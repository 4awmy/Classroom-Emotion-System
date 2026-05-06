from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from database import get_db
from models import AttendanceLog, Notification, Student
from typing import List
import qrcode
import io
import base64
import os
from datetime import datetime

router = APIRouter()

@router.post("/start")
def start_attendance(lecture_id: str):
    """
    Triggers AI attendance scanning (handled by vision_pipeline).
    """
    # Logic is actually in vision_pipeline.py which is triggered by session/start
    # This endpoint can be used to manually re-trigger or flag AI mode.
    return {"status": "scanning", "lecture_id": lecture_id}

@router.post("/manual")
def submit_manual_attendance(data: List[dict], db: Session = Depends(get_db)):
    """
    Manual attendance overrides.
    Expected data: [{"student_id": "...", "status": "Present"|"Absent", "reason": "..."}]
    """
    updated = 0
    for item in data:
        sid = item.get("student_id")
        lid = item.get("lecture_id") # Should be passed or part of data
        status = item.get("status")
        
        if not sid or not status: continue
        
        # Upsert manual entry
        entry = db.query(AttendanceLog).filter(
            AttendanceLog.student_id == sid,
            AttendanceLog.lecture_id == lid,
            AttendanceLog.method == "Manual"
        ).first()
        
        if not entry:
            entry = AttendanceLog(
                student_id=sid,
                lecture_id=lid,
                status=status,
                method="Manual",
                timestamp=datetime.utcnow()
            )
            db.add(entry)
        else:
            entry.status = status
            entry.timestamp = datetime.utcnow()
        updated += 1
    
    db.commit()
    return {"updated": updated, "status": "success"}

@router.get("/qr/{lecture_id}")
def get_attendance_qr(lecture_id: str):
    """
    Generates QR code PNG as base64 for student self-check-in.
    """
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(f"checkin:{lecture_id}")
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode()
    
    return {
        "qr_image_base64": img_str,
        "lecture_id": lecture_id
    }

@router.get("/snapshot/{lecture_id}/{student_id}")
def get_attendance_snapshot(lecture_id: str, student_id: str):
    """
    Returns visual proof (face crop) for a student.
    """
    path = f"data/snapshots/{lecture_id}/{student_id}.jpg"
    if os.path.exists(path):
        return FileResponse(path, media_type="image/jpeg")
    raise HTTPException(status_code=404, detail="Snapshot not found")

@router.post("/notify/lecturer")
def notify_lecturer(
    student_id: str,
    lecture_id: str,
    reason: str,
    db: Session = Depends(get_db)
):
    """
    Sends a notification to the lecturer (e.g. from Admin At-Risk panel).
    """
    # Find lecturer_id for this lecture
    from models import Lecture
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")
    
    new_notif = Notification(
        student_id=student_id,
        lecturer_id=lecture.lecturer_id,
        lecture_id=lecture_id,
        reason=reason,
        created_at=datetime.utcnow(),
        read=0
    )
    db.add(new_notif)
    db.commit()
    
    # WebSocket broadcast would happen here in a real system
    return {"status": "notified"}
