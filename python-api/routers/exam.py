from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from database import get_db
from models import Incident
from schemas import IncidentResponse
from services.websocket import manager

router = APIRouter(tags=["Exam"])

class ExamStartRequest(BaseModel):
    exam_id: str
    student_id: str

class ExamSubmitRequest(BaseModel):
    exam_id: str
    student_id: str
    reason: str

@router.post("/start")
async def start_exam(request: ExamStartRequest):
    """
    Initializes proctoring for an exam session.
    """
    return {"status": "active", "exam_id": request.exam_id}

@router.post("/submit")
async def submit_exam(request: ExamSubmitRequest):
    """
    Finalizes an exam session and broadcasts auto-submits.
    """
    # If it's an auto-submit, broadcast to WebSocket
    if "auto" in request.reason.lower():
        await manager.broadcast({
            "type": "exam:autosubmit",
            "exam_id": request.exam_id,
            "student_id": request.student_id,
            "reason": request.reason,
            "timestamp": datetime.now(timezone.utc).isoformat() + "Z"
        })
    return {"status": "submitted", "exam_id": request.exam_id}

@router.get("/incidents/{exam_id}", response_model=List[IncidentResponse])
async def get_exam_incidents(exam_id: str, db: Session = Depends(get_db)):
    """
    Returns all proctoring incidents for a specific exam.
    """
    incidents = db.query(Incident).filter(Incident.exam_id == exam_id).all()
    return incidents
