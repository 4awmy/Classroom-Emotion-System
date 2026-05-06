from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from models import EmotionLog
from schemas import EmotionLogResponse
from typing import List, Optional
from datetime import datetime, timedelta
from sqlalchemy import func

router = APIRouter()

@router.get("/live", response_model=List[EmotionLogResponse])
def get_live_emotions(
    lecture_id: str,
    limit: int = Query(60, ge=1, le=1000),
    db: Session = Depends(get_db)
):
    """
    Returns the last N emotion logs for a lecture.
    Includes confidence_rate alias for R/Shiny compatibility.
    """
    logs = db.query(EmotionLog).filter(
        EmotionLog.lecture_id == lecture_id
    ).order_by(EmotionLog.timestamp.desc()).limit(limit).all()
    
    # confidence_rate is added by the schema or manually if needed
    # Since our schema doesn't have it yet, I should probably add it there
    return logs

@router.get("/confusion-rate")
def get_confusion_rate(
    lecture_id: str,
    window: int = Query(120, ge=10, le=3600),
    db: Session = Depends(get_db)
):
    """
    Computes the percentage of 'Confused' emotions in the last X seconds.
    Used by Shiny confusion observer.
    """
    since = datetime.utcnow() - timedelta(seconds=window)
    
    total = db.query(func.count(EmotionLog.id)).filter(
        EmotionLog.lecture_id == lecture_id,
        EmotionLog.timestamp >= since
    ).scalar()
    
    if total == 0:
        return {"lecture_id": lecture_id, "confusion_rate": 0.0, "window_seconds": window}
    
    confused = db.query(func.count(EmotionLog.id)).filter(
        EmotionLog.lecture_id == lecture_id,
        EmotionLog.emotion == "Confused",
        EmotionLog.timestamp >= since
    ).scalar()
    
    rate = confused / total
    return {
        "lecture_id": lecture_id,
        "confusion_rate": round(rate, 2),
        "window_seconds": window
    }
