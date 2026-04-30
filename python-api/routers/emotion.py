from fastapi import APIRouter
from typing import List

router = APIRouter()

@router.get("/live")
def get_live_emotions(lecture_id: str, limit: int = 60):
    """
    Mock endpoint for live emotion stream.
    As per ARCHITECTURE.md 3.4
    """
    return [
        {
            "student_id": "231006367",
            "lecture_id": lecture_id,
            "timestamp": "2026-04-28T09:05:00",
            "emotion": "Focused",
            "confidence": 1.0,
            "engagement_score": 1.0
        },
        {
            "student_id": "231006412",
            "lecture_id": lecture_id,
            "timestamp": "2026-04-28T09:05:05",
            "emotion": "Confused",
            "confidence": 0.55,
            "engagement_score": 0.55
        }
    ]

@router.get("/confusion-rate")
def get_confusion_rate(lecture_id: str, window: int = 120):
    """
    Mock endpoint for class confusion rate.
    As per ARCHITECTURE.md 3.4
    """
    return {
        "lecture_id": lecture_id,
        "confusion_rate": 0.42,
        "window_seconds": window
    }
