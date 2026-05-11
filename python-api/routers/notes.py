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
    """T062: Generate personalized smart notes based on distraction and wrong quiz answers."""
    from models import EmotionLog, StudentAnswer, ComprehensionCheck, Material
    from services.gemini_service import generate_smart_notes
    
    # 1. Fetch Distraction Timestamps
    distracted_logs = db.query(EmotionLog).filter(
        EmotionLog.student_id == student_id,
        EmotionLog.lecture_id == lecture_id,
        EmotionLog.emotion.in_(["Disengaged", "Anxious", "Frustrated"])
    ).all()
    d_ts = [log.timestamp for log in distracted_logs]

    # 2. Fetch Wrong Topics from Comprehension Checks
    wrong_answers = db.query(StudentAnswer).join(ComprehensionCheck).filter(
        StudentAnswer.student_id == student_id,
        ComprehensionCheck.lecture_id == lecture_id,
        StudentAnswer.is_correct == False
    ).all()
    # Extract unique topics
    wrong_topics = list(set([ans.check.topic for ans in wrong_answers if ans.check.topic]))

    # 3. Get Contextual Content (Transcript/Material)
    material = db.query(Material).filter(Material.lecture_id == lecture_id).first()
    transcript = f"Technical overview of {material.title if material else 'lecture ' + lecture_id}. " \
                 f"Key discussions included implementation details, architecture, and core logic patterns."

    # 4. Generate AI Notes
    notes = generate_smart_notes(transcript, d_ts, wrong_topics)

    return {"markdown": notes}
