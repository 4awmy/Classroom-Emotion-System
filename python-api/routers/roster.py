import io
import re
import pandas as pd
import requests
import face_recognition
import numpy as np
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from database import get_db, SessionLocal
from models import Student
from routers.auth import get_password_hash
import logging

router = APIRouter(tags=["Roster"])
logger = logging.getLogger(__name__)

def extract_drive_id(url: str) -> str:
    """Extracts the file ID from a Google Drive sharing URL."""
    if not isinstance(url, str):
        return None
    match = re.search(r'id=([a-zA-Z0-9_-]+)', url)
    if not match:
        match = re.search(r'/d/([a-zA-Z0-9_-]+)', url)
    return match.group(1) if match else None

def process_student_photo(student_id: str, photo_url: str):
    """Background task to download and encode a student photo."""
    db = SessionLocal()
    try:
        drive_id = extract_drive_id(photo_url)
        if not drive_id:
            return

        download_url = f"https://drive.google.com/uc?export=download&id={drive_id}"
        resp = requests.get(download_url, timeout=30)
        content_type = resp.headers.get("Content-Type", "")
        
        if resp.status_code == 200 and ("image" in content_type or "octet-stream" in content_type):
            image = face_recognition.load_image_file(io.BytesIO(resp.content))
            encodings = face_recognition.face_encodings(image)
            
            if encodings:
                student = db.query(Student).filter(Student.student_id == student_id).first()
                if student:
                    student.face_encoding = encodings[0].tobytes()
                    db.commit()
                    logger.info(f"Successfully saved encoding for student {student_id}")
            else:
                logger.warning(f"No face found in photo for student {student_id}")
        else:
            logger.warning(f"Failed to download image for student {student_id}: {resp.status_code}")
    except Exception as e:
        logger.error(f"Error processing photo for student {student_id}: {e}")
    finally:
        db.close()

@router.post("/upload")
async def upload_roster(
    background_tasks: BackgroundTasks,
    roster_xlsx: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Parses an XLSX roster, creates/updates student records, and 
    schedules photo processing in the background.
    """
    try:
        # Read XLSX into memory
        contents = await roster_xlsx.read()
        df = pd.read_excel(io.BytesIO(contents))
        
        # Validate columns
        required_cols = ['Student ID', 'Student Name', 'Photo Link']
        if not all(col in df.columns for col in required_cols):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Missing required columns. Expected: {required_cols}"
            )

        # Deduplicate by Student ID
        df = df.drop_duplicates(subset=['Student ID'])

        students_created = 0
        students_updated = 0

        for i, row in df.iterrows():
            student_id = str(row['Student ID']).strip()
            if len(student_id) < 9:
                student_id = student_id.zfill(9)
            
            name = str(row['Student Name']).strip()
            photo_url = str(row['Photo Link']).strip()
            role = "lecturer" if student_id.upper().startswith("LECT") else "student"
            
            existing_student = db.query(Student).filter(Student.student_id == student_id).first()
            
            if existing_student:
                existing_student.name = name
                existing_student.role = role
                students_updated += 1
            else:
                new_student = Student(
                    student_id=student_id,
                    name=name,
                    role=role,
                    hashed_password=get_password_hash("password123") # Default password
                )
                db.add(new_student)
                students_created += 1

            # Schedule photo processing
            if photo_url and "drive.google.com" in photo_url:
                background_tasks.add_task(process_student_photo, student_id, photo_url)

            if (students_created + students_updated) % 20 == 0:
                db.commit()

        db.commit()
        return {
            "students_created": students_created,
            "students_updated": students_updated,
            "message": "Roster processed. Photo encoding running in background."
        }

    except Exception as e:
        db.rollback()
        logger.exception("Roster upload failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process roster: {str(e)}"
        )
