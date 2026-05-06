from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.orm import Session
from pydantic import BaseModel
from database import get_db
from models import Lecture, Transcript, FocusStrike
from services.gemini_service import generate_fresh_brainer, generate_smart_notes
import logging
import os

router = APIRouter(tags=["Gemini / AI"])
logger = logging.getLogger(__name__)

class GeminiQuestionRequest(BaseModel):
    lecture_id: str

@router.post("/gemini/question")
async def get_gemini_question(request: GeminiQuestionRequest, db: Session = Depends(get_db)):
    """
    Generates a clarifying question based on current lecture content (slides).
    """
    lecture = db.query(Lecture).filter(Lecture.lecture_id == request.lecture_id).first()
    if not lecture:
        # Fallback if lecture not found during dev
        slide_text = f"General concepts for {request.lecture_id}"
    else:
        slide_text = f"Subject: {lecture.subject}, Title: {lecture.title}"

    question = generate_fresh_brainer(slide_text)
    return {"question": question}

# NOTE: /notes/{student_id}/plan MUST be registered BEFORE /notes/{student_id}/{lecture_id}
# so that FastAPI does not capture "plan" as the lecture_id path parameter.
@router.get("/notes/{student_id}/plan")
async def get_intervention_plan(student_id: str):
    """
    Returns the latest AI-generated intervention plan for a student.
    """
    plan_path = f"data/plans/{student_id}.md"
    if os.path.exists(plan_path):
        with open(plan_path, "r") as f:
            markdown_content = f.read()
    else:
        markdown_content = "## Intervention Plan\n\n1. Review lecture recordings for previous weeks.\n2. Participate in office hours.\n3. Complete practice exercises."

    return Response(content=markdown_content, media_type="text/markdown")

@router.get("/notes/{student_id}/{lecture_id}")
async def get_smart_notes(student_id: str, lecture_id: str, db: Session = Depends(get_db)):
    """
    Returns smart notes with highlight markers for a specific student and lecture.
    """
    # Fetch all transcript chunks for this lecture
    transcripts = db.query(Transcript).filter(Transcript.lecture_id == lecture_id).order_by(Transcript.timestamp.asc()).all()
    combined_transcript = " ".join([t.chunk_text for t in transcripts]) if transcripts else "No transcript available."

    # Fetch focus strikes for this student during this lecture
    strikes = db.query(FocusStrike).filter(
        FocusStrike.student_id == student_id,
        FocusStrike.lecture_id == lecture_id
    ).all()
    distraction_timestamps = [s.timestamp.strftime("%H:%M:%S") for s in strikes]

    notes = generate_smart_notes(combined_transcript, distraction_timestamps)
    return Response(content=notes, media_type="text/markdown")
