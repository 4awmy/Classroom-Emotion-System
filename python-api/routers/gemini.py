from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from database import get_db
from models import Lecture, FocusStrike, EmotionLog, Student
from services import gemini_service
from services.websocket import manager
import pdfplumber
import httpx
import io
import os
import anyio
from typing import Optional

router = APIRouter()

def extract_text_from_pdf(content: bytes) -> str:
    """Extract text from first 5 pages of a PDF."""
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            return "\n".join([page.extract_text() or "" for page in pdf.pages[:5]])
    except Exception:
        return ""


async def _fetch_material_text(db: Session, class_id: str) -> tuple[str, str]:
    """
    Find the most recent material for a class, download its PDF, and extract text.
    Returns (slide_text, material_title).
    """
    from models import Material
    material = (
        db.query(Material)
        .join(Lecture, Material.lecture_id == Lecture.lecture_id)
        .filter(Lecture.class_id == class_id)
        .order_by(Material.uploaded_at.desc())
        .first()
    )
    if not material or not material.drive_link:
        return "No lecture materials found.", ""

    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            resp = await client.get(material.drive_link, timeout=25.0)
            if resp.status_code == 200 and len(resp.content) > 500:
                text = await anyio.to_thread.run_sync(
                    extract_text_from_pdf, resp.content
                )
                return text or "Could not extract text from PDF.", material.title
    except Exception as e:
        print(f"[GEMINI] Material download error: {e}")

    return "Material download failed.", material.title


@router.post("/question")
async def get_clarifying_question(
    lecture_id: str,
    db: Session = Depends(get_db)
):
    """
    Generates a clarifying question from the most recent class material using Gemini.
    Returns the question synchronously so Shiny can display it directly.
    Also broadcasts via WebSocket for connected student devices.
    """
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    slide_text, material_title = await _fetch_material_text(db, lecture.class_id)
    question = gemini_service.generate_fresh_brainer(slide_text)

    # Broadcast to any connected student devices
    await manager.broadcast({
        "type": "freshbrainer",
        "lecture_id": lecture_id,
        "question": question
    })

    return {
        "status": "ok",
        "question": question,
        "material_title": material_title,
        "lecture_id": lecture_id,
    }


async def process_question_task(lecture_id: str, slide_url: Optional[str]):
    """Legacy background task — kept for backward compat."""
    pass

@router.get("/refresher")
async def get_refresher(lecture_id: str, db: Session = Depends(get_db)):
    """
    Generates a refresher summary of the PREVIOUS lecture for this class.
    """
    current_lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not current_lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")
    
    prev_lecture = db.query(Lecture).filter(
        Lecture.class_id == current_lecture.class_id,
        Lecture.start_time < current_lecture.start_time
    ).order_by(Lecture.start_time.desc()).first()
    
    if not prev_lecture:
        return {"summary": "Welcome! This is the first session of the course."}
    
    from models import Material
    material = db.query(Material).filter(Material.lecture_id == prev_lecture.lecture_id).first()
    text = f"Recap of {prev_lecture.title}. Focused on {material.title if material else 'key concepts'}."

    summary = gemini_service.generate_refresher(text)
    return {"summary": summary, "prev_lecture_id": prev_lecture.lecture_id}

@router.post("/intervention/push")
async def push_intervention(lecture_id: str, content: str):
    """
    Broadcasts a 'Fresh Brainer' to students via WebSockets.
    """
    await manager.broadcast({
        "type": "intervention",
        "sub_type": "fresh_brainer",
        "lecture_id": lecture_id,
        "content": content
    })
    return {"status": "pushed"}

@router.post("/check/generate")
async def generate_check(lecture_id: str, db: Session = Depends(get_db)):
    """
    Generates an AI MCQ and saves it to the database for tracking.
    """
    from models import Material, ComprehensionCheck
    material = db.query(Material).filter(Material.lecture_id == lecture_id).first()
    
    # Generate MCQ
    text = f"Lecture: {lecture_id}. Topics: {material.title if material else 'General session'}"
    mcq = gemini_service.generate_comprehension_check(text)
    
    # Save to DB
    new_check = ComprehensionCheck(
        lecture_id=lecture_id,
        material_id=material.material_id if material else None,
        question=mcq['question'],
        options="|".join(mcq['options']), # Use pipe as separator
        correct_option=mcq['correct_option'],
        topic=mcq['topic']
    )
    db.add(new_check)
    db.commit()
    db.refresh(new_check)
    
    return {
        "id": new_check.id,
        "question": new_check.question,
        "options": mcq['options'],
        "topic": new_check.topic
    }

@router.post("/check/submit")
async def submit_check(check_id: int, student_id: str, chosen_option: int, db: Session = Depends(get_db)):
    """
    Students submit their answer to a comprehension check.
    """
    from models import ComprehensionCheck, StudentAnswer
    check = db.query(ComprehensionCheck).filter(ComprehensionCheck.id == check_id).first()
    if not check:
        raise HTTPException(status_code=404, detail="Check not found")
    
    is_correct = (chosen_option == check.correct_option)
    
    ans = StudentAnswer(
        check_id=check_id,
        student_id=student_id,
        chosen_option=chosen_option,
        is_correct=is_correct
    )
    db.add(ans)
    db.commit()
    
    return {"is_correct": is_correct}
