from fastapi import APIRouter, UploadFile, File
from typing import Optional

router = APIRouter()

@router.post("/upload")
async def upload_roster(
    roster_csv: UploadFile = File(...),
    images_zip: UploadFile = File(...)
):
    # Mock roster processing
    return {
        "students_created": 30,
        "encodings_saved": 28
    }
