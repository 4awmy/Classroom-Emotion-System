from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
import models
import uuid
import os

router = APIRouter()

MATERIALS_DIR = "data/materials"

@router.post("/material")
async def upload_material(
    lecture_id: str = Form(...),
    lecturer_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    material_id = str(uuid.uuid4())[:8].upper()

    # Save file locally
    dest_dir = os.path.join(MATERIALS_DIR, material_id)
    os.makedirs(dest_dir, exist_ok=True)
    filename = file.filename or "upload"
    dest_path = os.path.join(dest_dir, filename)
    content = await file.read()
    with open(dest_path, "wb") as f:
        f.write(content)

    local_path = dest_path.replace("\\", "/")

    material = models.Material(
        material_id=material_id,
        lecture_id=lecture_id,
        lecturer_id=lecturer_id,
        title=title,
        drive_link=local_path
    )
    db.add(material)
    db.commit()

    return {
        "material_id": material_id,
        "lecture_id": lecture_id,
        "lecturer_id": lecturer_id,
        "title": title,
        "drive_link": local_path,
        "status": "uploaded"
    }
