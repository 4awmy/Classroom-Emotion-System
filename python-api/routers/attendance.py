from fastapi import APIRouter
from typing import List

router = APIRouter()

@router.post("/start")
def start_attendance(lecture_id: str):
    """
    Mock endpoint to trigger AI attendance scanning.
    As per ARCHITECTURE.md 3.6
    """
    return {"status": "scanning", "lecture_id": lecture_id}

@router.post("/manual")
def submit_manual_attendance(data: List[dict]):
    """
    Mock endpoint for manual attendance overrides.
    As per ARCHITECTURE.md 3.6
    """
    return {"updated": len(data), "status": "success"}

@router.get("/qr/{lecture_id}")
def get_attendance_qr(lecture_id: str):
    """
    Mock endpoint for QR code fallback.
    As per ARCHITECTURE.md 3.6
    """
    return {
        "qr_image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
        "lecture_id": lecture_id
    }
