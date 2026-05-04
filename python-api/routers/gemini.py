"""
Gemini Router — AI-powered endpoints
T061: POST /gemini/question       — fresh-brainer question from slide content
T062: GET  /notes/{sid}/{lid}     — smart notes from transcript + distraction timestamps
T063: GET  /notes/{sid}/plan      — intervention plan from student emotion history
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from services.gemini_service import (
    generate_fresh_brainer,
    generate_smart_notes,
    generate_intervention_plan,
)
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


class GeminiQuestionRequest(BaseModel):
    lecture_id: str


# NOTE: /notes/{student_id}/plan MUST be declared BEFORE /notes/{student_id}/{lecture_id}
# so FastAPI does not capture "plan" as a lecture_id path segment.

@router.get("/notes/{student_id}/plan")
async def get_intervention_plan(student_id: str, db: Session = Depends(get_db)):
    """T063: Generate AI intervention plan from student's emotion history."""
    rows = db.execute(
        text("""
            SELECT el.lecture_id, el.emotion, el.engagement_score, el.timestamp
            FROM emotion_log el
            WHERE el.student_id = :sid
            ORDER BY el.timestamp ASC
        """),
        {"sid": student_id}
    ).fetchall()

    if not rows:
        # Return cached plan from filesystem if it exists
        plan_path = f"data/plans/{student_id}.md"
        if os.path.exists(plan_path):
            with open(plan_path) as f:
                return {"plan": f.read()}
        raise HTTPException(status_code=404, detail="No emotion data found for student")

    # Build history summary for Gemini
    history_lines = []
    for r in rows:
        history_lines.append(f"Lecture {r.lecture_id}: {r.emotion} (score={r.engagement_score:.2f})")
    history_text = "\n".join(history_lines)

    plan = generate_intervention_plan(history_text)

    # Cache to filesystem
    plan_path = f"data/plans/{student_id}.md"
    os.makedirs("data/plans", exist_ok=True)
    with open(plan_path, "w", encoding="utf-8") as f:
        f.write(plan)

    return {"plan": plan}


@router.get("/notes/{student_id}/{lecture_id}")
async def get_smart_notes(student_id: str, lecture_id: str, db: Session = Depends(get_db)):
    """T062: Generate smart notes from lecture transcript + student's distraction timestamps."""
    # Fetch transcript for this lecture
    transcripts = db.execute(
        text("SELECT chunk_text, timestamp FROM transcripts WHERE lecture_id = :lid ORDER BY timestamp"),
        {"lid": lecture_id}
    ).fetchall()

    if not transcripts:
        return {"markdown": f"## Lecture {lecture_id} Notes\n\n*No transcript available for this lecture.*"}

    transcript_text = " ".join(r.chunk_text for r in transcripts)

    # Fetch focus strikes (distraction timestamps) for this student in this lecture
    strikes = db.execute(
        text("SELECT timestamp FROM focus_strikes WHERE student_id = :sid AND lecture_id = :lid ORDER BY timestamp"),
        {"sid": student_id, "lid": lecture_id}
    ).fetchall()

    distraction_timestamps = [r.timestamp.strftime("%H:%M") for r in strikes]

    notes = generate_smart_notes(transcript_text, distraction_timestamps)
    return {"markdown": notes}


@router.post("/question")
async def get_gemini_question(request: GeminiQuestionRequest, db: Session = Depends(get_db)):
    """T061: Generate a fresh-brainer question from the current lecture's slide content."""
    lecture = db.execute(
        text("SELECT slide_url, title FROM lectures WHERE lecture_id = :lid"),
        {"lid": request.lecture_id}
    ).fetchone()

    if not lecture or not lecture.slide_url:
        # Use fallback if no slide URL
        question = generate_fresh_brainer(f"Lecture: {request.lecture_id}")
        return {"question": question}

    # Fetch recent transcript as slide text proxy if PDF extraction not available
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
    else:
        slide_text = f"Lecture: {lecture.title or request.lecture_id}"

    question = generate_fresh_brainer(slide_text)
    return {"question": question}
