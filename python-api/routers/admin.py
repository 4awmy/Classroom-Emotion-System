import io
import base64
import pandas as pd
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import List

from database import get_db
from routers.auth import get_current_user, get_password_hash
from services.face_embeddings import embeddings_available, image_bytes_to_embedding_bytes
import models
import schemas

router = APIRouter(
    dependencies=[Depends(get_current_user)],
)

# --- Helpers ---

def generate_face_encoding(photo_b64: str):
    """Generate ArcFace face embedding from a base64 photo."""
    if not embeddings_available():
        return None
    try:
        _, encoded = photo_b64.split(",", 1) if "," in photo_b64 else (None, photo_b64)
        data = base64.b64decode(encoded)
        return image_bytes_to_embedding_bytes(data)
    except Exception as e:
        print(f"[ADMIN] Encoding error: {e}")
        return None

# --- Admin CRUD ---

@router.get("/admins", response_model=List[schemas.AdminResponse])
def get_admins(db: Session = Depends(get_db)):
    return db.query(models.Admin).all()

@router.post("/admins", response_model=schemas.AdminResponse)
def create_admin(admin: schemas.AdminCreate, db: Session = Depends(get_db)):
    db_admin = db.query(models.Admin).filter(models.Admin.admin_id == admin.admin_id).first()
    if db_admin:
        raise HTTPException(status_code=400, detail="Admin ID already exists")

    admin_data = admin.model_dump()
    if "password" in admin_data and admin_data["password"]:
        admin_data["password_hash"] = get_password_hash(admin_data.pop("password"))
    else:
        admin_data.pop("password", None)

    if not admin_data.get("auth_user_id"):
        admin_data["auth_user_id"] = uuid.uuid4()
    else:
        admin_data["auth_user_id"] = uuid.UUID(str(admin_data["auth_user_id"]))

    try:
        new_admin = models.Admin(**admin_data)
        db.add(new_admin)
        db.commit()
        db.refresh(new_admin)
        return new_admin
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail="Admin with this ID or email already exists")

@router.put("/admins/{admin_id}", response_model=schemas.AdminResponse)
def update_admin(admin_id: str, admin_update: schemas.AdminUpdate, db: Session = Depends(get_db)):
    db_admin = db.query(models.Admin).filter(models.Admin.admin_id == admin_id).first()
    if not db_admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    
    update_data = admin_update.model_dump(exclude_unset=True)
    if "password" in update_data and update_data["password"]:
        update_data["password_hash"] = get_password_hash(update_data.pop("password"))
    else:
        update_data.pop("password", None)
        
    for key, value in update_data.items():
        setattr(db_admin, key, value)
        
    db.commit()
    db.refresh(db_admin)
    return db_admin

@router.delete("/admins/{admin_id}")
def delete_admin(admin_id: str, db: Session = Depends(get_db)):
    db_admin = db.query(models.Admin).filter(models.Admin.admin_id == admin_id).first()
    if not db_admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    if admin_id == "admin":
        raise HTTPException(status_code=403, detail="Cannot delete main admin account")
    db.delete(db_admin)
    db.commit()
    return {"detail": "Admin deleted"}

# --- Lecturer CRUD ---

@router.get("/lecturers", response_model=List[schemas.LecturerResponse])
def get_lecturers(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Lecturer).offset(skip).limit(limit).all()

@router.post("/lecturers", response_model=schemas.LecturerResponse)
def create_lecturer(lecturer: schemas.LecturerCreate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer.lecturer_id).first()
    if db_lecturer:
        raise HTTPException(status_code=400, detail="Lecturer already registered")

    lecturer_data = lecturer.model_dump()
    if "password" in lecturer_data and lecturer_data["password"]:
        lecturer_data["password_hash"] = get_password_hash(lecturer_data.pop("password"))
    else:
        lecturer_data.pop("password", None)

    if not lecturer_data.get("auth_user_id"):
        lecturer_data["auth_user_id"] = uuid.uuid4()
    else:
        lecturer_data["auth_user_id"] = uuid.UUID(str(lecturer_data["auth_user_id"]))

    try:
        new_lecturer = models.Lecturer(**lecturer_data)
        db.add(new_lecturer)
        db.commit()
        db.refresh(new_lecturer)
        return new_lecturer
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail="Lecturer with this ID or email already exists")

@router.put("/lecturers/{lecturer_id}", response_model=schemas.LecturerResponse)
def update_lecturer(lecturer_id: str, lecturer_update: schemas.LecturerUpdate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first()
    if not db_lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")
    
    update_data = lecturer_update.model_dump(exclude_unset=True)
    if "password" in update_data and update_data["password"]:
        update_data["password_hash"] = get_password_hash(update_data.pop("password"))
    else:
        update_data.pop("password", None)
        
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
    if "photo_b64" in student_data and student_data["photo_b64"]:
        encoding = generate_face_encoding(student_data.pop("photo_b64"))
        if encoding:
            student_data["face_encoding"] = encoding
    else:
        student_data.pop("photo_b64", None)

    if "password" in student_data and student_data["password"]:
        student_data["password_hash"] = get_password_hash(student_data.pop("password"))
    else:
        student_data.pop("password", None)

    if not student_data.get("auth_user_id"):
        student_data["auth_user_id"] = uuid.uuid4()
    else:
        student_data["auth_user_id"] = uuid.UUID(str(student_data["auth_user_id"]))

    try:
        new_student = models.Student(**student_data)
        db.add(new_student)
        db.commit()
        db.refresh(new_student)
        return new_student
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail="Student with this ID or email already exists")

@router.put("/students/{student_id}", response_model=schemas.StudentResponse)
def update_student(student_id: str, student_update: schemas.StudentUpdate, db: Session = Depends(get_db)):
    db_student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    update_data = student_update.model_dump(exclude_unset=True)
    if "password" in update_data and update_data["password"]:
        update_data["password_hash"] = get_password_hash(update_data.pop("password"))
    else:
        update_data.pop("password", None)
        
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
