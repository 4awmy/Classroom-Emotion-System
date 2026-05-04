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
from services.gemini_service import generate_smart_notes, generate_intervention_plan
import os
import logging
from datetime import datetime

router = APIRouter()
logger = logging.getLogger(__name__)


def _parse_timestamp(ts) -> datetime:
    """Parse SQLite timestamp string or datetime object to datetime."""
    if isinstance(ts, datetime):
        return ts
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(str(ts), fmt)
        except ValueError:
            continue
    return datetime.utcnow()  # fallback — never crash on bad timestamp


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
    """T062: Generate smart notes from transcript + distraction timestamps."""
    transcripts = db.execute(
        text("SELECT chunk_text FROM transcripts WHERE lecture_id = :lid ORDER BY timestamp"),
        {"lid": lecture_id}
    ).fetchall()

    if not transcripts:
        return {"markdown": f"## Lecture {lecture_id} Notes\n\n*No transcript available.*"}

    transcript_text = " ".join(r.chunk_text for r in transcripts)

    strikes = db.execute(
        text("SELECT timestamp FROM focus_strikes WHERE student_id = :sid AND lecture_id = :lid ORDER BY timestamp"),
        {"sid": student_id, "lid": lecture_id}
    ).fetchall()

    # Bug 2 fix: parse timestamps safely regardless of SQLite returning str or datetime
    distraction_timestamps = [
        _parse_timestamp(r.timestamp).strftime("%H:%M") for r in strikes
    ]

    notes = generate_smart_notes(transcript_text, distraction_timestamps)
    return {"markdown": notes}
