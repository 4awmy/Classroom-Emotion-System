from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
from datetime import datetime
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

@router.get("/incidents/{exam_id}")
async def get_exam_incidents(exam_id: str):
    return [
        {
            "student_id": "S01",
            "timestamp": "2026-04-28T10:15:33",
            "flag_type": "phone_on_desk",
            "severity": 3,
            "evidence_path": f"data/evidence/{exam_id}_S01_1714299333.jpg"
        }
    ]
