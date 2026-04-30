from fastapi import APIRouter, UploadFile, File, Form

router = APIRouter(tags=["Upload"])

@router.post("/material")
async def upload_material(
    lecture_id: str = Form(...),
    lecturer_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...)
):
    return {
        "material_id": "M01",
        "lecture_id": lecture_id,
        "lecturer_id": lecturer_id,
        "title": title,
        "drive_link": "https://drive.google.com/file/d/mock_id/view",
        "status": "uploaded"
    }
