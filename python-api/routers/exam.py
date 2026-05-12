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

# ── Request Models ────────────────────────────────────────────────────────────

class ExamCreateRequest(BaseModel):
    class_id: str
    title: str
    scheduled_start: datetime

class ExamStartSessionRequest(BaseModel):
    """Used by Shiny to create an exam and notify mobile clients."""
    class_id: str
    title: str
    exam_id: Optional[str] = None

class ExamSubmitRequest(BaseModel):
    exam_id: str
    student_id: str
    reason: str = "manual"

# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("")
async def create_exam(request: ExamCreateRequest, db: Session = Depends(get_db)):
    """Create an exam record (admin/Shiny use)."""
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

@router.post("/start-session")
async def start_exam_session(request: ExamStartSessionRequest, db: Session = Depends(get_db)):
    """
    Called by Shiny when lecturer starts an exam.
    Creates the exam record (if not exists) and broadcasts exam:start to all
    connected mobile clients so they can navigate to the exam screen.
    """
    exam_id = request.exam_id or str(uuid.uuid4())

    exam = db.query(models.Exam).filter(models.Exam.exam_id == exam_id).first()
    if not exam:
        exam = models.Exam(
            exam_id=exam_id,
            class_id=request.class_id,
            title=request.title,
            scheduled_start=datetime.utcnow(),
        )
        db.add(exam)
        db.commit()
        db.refresh(exam)

    await manager.broadcast({
        "type": "exam:start",
        "exam_id": exam.exam_id,
        "class_id": exam.class_id,
        "title": exam.title,
        "timestamp": datetime.utcnow().isoformat() + "Z",
    })
    return {"status": "started", "exam_id": exam.exam_id, "title": exam.title}

@router.get("/active/{student_id}")
async def get_active_exam(student_id: str, db: Session = Depends(get_db)):
    """Returns the currently active (non-ended) exam for student's enrolled classes."""
    enrolled = db.query(models.Enrollment).filter(
        models.Enrollment.student_id == student_id
    ).all()
    class_ids = [e.class_id for e in enrolled]
    if not class_ids:
        return {"active": False}

    cutoff = datetime.utcnow() - timedelta(hours=4)
    exam = (
        db.query(models.Exam)
        .filter(
            models.Exam.class_id.in_(class_ids),
            models.Exam.end_time == None,
            models.Exam.created_at >= cutoff,
        )
        .order_by(models.Exam.created_at.desc())
        .first()
    )
    if not exam:
        return {"active": False}
    return {
        "active": True,
        "exam_id": exam.exam_id,
        "title": exam.title,
        "class_id": exam.class_id,
    }

@router.get("/list/{class_id}")
async def list_exams(class_id: str, db: Session = Depends(get_db)):
    """Returns all exams for a class, newest first."""
    return db.query(models.Exam).filter(
        models.Exam.class_id == class_id
    ).order_by(models.Exam.created_at.desc()).all()

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
    """Submit exam for a student. Checks auto-submit condition and broadcasts if triggered."""
    if _PROCTOR_AVAILABLE and ProctorService:
        proctor = ProctorService(db)
        if proctor.check_auto_submit(request.exam_id, request.student_id):
            request.reason = "auto-submit: 3+ high-severity incidents"

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
