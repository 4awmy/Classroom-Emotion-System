from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from routers.auth import get_current_user
import models
import schemas

router = APIRouter(
    dependencies=[Depends(get_current_user)],
)

# --- Course CRUD ---

@router.get("/", response_model=List[schemas.CourseResponse])
def get_courses(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Course).offset(skip).limit(limit).all()

@router.post("/", response_model=schemas.CourseResponse)
def create_course(course: schemas.CourseCreate, db: Session = Depends(get_db)):
    db_course = db.query(models.Course).filter(models.Course.course_id == course.course_id).first()
    if db_course:
        raise HTTPException(status_code=400, detail="Course already exists")
    new_course = models.Course(**course.model_dump())
    db.add(new_course)
    db.commit()
    db.refresh(new_course)
    return new_course

@router.get("/{course_id}", response_model=schemas.CourseResponse)
def get_course(course_id: str, db: Session = Depends(get_db)):
    course = db.query(models.Course).filter(models.Course.course_id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    return course

@router.put("/{course_id}", response_model=schemas.CourseResponse)
def update_course(course_id: str, course_update: schemas.CourseUpdate, db: Session = Depends(get_db)):
    db_course = db.query(models.Course).filter(models.Course.course_id == course_id).first()
    if not db_course:
        raise HTTPException(status_code=404, detail="Course not found")
    for key, value in course_update.model_dump(exclude_unset=True).items():
        setattr(db_course, key, value)
    db.commit()
    db.refresh(db_course)
    return db_course

@router.delete("/{course_id}")
def delete_course(course_id: str, db: Session = Depends(get_db)):
    db_course = db.query(models.Course).filter(models.Course.course_id == course_id).first()
    if not db_course:
        raise HTTPException(status_code=404, detail="Course not found")
    db.delete(db_course)
    db.commit()
    return {"detail": "Course deleted"}

# --- Class CRUD ---

@router.get("/classes", response_model=List[schemas.ClassResponse])
def get_classes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Class).offset(skip).limit(limit).all()

@router.post("/classes", response_model=schemas.ClassResponse)
def create_class(class_data: schemas.ClassCreate, db: Session = Depends(get_db)):
    new_class = models.Class(**class_data.model_dump())
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    return new_class

@router.get("/classes/{class_id}", response_model=schemas.ClassResponse)
def get_class(class_id: str, db: Session = Depends(get_db)):
    class_obj = db.query(models.Class).filter(models.Class.class_id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    return class_obj

@router.put("/classes/{class_id}", response_model=schemas.ClassResponse)
def update_class(class_id: str, class_update: schemas.ClassUpdate, db: Session = Depends(get_db)):
    db_class = db.query(models.Class).filter(models.Class.class_id == class_id).first()
    if not db_class:
        raise HTTPException(status_code=404, detail="Class not found")
    for key, value in class_update.model_dump(exclude_unset=True).items():
        setattr(db_class, key, value)
    db.commit()
    db.refresh(db_class)
    return db_class

@router.delete("/classes/{class_id}")
def delete_class(class_id: str, db: Session = Depends(get_db)):
    db_class = db.query(models.Class).filter(models.Class.class_id == class_id).first()
    if not db_class:
        raise HTTPException(status_code=404, detail="Class not found")
    db.delete(db_class)
    db.commit()
    return {"detail": "Class deleted"}

# --- ClassSchedule CRUD ---

@router.get("/schedules", response_model=List[schemas.ClassScheduleResponse])
def get_schedules(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.ClassSchedule).offset(skip).limit(limit).all()

@router.post("/schedules", response_model=schemas.ClassScheduleResponse)
def create_schedule(schedule: schemas.ClassScheduleCreate, db: Session = Depends(get_db)):
    new_schedule = models.ClassSchedule(**schedule.model_dump())
    db.add(new_schedule)
    db.commit()
    db.refresh(new_schedule)
    return new_schedule

@router.get("/schedules/{schedule_id}", response_model=schemas.ClassScheduleResponse)
def get_schedule(schedule_id: str, db: Session = Depends(get_db)):
    schedule = db.query(models.ClassSchedule).filter(models.ClassSchedule.schedule_id == schedule_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    return schedule

@router.put("/schedules/{schedule_id}", response_model=schemas.ClassScheduleResponse)
def update_schedule(schedule_id: str, schedule_update: schemas.ClassScheduleUpdate, db: Session = Depends(get_db)):
    db_schedule = db.query(models.ClassSchedule).filter(models.ClassSchedule.schedule_id == schedule_id).first()
    if not db_schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    for key, value in schedule_update.model_dump(exclude_unset=True).items():
        setattr(db_schedule, key, value)
    db.commit()
    db.refresh(db_schedule)
    return db_schedule

@router.delete("/schedules/{schedule_id}")
def delete_schedule(schedule_id: str, db: Session = Depends(get_db)):
    db_schedule = db.query(models.ClassSchedule).filter(models.ClassSchedule.schedule_id == schedule_id).first()
    if not db_schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
    db.delete(db_schedule)
    db.commit()
    return {"detail": "Schedule deleted"}

# --- Enrollment CRUD ---

@router.get("/enrollments", response_model=List[schemas.EnrollmentResponse])
def get_enrollments(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Enrollment).offset(skip).limit(limit).all()

@router.post("/enrollments", response_model=schemas.EnrollmentResponse)
def create_enrollment(enrollment: schemas.EnrollmentCreate, db: Session = Depends(get_db)):
    new_enrollment = models.Enrollment(**enrollment.model_dump())
    db.add(new_enrollment)
    db.commit()
    db.refresh(new_enrollment)
    return new_enrollment

@router.get("/enrollments/{enrollment_id}", response_model=schemas.EnrollmentResponse)
def get_enrollment(enrollment_id: int, db: Session = Depends(get_db)):
    enrollment = db.query(models.Enrollment).filter(models.Enrollment.id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found")
    return enrollment

@router.put("/enrollments/{enrollment_id}", response_model=schemas.EnrollmentResponse)
def update_enrollment(enrollment_id: int, enrollment_update: schemas.EnrollmentUpdate, db: Session = Depends(get_db)):
    db_enrollment = db.query(models.Enrollment).filter(models.Enrollment.id == enrollment_id).first()
    if not db_enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found")
    for key, value in enrollment_update.model_dump(exclude_unset=True).items():
        setattr(db_enrollment, key, value)
    db.commit()
    db.refresh(db_enrollment)
    return db_enrollment

@router.delete("/enrollments/{enrollment_id}")
def delete_enrollment(enrollment_id: int, db: Session = Depends(get_db)):
    db_enrollment = db.query(models.Enrollment).filter(models.Enrollment.id == enrollment_id).first()
    if not db_enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found")
    db.delete(db_enrollment)
    db.commit()
    return {"detail": "Enrollment deleted"}
