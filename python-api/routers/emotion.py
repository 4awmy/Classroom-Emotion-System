from fastapi import APIRouter
from typing import List

router = APIRouter(tags=["Emotion"])

@router.get("/live")
def get_live_emotions(lecture_id: str, limit: int = 60):
    """
    Returns last n emotion rows for a lecture.
    """
    return [
        {
            "student_id": "231006367",
            "emotion": "Focused",
            "confidence": 1.0,
            "engagement_score": 1.0,
            "timestamp": "2026-04-30T10:05:00"
        },
        {
            "student_id": "231006412",
            "emotion": "Confused",
            "confidence": 0.55,
            "engagement_score": 0.55,
            "timestamp": "2026-04-30T10:05:05"
        }
    ]

@router.get("/confusion-rate")
def get_confusion_rate(lecture_id: str, window: int = 120):
    """
    Returns confusion rate over the last window seconds.
    """
    return {
        "lecture_id": lecture_id,
        "window_seconds": window,
        "confusion_rate": 0.42
    }
