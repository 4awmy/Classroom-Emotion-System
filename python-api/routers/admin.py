import io
import base64
import pandas as pd
import numpy as np
import cv2
import face_recognition
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from routers.auth import get_current_user
import models
import schemas

router = APIRouter(
    dependencies=[Depends(get_current_user)],
)

# --- Helpers ---

def generate_face_encoding(photo_b64: str):
    """Generates 128-d face encoding from base64 string."""
    try:
        # Decode base64
        header, encoded = photo_b64.split(",", 1) if "," in photo_b64 else (None, photo_b64)
        data = base64.b64decode(encoded)
        
        # Load image into OpenCV
        nparr = np.frombuffer(data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return None
            
        # Convert to RGB (face_recognition requirement)
        rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Find faces and encodings
        face_locations = face_recognition.face_locations(rgb_img)
        if not face_locations:
            return None
            
        encodings = face_recognition.face_encodings(rgb_img, face_locations)
        if not encodings:
            return None
            
        # Return first face encoding as bytes
        return encodings[0].tobytes()
    except Exception as e:
        print(f"[ADMIN] Error generating encoding: {e}")
        return None

# --- Lecturer CRUD ---

@router.get("/lecturers", response_model=List[schemas.LecturerResponse])
def get_lecturers(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Lecturer).offset(skip).limit(limit).all()

@router.post("/lecturers", response_model=schemas.LecturerResponse)
def create_lecturer(lecturer: schemas.LecturerCreate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer.lecturer_id).first()
    if db_lecturer:
        raise HTTPException(status_code=400, detail="Lecturer already registered")
    
    # Hash password if provided (REMOVED: Using Supabase Auth)
    lecturer_data = lecturer.model_dump()
    # if "password" in lecturer_data and lecturer_data["password"]:
    #     lecturer_data["password_hash"] = get_password_hash(lecturer_data.pop("password"))
    if "password" in lecturer_data:
        lecturer_data.pop("password")
    
    new_lecturer = models.Lecturer(**lecturer_data)
    db.add(new_lecturer)
    db.commit()
    db.refresh(new_lecturer)
    return new_lecturer

@router.put("/lecturers/{lecturer_id}", response_model=schemas.LecturerResponse)
def update_lecturer(lecturer_id: str, lecturer_update: schemas.LecturerUpdate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first()
    if not db_lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")
    
    update_data = lecturer_update.model_dump(exclude_unset=True)
    if "password" in update_data:
        update_data.pop("password")
        
    for key, value in update_data.items():
        setattr(db_lecturer, key, value)
        
    db.commit()
    db.refresh(db_lecturer)
    return db_lecturer

@router.delete("/lecturers/{lecturer_id}")
def delete_lecturer(lecturer_id: str, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first()
    if not db_lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")
    db.delete(db_lecturer)
    db.commit()
    return {"detail": "Lecturer deleted"}

# --- Student CRUD ---

@router.get("/students", response_model=List[schemas.StudentResponse])
def get_students(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Student).offset(skip).limit(limit).all()

@router.post("/students", response_model=schemas.StudentResponse)
def create_student(student: schemas.StudentCreate, db: Session = Depends(get_db)):
    db_student = db.query(models.Student).filter(models.Student.student_id == student.student_id).first()
    if db_student:
        raise HTTPException(status_code=400, detail="Student already registered")
    
    student_data = student.model_dump()
    
    # NEW: Generate Face Encoding if photo provided
    if "photo_b64" in student_data and student_data["photo_b64"]:
        encoding = generate_face_encoding(student_data.pop("photo_b64"))
        if encoding:
            student_data["face_encoding"] = encoding
        else:
            raise HTTPException(status_code=400, detail="Could not detect face in provided photo")
    
    # Hash password if provided
    if "password" in student_data and student_data["password"]:
        student_data["password_hash"] = get_password_hash(student_data.pop("password"))
        
    new_student = models.Student(**student_data)
    db.add(new_student)
    db.commit()
    db.refresh(new_student)
    return new_student

@router.put("/students/{student_id}", response_model=schemas.StudentResponse)
def update_student(student_id: str, student_update: schemas.StudentUpdate, db: Session = Depends(get_db)):
    db_student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    update_data = student_update.model_dump(exclude_unset=True)
    if "password" in update_data:
        update_data.pop("password")
        
    for key, value in update_data.items():
        setattr(db_student, key, value)
        
    db.commit()
    db.refresh(db_student)
    return db_student

@router.delete("/students/{student_id}")
def delete_student(student_id: str, db: Session = Depends(get_db)):
    db_student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Student not found")
    db.delete(db_student)
    db.commit()
    return {"detail": "Student deleted"}

# --- Bulk Uploads ---

@router.post("/lecturers/bulk")
async def bulk_upload_lecturers(file: UploadFile = File(...), db: Session = Depends(get_db)):
    if not file.filename.endswith(('.csv', '.xlsx')):
        raise HTTPException(status_code=400, detail="Invalid file format. Please upload a CSV or XLSX file.")
    
    contents = await file.read()
    try:
        if file.filename.endswith('.csv'):
            df = pd.read_csv(io.BytesIO(contents))
        else:
            df = pd.read_excel(io.BytesIO(contents))
            
        records = df.to_dict(orient="records")
        added = 0
        for record in records:
            lecturer_id = str(record.get('lecturer_id'))
            if not db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first():
                # Provide a default password for bulk uploads if not present
                password = record.get('password', 'AAST12345')
                new_lecturer = models.Lecturer(
                    lecturer_id=lecturer_id,
                    name=record.get('name'),
                    email=record.get('email'),
                    department=record.get('department'),
                    auth_user_id=uuid.uuid4() # Placeholder: Should be created in Supabase
                )
                db.add(new_lecturer)
                added += 1
        db.commit()
        return {"detail": f"Successfully added {added} lecturers."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing file: {str(e)}")

@router.post("/students/bulk")
async def bulk_upload_students(file: UploadFile = File(...), db: Session = Depends(get_db)):
    if not file.filename.endswith(('.csv', '.xlsx')):
        raise HTTPException(status_code=400, detail="Invalid file format. Please upload a CSV or XLSX file.")
    
    contents = await file.read()
    try:
        if file.filename.endswith('.csv'):
            df = pd.read_csv(io.BytesIO(contents))
        else:
            df = pd.read_excel(io.BytesIO(contents))
            
        records = df.to_dict(orient="records")
        added = 0
        for record in records:
            student_id = str(record.get('student_id'))
            if not db.query(models.Student).filter(models.Student.student_id == student_id).first():
                # Default password for bulk uploads
                password = record.get('password', 'AAST12345')
                new_student = models.Student(
                    student_id=student_id,
                    name=record.get('name'),
                    email=record.get('email'),
                    auth_user_id=uuid.uuid4() # Placeholder
                )
                db.add(new_student)
                added += 1
        db.commit()
        return {"detail": f"Successfully added {added} students."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing file: {str(e)}")
