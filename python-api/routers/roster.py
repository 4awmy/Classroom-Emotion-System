import io
import re
import pandas as pd
import requests
import face_recognition
import numpy as np
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
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

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Parses an XLSX roster, downloads student photos from Google Drive,
    generates face encodings, and saves to the database.
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

        # Deduplicate by Student ID in the Excel file
        df = df.drop_duplicates(subset=['Student ID'])

        students_created = 0
        encodings_saved = 0

        for i, row in df.iterrows():
            student_id = str(row['Student ID']).strip()
            # Ensure 9 digits (AAST format)
            if len(student_id) < 9:
                student_id = student_id.zfill(9)
            
            name = str(row['Student Name']).strip()
            photo_url = str(row['Photo Link']).strip()
            
            # Determine role based on ID (mock logic for now, but saved to DB)
            role = "lecturer" if student_id.upper().startswith("LECT") else "student"
            
            # Check if student already exists
            existing_student = db.query(Student).filter(Student.student_id == student_id).first()
            if existing_student:
                logger.info(f"Student {student_id} already exists, updating role.")
                existing_student.role = role
                if not existing_student.hashed_password:
                    existing_student.hashed_password = get_password_hash("password123")
                continue

            # Process photo
            face_encoding_bytes = None
            drive_id = extract_drive_id(photo_url)
            
            if drive_id:
                download_url = f"https://drive.google.com/uc?export=download&id={drive_id}"
                try:
                    resp = requests.get(download_url, timeout=15)
                    content_type = resp.headers.get("Content-Type", "")
                    if resp.status_code == 200 and ("image" in content_type or "octet-stream" in content_type):
                        # Load image and generate encoding
                        image = face_recognition.load_image_file(io.BytesIO(resp.content))
                        encodings = face_recognition.face_encodings(image)
                        
                        if encodings:
                            face_encoding_bytes = encodings[0].tobytes()
                            encodings_saved += 1
                        else:
                            logger.warning(f"No face found in photo for student {student_id}")
                    else:
                        logger.warning(f"Failed to download image for student {student_id}: {resp.status_code}")
                except Exception as e:
                    logger.error(f"Error processing photo for student {student_id}: {e}")

            # Create student record
            new_student = Student(
                student_id=student_id,
                name=name,
                role=role,
                hashed_password=get_password_hash("password123"),
                face_encoding=face_encoding_bytes
            )
            db.add(new_student)
            students_created += 1
            
            # Commit every 10 students
            if students_created % 10 == 0:
                db.commit()
                logger.info(f"Committed {students_created} students so far...")

        db.commit()
        return {
            "students_created": students_created,
            "encodings_saved": encodings_saved
        }

    except Exception as e:
        db.rollback()
        logger.exception("Roster upload failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process roster: {str(e)}"
        )
