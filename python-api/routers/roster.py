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
from services.face_embeddings import (
    ENCODING_DIM,
    ENCODING_DTYPE,
    embeddings_available,
    image_bytes_to_embedding_bytes,
)

router = APIRouter()


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


def normalize_student_id(value) -> str:
    sid = str(value).strip()
    if sid.endswith(".0"):
        sid = sid[:-2]
    return sid


def get_face_encoding(image_bytes: bytes) -> Optional[bytes]:
    """Detect the largest face and return its ArcFace embedding as bytes."""
    if not embeddings_available():
        return None
    try:
        return image_bytes_to_embedding_bytes(image_bytes)
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
            sid = normalize_student_id(row["student_id"])
            name = str(row["name"]).strip()
            email = str(row["email"]).strip()
            url = str(row["photo_link"]).strip()
            
            # 1. UPSERT Student record
            student = db.query(Student).filter(Student.student_id == sid).first()
            if not student:
                student = Student(student_id=sid, name=name, email=email, photo_url=url)
                db.add(student)
                created += 1
            else:
                student.name = name
                student.email = email
                student.photo_url = url
            
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
    student_id = normalize_student_id(student_id)

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
            "department": s.department,
            "year": s.year,
            "photo_url": s.photo_url,
            "has_encoding": _has_arcface_encoding(s.face_encoding),
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
    """Return all ArcFace encodings as JSON lists (used by local vision node)."""
    students = db.query(Student).filter(Student.face_encoding.isnot(None)).all()
    result = []
    for s in students:
        enc = np.frombuffer(s.face_encoding, dtype=ENCODING_DTYPE)
        if enc.shape[0] == ENCODING_DIM:
            result.append({
                "student_id": s.student_id,
                "name": s.name,
                "encoding": enc.tolist(),
            })
    return result


def _has_arcface_encoding(face_encoding: Optional[bytes]) -> bool:
    if not face_encoding:
        return False
    enc = np.frombuffer(face_encoding, dtype=ENCODING_DTYPE)
    return enc.shape[0] == ENCODING_DIM
