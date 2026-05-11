import io
import base64
import pandas as pd
import numpy as np
import uuid

try:
    import cv2
    _CV2_OK = True
except ImportError:
    _CV2_OK = False

ENCODING_DTYPE = np.float32
_HOG_SIZE = (64, 64)

def _get_cascade():
    if not _CV2_OK:
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
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from routers.auth import get_current_user, get_password_hash
import models
import schemas

router = APIRouter(
    dependencies=[Depends(get_current_user)],
)

# --- Helpers ---

def generate_face_encoding(photo_b64: str):
    """Generate HOG face encoding from base64 photo (works on DO cloud, no compilation needed)."""
    if not _CV2_OK:
        return None
    try:
        _, encoded = photo_b64.split(",", 1) if "," in photo_b64 else (None, photo_b64)
        data = base64.b64decode(encoded)
        nparr = np.frombuffer(data, np.uint8)
        img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
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
        admin_data["auth_user_id"] = str(uuid.uuid4())
        
    new_admin = models.Admin(**admin_data)
    db.add(new_admin)
    db.commit()
    db.refresh(new_admin)
    return new_admin

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
        lecturer_data["auth_user_id"] = str(uuid.uuid4())
    
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
    
    if "password" in student_data and student_data["password"]:
        student_data["password_hash"] = get_password_hash(student_data.pop("password"))
    else:
        student_data.pop("password", None)
        
    if not student_data.get("auth_user_id"):
        student_data["auth_user_id"] = str(uuid.uuid4())
        
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
