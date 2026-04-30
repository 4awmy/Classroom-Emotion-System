from fastapi import APIRouter, UploadFile, File

router = APIRouter(tags=["Roster"])

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...)
):
    """
    Multipart form with single XLSX field.
    """
    return {
        "students_created": 127,
        "encodings_saved": 120
    }
