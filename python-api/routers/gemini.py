from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Lecture, Transcript, FocusStrike, EmotionLog, Student
from services import gemini_service
import pdfplumber
import requests
import io
import os
from typing import Optional

router = APIRouter()

@router.post("/question")
def get_clarifying_question(lecture_id: str, db: Session = Depends(get_db)):
    """
    Generates a clarifying question from slide content using Gemini.
    """
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not lecture or not lecture.slide_url:
        return {"question": "Can you explain the key concepts we just covered?"}

    slide_text = ""
    try:
        # 1. Extract Drive File ID
        from routers.roster import extract_drive_id
        file_id = extract_drive_id(lecture.slide_url)
        
        if file_id:
            # 2. Download PDF
            resp = requests.get(f"https://drive.google.com/uc?export=download&id={file_id}", timeout=20)
            if resp.status_code == 200:
                # 3. Extract Text
                with pdfplumber.open(io.BytesIO(resp.content)) as pdf:
                    # Extract text from first 5 pages for context
                    slide_text = "\n".join([page.extract_text() or "" for page in pdf.pages[:5]])
    except Exception as e:
        print(f"[GEMINI] Slide extraction error: {e}")

    question = gemini_service.generate_fresh_brainer(slide_text or "No slide text available.")
    return {"question": question}
