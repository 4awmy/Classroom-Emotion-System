from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
import threading
import time
from sqlalchemy.orm import Session
from services.websocket import manager
from database import get_db, SessionLocal
import models
from models import FocusStrike
from schemas import LectureResponse
from services.vision_pipeline import run_pipeline
import os

router = APIRouter()
logger = logging.getLogger(__name__)

# Global tracking for active lecture tasks
# lecture_id -> {"stop_event": threading.Event, "thread": threading.Thread}
active_lecture_tasks = {}

class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: Optional[str] = None
    subject: Optional[str] = None
    slide_url: str
    context: Optional[str] = "lecture"  # lecture | exam
    exam_id: Optional[str] = None

class SessionEndRequest(BaseModel):
    lecture_id: str

class SessionBroadcastRequest(BaseModel):
    type: str
    question: str
    lecture_id: str

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    # 1. Persist lecture to DB
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
    if not lecture:
        lecture = models.Lecture(
            lecture_id=request.lecture_id,
            lecturer_id=request.lecturer_id,
            title=request.title,
            subject=request.subject,
            slide_url=request.slide_url,
            start_time=datetime.utcnow()
        )
        db.add(lecture)
    else:
        lecture.start_time = datetime.utcnow()
        lecture.end_time = None
        lecture.slide_url = request.slide_url
    
    db.commit()

    # 2. Spawn background tasks
    if request.lecture_id not in active_lecture_tasks:
        stop_event = threading.Event()

        # Vision Pipeline (Thread) with robust retry wrapper
        camera_url = os.getenv("CLASSROOM_CAMERA_URL", "0") # Default to webcam
        
        def start_vision_with_retry():
            retry_count = 0
            max_retries = 10
            backoff = 2
            
            while retry_count < max_retries and not stop_event.is_set():
                try:
                    logger.info(f"[SESSION] Starting vision pipeline for {request.lecture_id} (Attempt {retry_count + 1})")
                    run_pipeline(request.lecture_id, camera_url, stop_event, request.context, request.exam_id)
                    
                    # If run_pipeline returns, check if it was intentional
                    if stop_event.is_set():
                        logger.info(f"[SESSION] Vision pipeline for {request.lecture_id} stopped intentionally.")
                        break
                    
                    logger.warning(f"[SESSION] Vision pipeline for {request.lecture_id} exited unexpectedly. Retrying...")
                except Exception as e:
                    logger.error(f"[SESSION] Vision pipeline crash for {request.lecture_id}: {e}")
                
                retry_count += 1
                wait_time = min(backoff ** retry_count, 30)
                logger.info(f"[SESSION] Waiting {wait_time}s before next retry...")
                if stop_event.wait(timeout=wait_time):
                    break
            
            if retry_count >= max_retries:
                logger.error(f"[SESSION] Vision pipeline for {request.lecture_id} failed after {max_retries} attempts.")

        vision_thread = threading.Thread(
            target=start_vision_with_retry,
            daemon=True
        )
        vision_thread.start()

        active_lecture_tasks[request.lecture_id] = {
            "stop_event": stop_event,
            "thread": vision_thread
        }

    # 3. Broadcast session:start to all clients
    await manager.broadcast({
        "type": "session:start",
        "lecture_id": request.lecture_id,
        "slide_url": request.slide_url,
        "lecturer_id": request.lecturer_id,
        "context": request.context,
        "exam_id": request.exam_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "started", "lecture_id": request.lecture_id, "context": request.context}


@router.post("/end")
async def end_session(request: SessionEndRequest, db: Session = Depends(get_db)):
    # 1. Update lecture end_time in DB
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
    if lecture:
        lecture.end_time = datetime.utcnow()
        db.commit()

    # 2. Stop background tasks
    if request.lecture_id in active_lecture_tasks:
        tasks = active_lecture_tasks.pop(request.lecture_id)
        tasks["stop_event"].set()

    # 3. Broadcast session:end to all clients
    await manager.broadcast({
        "type": "session:end",
        "lecture_id": request.lecture_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "ended", "lecture_id": request.lecture_id}

@router.post("/broadcast")
async def broadcast_event(request: SessionBroadcastRequest):
    # Broadcast the event (e.g., freshbrainer)
    await manager.broadcast({
        "type": request.type,
        "question": request.question,
        "lecture_id": request.lecture_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "broadcast"}

@router.get("/upcoming", response_model=List[LectureResponse])
async def get_upcoming_sessions(db: Session = Depends(get_db)):
    return db.query(models.Lecture).filter(models.Lecture.end_time == None).all()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        await websocket.send_json({
            "type": "connection_established",
            "message": "Connected to Classroom Emotion System WebSocket"
        })
        
        while True:
            data = await websocket.receive_json()
            if isinstance(data, dict) and data.get("type") == "focus_strike":
                student_id = data.get("student_id")
                lecture_id = data.get("lecture_id")
                strike_type = data.get("strike_type", "app_background")
                
                persisted = False
                if student_id and lecture_id:
                    db: Session = SessionLocal()
                    try:
                        db.add(FocusStrike(
                            student_id=student_id,
                            lecture_id=lecture_id,
                            timestamp=datetime.utcnow(),
                            strike_type=strike_type
                        ))
                        db.commit()
                        persisted = True
                    except Exception as e:
                        logger.error("Failed to persist focus strike: %s", e)
                        db.rollback()
                    finally:
                        db.close()
                
                if persisted:
                    await websocket.send_json({
                        "type": "strike_ack",
                        "student_id": student_id,
                        "timestamp": datetime.utcnow().isoformat() + "Z"
                    })
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as exc:
        logger.exception("WebSocket error: %s", exc)
        manager.disconnect(websocket)
