from fastapi import APIRouter, UploadFile, File, Form, Depends
from sqlalchemy.orm import Session
from database import get_db
import models
import uuid

router = APIRouter()

@router.post("/material")
async def upload_material(
    lecture_id: str = Form(...),
    lecturer_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # In Phase 1, we just mock the drive link and persist the record
    material_id = str(uuid.uuid4())[:8].upper()
    
    material = models.Material(
        material_id=material_id,
        lecture_id=lecture_id,
        lecturer_id=lecturer_id,
        title=title,
        drive_link="https://drive.google.com/file/d/mock_id/view"
    )
    db.add(material)
    db.commit()
    
    return {
        "material_id": material_id,
        "lecture_id": lecture_id,
        "lecturer_id": lecturer_id,
        "title": title,
        "drive_link": "https://drive.google.com/file/d/mock_id/view",
        "status": "uploaded"
    }
