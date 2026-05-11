from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Form
from sqlalchemy.orm import Session
from database import get_db
from models import Student
from schemas import StudentListResponse, StudentUploadResponse
from typing import List, Optional
import pandas as pd
import io
import requests
import numpy as np
import re

try:
    import cv2
    _VISION_AVAILABLE = True
except ImportError:
    _VISION_AVAILABLE = False

router = APIRouter()

ENCODING_DTYPE = np.float32
_HOG_SIZE = (64, 64)


def _get_cascade():
    if not _VISION_AVAILABLE:
        return None
    return cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")


def _hog_descriptor(face_bgr: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(cv2.resize(face_bgr, _HOG_SIZE), cv2.COLOR_BGR2GRAY)
    hog = cv2.HOGDescriptor(
        _winSize=(64, 64), _blockSize=(16, 16), _blockStride=(8, 8),
        _cellSize=(8, 8), _nbins=9
    )
    desc = hog.compute(gray).flatten().astype(ENCODING_DTYPE)
    norm = np.linalg.norm(desc)
    return desc / norm if norm > 0 else desc


def extract_drive_id(url: str) -> Optional[str]:
    patterns = [
        r'/file/d/([a-zA-Z0-9_-]+)',
        r'id=([a-zA-Z0-9_-]+)',
        r'([a-zA-Z0-9_-]+)$',
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def get_face_encoding(image_bytes: bytes) -> Optional[bytes]:
    """Detect the largest face and return its HOG descriptor as bytes."""
    if not _VISION_AVAILABLE:
        return None
    try:
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            return None
        cascade = _get_cascade()
        if cascade is None:
            return None
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
        if len(faces) == 0:
            return None
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        face_roi = img_bgr[y:y+h, x:x+w]
        if face_roi.size == 0:
            return None
        return _hog_descriptor(face_roi).tobytes()
    except Exception as e:
        print(f"[ROSTER] Face encoding error: {e}")
    return None

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Bulk roster upload via XLSX or CSV.
    Expected columns: student_id, name, email, photo_link
    """
    try:
        contents = await roster_xlsx.read()
        filename = (roster_xlsx.filename or "").lower()

        if filename.endswith(".csv"):
            df = pd.read_csv(io.BytesIO(contents))
        else:
            df = pd.read_excel(io.BytesIO(contents))

        # Normalise column names (strip whitespace)
        df.columns = [c.strip() for c in df.columns]

        # Map common alternate column name formats to expected names
        col_aliases = {
            "Student ID":   "student_id",
            "student id":   "student_id",
            "StudentID":    "student_id",
            "ID":           "student_id",
            "Student Name": "name",
            "student name": "name",
            "StudentName":  "name",
            "Full Name":    "name",
            "Photo Link":   "photo_link",
            "photo link":   "photo_link",
            "PhotoLink":    "photo_link",
            "Photo URL":    "photo_link",
            "Email":        "email",
            "email":        "email",
        }
        df.rename(columns=col_aliases, inplace=True)

        # email is optional — add blank column if missing
        if "email" not in df.columns:
            df["email"] = ""

        required_cols = ["student_id", "name", "photo_link"]
        if not all(col in df.columns for col in required_cols):
            raise HTTPException(status_code=400, detail=f"File must contain: {required_cols}. Found: {list(df.columns)}")

        created = 0
        encoded = 0
        
        for _, row in df.iterrows():
            sid = str(row["student_id"]).strip()
            name = str(row["name"]).strip()
            email = str(row["email"]).strip()
            url = str(row["photo_link"]).strip()
            
            # 1. UPSERT Student record
            student = db.query(Student).filter(Student.student_id == sid).first()
            if not student:
                student = Student(student_id=sid, name=name, email=email)
                db.add(student)
                created += 1
            else:
                student.name = name
                student.email = email
            
            # 2. Process Encoding if link exists
            file_id = extract_drive_id(url)
            if file_id:
                try:
                    resp = requests.get(f"https://drive.google.com/uc?export=download&id={file_id}", timeout=15)
                    if resp.status_code == 200:
                        encoding = get_face_encoding(resp.content)
                        if encoding:
                            student.face_encoding = encoding
                            encoded += 1
                except:
                    pass # Skip failing links
        
        db.commit()
        return {"students_created": created, "encodings_saved": encoded}
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/student", response_model=StudentUploadResponse, status_code=201)
async def add_single_student(
    student_id: str = Form(...),
    name: str = Form(...),
    email: Optional[str] = Form(None),
    photo: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Add single student with photo upload.
    """
    if not re.match(r'^\d{9}$', student_id):
        raise HTTPException(status_code=400, detail="Student ID must be 9 digits.")
    
    if db.query(Student).filter(Student.student_id == student_id).first():
        raise HTTPException(status_code=409, detail="Student ID already exists.")

    photo_bytes = await photo.read()
    if len(photo_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Photo exceeds 5MB limit.")

    encoding = get_face_encoding(photo_bytes)
    if not encoding:
        raise HTTPException(status_code=422, detail="No face detected in photo.")

    new_student = Student(
        student_id=student_id,
        name=name,
        email=email,
        face_encoding=encoding
    )
    db.add(new_student)
    db.commit()
    
    return {
        "student_id": student_id,
        "name": name,
        "encoding_saved": True
    }

@router.get("/students", response_model=List[StudentListResponse])
def list_students(db: Session = Depends(get_db)):
    """
    List all students with encoding status.
    """
    students = db.query(Student).all()
    results = []
    for s in students:
        results.append({
            "student_id": s.student_id,
            "name": s.name,
            "email": s.email,
            "has_encoding": s.face_encoding is not None
        })
    return results


@router.get("/students/{student_id}/photo")
def proxy_student_photo(student_id: str, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.student_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    raise HTTPException(status_code=404, detail="No enrolled photo stored for this student")


@router.get("/students/encodings")
def get_student_encodings(db: Session = Depends(get_db)):
    """Return all HOG encodings as JSON lists (used by local vision node)."""
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    result = []
    for s in students:
        enc = np.frombuffer(s.face_encoding, dtype=ENCODING_DTYPE)
        if enc.shape[0] > 100:  # HOG vectors are large; skip old 128-dim blobs
            result.append({
                "student_id": s.student_id,
                "name": s.name,
                "encoding": enc.tolist(),
            })
    return result
