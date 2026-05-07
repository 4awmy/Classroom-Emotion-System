from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Form
from sqlalchemy.orm import Session
from database import get_db
from models import Student
from schemas import StudentListResponse, StudentUploadResponse
from typing import List, Optional
import pandas as pd
import io
import requests
import face_recognition
import numpy as np
import re

router = APIRouter()

def extract_drive_id(url: str) -> Optional[str]:
    """
    Extracts the file ID from a Google Drive share URL.
    Handles:
    - https://drive.google.com/open?id=ID
    - https://drive.google.com/file/d/ID/view
    - Just the ID
    """
    if not url or url == "nan":
        return None
    
    patterns = [
        r'/file/d/([a-zA-Z0-9_-]+)',
        r'id=([a-zA-Z0-9_-]+)',
        r'([a-zA-Z0-9_-]{25,})' # Long alphanumeric string likely to be an ID
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

def get_face_encoding(image_bytes: bytes) -> Optional[bytes]:
    """
    Helper to detect face and return encoding as bytes.
    """
    try:
        # Load image from bytes
        img = face_recognition.load_image_file(io.BytesIO(image_bytes))
        encodings = face_recognition.face_encodings(img)
        if encodings:
            return encodings[0].astype(np.float64).tobytes()
    except Exception as e:
        print(f"[ROSTER] Face encoding error: {e}")
    return None

@router.post("/upload")
async def upload_roster(
    roster_file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Bulk roster upload via XLSX or CSV.
    Expected columns: student_id, name (or Student Name), email, photo_link (or Photo Link)
    """
    try:
        contents = await roster_file.read()
        filename = roster_file.filename.lower()
        
        if filename.endswith(".xlsx"):
            df = pd.read_excel(io.BytesIO(contents))
        elif filename.endswith(".csv"):
            df = pd.read_csv(io.BytesIO(contents))
        else:
            raise HTTPException(status_code=400, detail="Unsupported file format. Use .xlsx or .csv")

        # Normalize column names
        df.columns = [str(c).strip().lower().replace(" ", "_") for c in df.columns]
        
        # Mapping variations
        column_map = {
            "student_id": ["student_id", "id", "sid"],
            "name": ["name", "student_name", "full_name"],
            "email": ["email", "e-mail"],
            "photo_link": ["photo_link", "link", "drive_link", "url"]
        }
        
        final_cols = {}
        for target, aliases in column_map.items():
            for alias in aliases:
                if alias in df.columns:
                    final_cols[target] = alias
                    break
        
        if "student_id" not in final_cols or "name" not in final_cols:
            raise HTTPException(status_code=400, detail=f"File must contain student_id and name columns. Found: {list(df.columns)}")

        created = 0
        encoded = 0
        
        for _, row in df.iterrows():
            sid = str(row[final_cols["student_id"]]).strip().split(".")[0] # handle float IDs
            if not re.match(r'^\d{9}$', sid):
                continue # Skip invalid IDs
                
            name = str(row[final_cols["name"]]).strip()
            email = str(row.get(final_cols.get("email"), "")).strip() or None
            url = str(row.get(final_cols.get("photo_link"), "")).strip()
            
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
                    resp = requests.get(f"https://drive.google.com/uc?export=download&id={file_id}", timeout=20)
                    if resp.status_code == 200:
                        encoding = get_face_encoding(resp.content)
                        if encoding:
                            student.face_encoding = encoding
                            encoded += 1
                            print(f"[ROSTER] Encoded {sid} ({name})")
                except Exception as e:
                    print(f"[ROSTER] Failed to download/encode {sid}: {e}")
        
        db.commit()
        return {"students_created": created, "encodings_saved": encoded}
        
    except HTTPException as he:
        raise he
    except Exception as e:
        db.rollback()
        print(f"[ROSTER] Critical error: {e}")
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

