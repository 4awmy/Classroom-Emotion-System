from fastapi import APIRouter, UploadFile, File

router = APIRouter()

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...)
):
    """
    Mock roster upload endpoint.
    Accepts .xlsx file with student IDs, names, and Google Drive photo links.
    Phase 3 (T029) will implement real XLSX parsing + Drive download + face encoding.
    """
    return {
        "students_created": 127,
        "encodings_saved": 127
    }
