from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from database import get_db
import models
from schemas import EmotionLogResponse

router = APIRouter()

@router.get("/live", response_model=List[EmotionLogResponse])
def get_live_emotions(lecture_id: str, limit: int = 60, db: Session = Depends(get_db)):
    """
    Endpoint for live emotion stream.
    As per ARCHITECTURE.md 3.4
    """
    return db.query(models.EmotionLog).filter(
        models.EmotionLog.lecture_id == lecture_id
    ).order_by(models.EmotionLog.timestamp.desc()).limit(limit).all()

@router.get("/confusion-rate")
def get_confusion_rate(lecture_id: str, window: int = 120, db: Session = Depends(get_db)):
    """
    Endpoint for class confusion rate.
    As per ARCHITECTURE.md 3.4
    """
    # In a real scenario, we would filter by the last 'window' seconds
    # For Phase 1, we'll just calculate it from all logs for this lecture
    total = db.query(models.EmotionLog).filter(models.EmotionLog.lecture_id == lecture_id).count()
    if total == 0:
        return {
            "lecture_id": lecture_id,
            "confusion_rate": 0.0,
            "window_seconds": window
        }
    
    confused = db.query(models.EmotionLog).filter(
        models.EmotionLog.lecture_id == lecture_id,
        models.EmotionLog.emotion == "Confused"
    ).count()
    
    return {
        "lecture_id": lecture_id,
        "confusion_rate": confused / total,
        "window_seconds": window
    }
