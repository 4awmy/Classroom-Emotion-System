import os
import logging
from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import Material
from datetime import datetime
import uuid

router = APIRouter(tags=["Upload"])
logger = logging.getLogger(__name__)

@router.post("/material")
async def upload_material(
    lecture_id: str = Form(...),
    lecturer_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Uploads a lecture material (PDF/PPTX) and saves the reference to the database.
    In production, this uploads to Google Drive.
    """
    try:
        # Generate a unique ID for the material
        material_id = f"M{uuid.uuid4().hex[:6].upper()}"
        
        # Placeholder for real Google Drive upload logic
        drive_link = f"https://drive.google.com/mock/file/{material_id}/view"
        
        # Log the upload
        logger.info("Received file %s for lecture %s", file.filename, lecture_id)
        
        # Save to database
        new_material = Material(
            material_id=material_id,
            lecture_id=lecture_id,
            lecturer_id=lecturer_id,
            title=title,
            drive_link=drive_link,
            uploaded_at=datetime.utcnow()
        )
        db.add(new_material)
        db.commit()
        
        return {
            "material_id": material_id,
            "lecture_id": lecture_id,
            "lecturer_id": lecturer_id,
            "title": title,
            "drive_link": drive_link,
            "status": "uploaded",
            "filename": file.filename
        }
        
    except Exception as e:
        logger.exception("Material upload failed")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload material: {str(e)}"
        )
