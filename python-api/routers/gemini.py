"""
Gemini Router — mounted at /gemini prefix
POST /gemini/question  → fresh-brainer question (T061)

Notes endpoints are in routers/notes.py mounted at /notes prefix.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from services.gemini_service import generate_fresh_brainer
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


class GeminiQuestionRequest(BaseModel):
    lecture_id: str


@router.post("/question")
async def get_gemini_question(request: GeminiQuestionRequest, db: Session = Depends(get_db)):
    """T061: Generate a fresh-brainer question from the current lecture's slide content."""
    lecture = db.execute(
        text("SELECT slide_url, title FROM lectures WHERE lecture_id = :lid"),
        {"lid": request.lecture_id}
    ).fetchone()

    recent_transcript = db.execute(
        text("""
            SELECT chunk_text FROM transcripts
            WHERE lecture_id = :lid
            ORDER BY timestamp DESC
            LIMIT 10
        """),
        {"lid": request.lecture_id}
    ).fetchall()

    if recent_transcript:
        slide_text = " ".join(r.chunk_text for r in recent_transcript)
    elif lecture and lecture.title:
        slide_text = f"Lecture: {lecture.title}"
    else:
        slide_text = f"Lecture: {request.lecture_id}"

    question = generate_fresh_brainer(slide_text)
    return {"question": question}
