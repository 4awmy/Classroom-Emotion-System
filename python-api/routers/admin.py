import io
import pandas as pd
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

# --- Lecturer CRUD ---

@router.get("/lecturers", response_model=List[schemas.LecturerResponse])
def get_lecturers(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Lecturer).offset(skip).limit(limit).all()

@router.post("/lecturers", response_model=schemas.LecturerResponse)
def create_lecturer(lecturer: schemas.LecturerCreate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer.lecturer_id).first()
    if db_lecturer:
        raise HTTPException(status_code=400, detail="Lecturer already registered")
    new_lecturer = models.Lecturer(**lecturer.model_dump())
    db.add(new_lecturer)
    db.commit()
    db.refresh(new_lecturer)
    return new_lecturer

@router.get("/lecturers/{lecturer_id}", response_model=schemas.LecturerResponse)
def get_lecturer(lecturer_id: str, db: Session = Depends(get_db)):
    lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first()
    if not lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")
    return lecturer

@router.put("/lecturers/{lecturer_id}", response_model=schemas.LecturerResponse)
def update_lecturer(lecturer_id: str, lecturer_update: schemas.LecturerUpdate, db: Session = Depends(get_db)):
    db_lecturer = db.query(models.Lecturer).filter(models.Lecturer.lecturer_id == lecturer_id).first()
    if not db_lecturer:
        raise HTTPException(status_code=404, detail="Lecturer not found")
    for key, value in lecturer_update.model_dump(exclude_unset=True).items():
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
    new_student = models.Student(**student.model_dump())
    db.add(new_student)
    db.commit()
    db.refresh(new_student)
    return new_student

@router.get("/students/{student_id}", response_model=schemas.StudentResponse)
def get_student(student_id: str, db: Session = Depends(get_db)):
    student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return student

@router.put("/students/{student_id}", response_model=schemas.StudentResponse)
def update_student(student_id: str, student_update: schemas.StudentUpdate, db: Session = Depends(get_db)):
    db_student = db.query(models.Student).filter(models.Student.student_id == student_id).first()
    if not db_student:
        raise HTTPException(status_code=404, detail="Student not found")
    for key, value in student_update.model_dump(exclude_unset=True).items():
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
                new_lecturer = models.Lecturer(
                    lecturer_id=lecturer_id,
                    name=record.get('name'),
                    email=record.get('email'),
                    department=record.get('department')
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
                new_student = models.Student(
                    student_id=student_id,
                    name=record.get('name'),
                    email=record.get('email')
                )
                db.add(new_student)
                added += 1
        db.commit()
        return {"detail": f"Successfully added {added} students."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing file: {str(e)}")
