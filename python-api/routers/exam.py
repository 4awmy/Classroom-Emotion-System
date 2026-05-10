from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from database import get_db
import models
from schemas import IncidentResponse
from services.websocket import manager
try:
    from services.proctor_service import ProctorService
    _PROCTOR_AVAILABLE = True
except ImportError:
    ProctorService = None
    _PROCTOR_AVAILABLE = False
import uuid

router = APIRouter()

class ExamCreateRequest(BaseModel):
    class_id: str
    title: str
    scheduled_start: datetime

class ExamSubmitRequest(BaseModel):
    exam_id: str
    student_id: str
    reason: str

@router.post("")
async def create_exam(request: ExamCreateRequest, db: Session = Depends(get_db)):
    new_exam = models.Exam(
        exam_id=str(uuid.uuid4()),
        class_id=request.class_id,
        title=request.title,
        scheduled_start=request.scheduled_start
    )
    db.add(new_exam)
    db.commit()
    db.refresh(new_exam)
    return new_exam

@router.post("/{exam_id}/end")
async def end_exam(exam_id: str, db: Session = Depends(get_db)):
    exam = db.query(models.Exam).filter(models.Exam.exam_id == exam_id).first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
    
    exam.end_time = datetime.utcnow()
    db.commit()
    return {"status": "ended", "exam_id": exam_id}

@router.post("/submit")
async def submit_exam(request: ExamSubmitRequest, db: Session = Depends(get_db)):
    # Check for auto-submit condition
    proctor = ProctorService(db)
    if proctor.check_auto_submit(request.exam_id, request.student_id):
        request.reason = "auto-submit: 3+ high-severity incidents"
    
    # If it's an auto-submit, broadcast to WebSocket
    if "auto" in request.reason:
        await manager.broadcast({
            "type": "exam:autosubmit",
            "exam_id": request.exam_id,
            "student_id": request.student_id,
            "reason": request.reason,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        })
    return {"status": "submitted", "exam_id": request.exam_id}

@router.get("/incidents/{exam_id}", response_model=List[IncidentResponse])
async def get_exam_incidents(exam_id: str, db: Session = Depends(get_db)):
    return db.query(models.Incident).filter(models.Incident.exam_id == exam_id).all()
