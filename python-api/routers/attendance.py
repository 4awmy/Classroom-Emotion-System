import io
import qrcode
import base64
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from database import get_db
from models import AttendanceLog, Student
from schemas import AttendanceLogResponse
from datetime import datetime

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
    Note: In a full implementation, this might signal the vision pipeline.
    """
    return {"status": "ai_scanning", "lecture_id": lecture_id}

@router.post("/manual")
def submit_manual_attendance(request: ManualAttendanceRequest, db: Session = Depends(get_db)):
    """
    Manual attendance overrides. Bulk upserts attendance records.
    """
    updated_count = 0
    for record in request.records:
        # Check if record already exists for this lecture/student
        existing = db.query(AttendanceLog).filter(
            AttendanceLog.lecture_id == request.lecture_id,
            AttendanceLog.student_id == record.student_id
        ).first()
        
        if existing:
            existing.status = record.status
            existing.method = "Manual"
            existing.timestamp = datetime.utcnow()
        else:
            new_log = AttendanceLog(
                student_id=record.student_id,
                lecture_id=request.lecture_id,
                status=record.status,
                method="Manual"
            )
            db.add(new_log)
        updated_count += 1
    
    db.commit()
    return {"updated": updated_count}

@router.get("/qr/{lecture_id}")
def get_attendance_qr(lecture_id: str):
    """
    Generates a QR code PNG as base64 string for student check-in.
    """
    # The QR code data would typically be a signed token or a direct check-in URL
    qr_data = f"attendance:{lecture_id}"
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(qr_data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode()
    
    return {
        "lecture_id": lecture_id,
        "qr_base64": f"data:image/png;base64,{img_str}"
    }
