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
    import face_recognition
    _VISION_AVAILABLE = True
except ImportError:
    _VISION_AVAILABLE = False

router = APIRouter()

def extract_drive_id(url: str) -> Optional[str]:
    """
    Extracts the file ID from a Google Drive share URL.
    """
    patterns = [
        r'/file/d/([a-zA-Z0-9_-]+)',
        r'id=([a-zA-Z0-9_-]+)',
        r'([a-zA-Z0-9_-]+)$' # Fallback for just the ID
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

def get_face_encoding(image_bytes: bytes) -> Optional[bytes]:
    """
    Helper to detect face and return encoding as bytes.
    Returns None in cloud deployment where vision libs are not installed.
    """
    if not _VISION_AVAILABLE:
        return None
    try:
        img = face_recognition.load_image_file(io.BytesIO(image_bytes))
        encodings = face_recognition.face_encodings(img)
        if encodings:
            return encodings[0].astype(np.float64).tobytes()
    except Exception as e:
        print(f"[ROSTER] Face encoding error: {e}")
    return None

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Bulk roster upload via XLSX.
    Expected columns: student_id, name, email, photo_link
    """
    try:
        contents = await roster_xlsx.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        required_cols = ["student_id", "name", "email", "photo_link"]
        if not all(col in df.columns for col in required_cols):
            raise HTTPException(status_code=400, detail=f"XLSX must contain: {required_cols}")

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
    """
    Proxies the enrolled Drive photo thumbnail for a student.
    Avoids CORS issues when Shiny embeds Drive photos directly.
    Returns 404 if student not found or no photo available.
    """
    from fastapi import Response as FastAPIResponse
    from fastapi.responses import StreamingResponse
    import io

    student = db.query(Student).filter(Student.student_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Use enrolled photo_link if stored — for now derive from email or raise 404
    # (photo_link is not stored in DB; this endpoint is a placeholder for Drive proxy)
    raise HTTPException(status_code=404, detail="No enrolled photo stored for this student")
