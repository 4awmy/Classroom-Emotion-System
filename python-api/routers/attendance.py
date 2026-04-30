from fastapi import APIRouter
from typing import List
from pydantic import BaseModel

router = APIRouter(tags=["Attendance"])

class ManualAttendanceRecord(BaseModel):
    student_id: str
    status: str

class ManualAttendanceRequest(BaseModel):
    lecture_id: str
    records: List[ManualAttendanceRecord]

@router.post("/start")
def start_attendance(lecture_id: str):
    """
    Trigger AI attendance scanning.
    """
    return {"status": "ai_scanning"}

@router.post("/manual")
def submit_manual_attendance(request: ManualAttendanceRequest):
    """
    Manual attendance overrides.
    """
    return {"updated": len(request.records)}

@router.get("/qr/{lecture_id}")
def get_attendance_qr(lecture_id: str):
    """
    Returns QR code PNG as base64 string.
    """
    return {
        "qr_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    }
