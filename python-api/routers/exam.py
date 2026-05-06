from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import List
from datetime import datetime
from sqlalchemy.orm import Session
from database import get_db
import models
from schemas import IncidentResponse
from services.websocket import manager

router = APIRouter()

class ExamStartRequest(BaseModel):
    exam_id: str
    lecture_id: str

class ExamSubmitRequest(BaseModel):
    exam_id: str
    student_id: str
    reason: str

@router.post("/start")
async def start_exam(request: ExamStartRequest):
    return {"status": "proctoring_active", "exam_id": request.exam_id}

@router.post("/submit")
async def submit_exam(request: ExamSubmitRequest):
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
