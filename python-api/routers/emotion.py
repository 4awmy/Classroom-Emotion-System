from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from datetime import datetime, timedelta
from database import get_db
from models import EmotionLog
from schemas import EmotionLogResponse

router = APIRouter(tags=["Emotion"])

@router.get("/live", response_model=List[EmotionLogResponse])
def get_live_emotions(lecture_id: str, limit: int = 60, db: Session = Depends(get_db)):
    """
    Returns last n emotion rows for a lecture from the database.
    """
    emotions = db.query(EmotionLog)\
        .filter(EmotionLog.lecture_id == lecture_id)\
        .order_by(EmotionLog.timestamp.desc())\
        .limit(limit)\
        .all()
    return emotions

@router.get("/confusion-rate")
def get_confusion_rate(lecture_id: str, window: int = 120, db: Session = Depends(get_db)):
    """
    Returns confusion rate over the last window seconds from the database.
    confusion_rate = count(Confused) / total_readings in window
    """
    since = datetime.utcnow() - timedelta(seconds=window)
    
    # Get total count and confused count in one go
    stats = db.query(
        func.count(EmotionLog.id).label("total"),
        func.count(func.nullif(EmotionLog.emotion != "Confused", True)).label("confused")
    ).filter(
        EmotionLog.lecture_id == lecture_id,
        EmotionLog.timestamp >= since
    ).first()
    
    total = stats.total if stats and stats.total else 0
    confused = stats.confused if stats and stats.confused else 0
    
    rate = confused / total if total > 0 else 0.0
    
    return {
        "lecture_id": lecture_id,
        "window_seconds": window,
        "total_readings": total,
        "confused_count": confused,
        "confusion_rate": round(rate, 4)
    }
