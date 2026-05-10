from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from models import EmotionLog
from schemas import EmotionLogResponse, EmotionLogCreate
from typing import List, Optional
from datetime import datetime, timedelta
from sqlalchemy import func
from .websocket import manager

router = APIRouter()

@router.post("/log", response_model=EmotionLogResponse)
def log_emotion(
    log_in: EmotionLogCreate,
    db: Session = Depends(get_db)
):
    """
    Endpoint for remote Vision Nodes to log student emotions.
    Broadcasts the update via WebSocket.
    """
    new_log = EmotionLog(
        student_id=log_in.student_id,
        lecture_id=log_in.lecture_id,
        emotion=log_in.emotion,
        confidence=log_in.confidence,
        engagement_score=log_in.engagement_score,
        timestamp=log_in.timestamp or datetime.utcnow()
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    
    # Broadcast to listeners (Shiny portal)
    manager.broadcast_sync({
        "type": "emotion_update",
        "lecture_id": log_in.lecture_id,
        "student_id": log_in.student_id,
        "emotion": log_in.emotion,
        "engagement_score": log_in.engagement_score,
        "timestamp": new_log.timestamp.isoformat()
    })
    
    return new_log

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
    
    # Add confidence_rate alias for R/Shiny compatibility
    for log in logs:
        log.confidence_rate = log.confidence
        
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
