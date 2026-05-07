"""
Notes Router — mounted at /notes prefix
GET /notes/{student_id}/plan           → intervention plan (T063)
GET /notes/{student_id}/{lecture_id}   → smart notes (T062)

IMPORTANT: /plan route MUST be declared before /{lecture_id} so FastAPI
does not capture "plan" as a lecture_id path segment.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from services.gemini_service import generate_intervention_plan
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/{student_id}/plan")
async def get_intervention_plan(student_id: str, db: Session = Depends(get_db)):
    """T063: Generate AI intervention plan from student's emotion history."""
    # Return cached plan if exists and recent
    plan_path = f"data/plans/{student_id}.md"
    if os.path.exists(plan_path):
        with open(plan_path, encoding="utf-8") as f:
            return {"markdown": f.read()}

    rows = db.execute(
        text("""
            SELECT lecture_id, emotion, engagement_score, timestamp
            FROM emotion_log
            WHERE student_id = :sid
            ORDER BY timestamp ASC
        """),
        {"sid": student_id}
    ).fetchall()

    if not rows:
        raise HTTPException(status_code=404, detail="No emotion data found for student")

    history_lines = [
        f"Lecture {r.lecture_id}: {r.emotion} (score={r.engagement_score:.2f})"
        for r in rows
    ]
    history_text = "\n".join(history_lines)

    plan = generate_intervention_plan(history_text)

    os.makedirs("data/plans", exist_ok=True)
    with open(plan_path, "w", encoding="utf-8") as f:
        f.write(plan)

    return {"markdown": plan}


@router.get("/{student_id}/{lecture_id}")
async def get_smart_notes(student_id: str, lecture_id: str, db: Session = Depends(get_db)):
    """T062: Smart notes endpoint — transcript source retired; returns placeholder."""
    return {"markdown": f"## Lecture {lecture_id} Notes\n\n*Lecture transcript not available.*"}
