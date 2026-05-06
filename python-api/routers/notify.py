"""
Notify Router — mounted at /notify prefix
POST /notify/lecturer   → create notification + WS broadcast (T059)
GET  /notify/{student_id} → list unread notifications for student
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Notification, Lecture
from datetime import datetime

router = APIRouter()


@router.post("/lecturer")
async def notify_lecturer(
    student_id: str,
    lecture_id: str,
    reason: str,
    db: Session = Depends(get_db),
):
    """
    T059 — Creates a notification for the lecturer of a given lecture.
    Called by the Admin At-Risk panel when flagging a student.
    Also broadcasts the notification over WebSocket so the Shiny
    dashboard updates without a page reload.
    """
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    notif = Notification(
        student_id=student_id,
        lecturer_id=lecture.lecturer_id,
        lecture_id=lecture_id,
        reason=reason,
        created_at=datetime.utcnow(),
        read=0,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)

    # Broadcast to all connected WebSocket clients
    try:
        from services.websocket import manager
        await manager.broadcast({
            "type": "notification",
            "student_id": student_id,
            "lecture_id": lecture_id,
            "reason": reason,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
    except Exception:
        pass  # WS broadcast is best-effort — don't fail the HTTP response

    return {"status": "notified", "notification_id": notif.id}


@router.get("/{student_id}")
def get_notifications(student_id: str, db: Session = Depends(get_db)):
    """Returns all unread notifications for a student."""
    notifications = (
        db.query(Notification)
        .filter(
            Notification.student_id == student_id,
            Notification.read == 0,
        )
        .order_by(Notification.created_at.desc())
        .all()
    )
    return notifications
