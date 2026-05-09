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

@router.post("/question", status_code=202)
async def get_clarifying_question(
    lecture_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Generates a clarifying question from slide content using Gemini (Async).
    Returns 202 Accepted immediately and pushes result via WebSocket.
    """
    lecture = db.query(Lecture).filter(Lecture.lecture_id == lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    background_tasks.add_task(
        process_question_task,
        lecture_id,
        lecture.slide_url
    )

    return {"status": "processing", "message": "AI is generating a question..."}


def extract_text_from_pdf(content: bytes) -> str:
    """Sync function to extract text from PDF bytes (offloaded to thread)."""
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        return "\n".join([page.extract_text() or "" for page in pdf.pages[:5]])


async def process_question_task(lecture_id: str, slide_url: Optional[str]):
    """Background task: download PDF, extract text, generate question, push via WS."""
    slide_text = "No slide text available."

    if slide_url:
        try:
            from routers.roster import extract_drive_id
            file_id = extract_drive_id(slide_url)
            if file_id:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(
                        f"https://drive.google.com/uc?export=download&id={file_id}",
                        timeout=20.0
                    )
                    if resp.status_code == 200:
                        slide_text = await anyio.to_thread.run_sync(
                            extract_text_from_pdf, resp.content
                        )
        except Exception as e:
            print(f"[GEMINI] Slide extraction error: {e}")

    question = gemini_service.generate_fresh_brainer(slide_text)
    await manager.broadcast({
        "type": "freshbrainer",
        "lecture_id": lecture_id,
        "question": question
    })
