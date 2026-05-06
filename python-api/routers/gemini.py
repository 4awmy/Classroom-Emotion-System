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

@router.get("/{student_id}/{lecture_id}")
def get_smart_notes(student_id: str, lecture_id: str, db: Session = Depends(get_db)):
    """
    Generates personalized smart notes with distraction markers.
    """
    # 1. Fetch transcripts
    transcripts = db.query(Transcript).filter(Transcript.lecture_id == lecture_id).order_by(Transcript.timestamp).all()
    if not transcripts:
        raise HTTPException(status_code=404, detail="No transcripts found for this lecture.")
    
    combined_text = "\n".join([t.chunk_text for t in transcripts])
    
    # 2. Fetch distraction timestamps (FocusStrikes)
    strikes = db.query(FocusStrike).filter(
        FocusStrike.student_id == student_id,
        FocusStrike.lecture_id == lecture_id
    ).all()
    distraction_ts = [s.timestamp for s in strikes]
    
    # 3. Call Gemini
    notes_md = gemini_service.generate_smart_notes(combined_text, distraction_ts)
    return {"markdown": notes_md}

@router.get("/{student_id}/plan")
def get_intervention_plan(student_id: str):
    """
    Returns the latest generated intervention plan for a student.
    Plans are generated nightly by export_service.
    """
    path = f"data/plans/{student_id}.md"
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        return {"markdown": content}
    
    # Optional: Generate on-the-fly if missing?
    # For MVP, follow T063 and return 404
    raise HTTPException(status_code=404, detail="Plan not yet generated. Please check back tomorrow.")
