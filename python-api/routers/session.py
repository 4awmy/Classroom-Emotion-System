from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
import threading
from sqlalchemy.orm import Session
from services.websocket import manager
from database import get_db, SessionLocal
import models
from models import FocusStrike
from schemas import LectureResponse
try:
    from services import vision_pipeline
    _VISION_AVAILABLE = True
except ImportError:
    vision_pipeline = None
    _VISION_AVAILABLE = False

try:
    from services.stream_state import latest_frames
except ImportError:
    latest_frames = {}
import os
import asyncio

router = APIRouter()
logger = logging.getLogger(__name__)

# Global tracking for active lecture tasks
active_lecture_tasks = {}

async def gen_frames(lecture_id: str):
    """MJPEG Frame Generator with shared state."""
    logger.info(f"[STREAM] Starting generator for {lecture_id}")
    retry_count = 0
    while True:
        frame = latest_frames.get(lecture_id)
        if frame:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
            retry_count = 0
        else:
            retry_count += 1
            if retry_count % 50 == 0:
                logger.warning(f"[STREAM] No frames found for {lecture_id} in shared state.")
            
            # Serve a placeholder "No Signal" if requested and still missing
            if retry_count > 100:
                # We could yield a black image here
                pass
                
        await asyncio.sleep(0.06) # ~15 FPS sync

@router.get("/video_feed/{lecture_id}")
async def video_feed(lecture_id: str):
    """Streaming endpoint for the live vision feed."""
    return StreamingResponse(gen_frames(lecture_id),
                             media_type="multipart/x-mixed-replace; boundary=frame")


class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: Optional[str] = None
    subject: Optional[str] = None
    slide_url: Optional[str] = None
    camera_url: Optional[str] = None
    context: Optional[str] = "lecture"
    exam_id: Optional[str] = None

class SessionEndRequest(BaseModel):
    lecture_id: str

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    try:
        logger.info(f"[*] Starting session request: {request.lecture_id}")
        lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
        now = datetime.utcnow()

        if not lecture:
            lecture = models.Lecture(
                lecture_id=request.lecture_id,
                lecturer_id=request.lecturer_id,
                title=request.title or f"Lecture {request.lecture_id}",
                slide_url=request.slide_url,
                start_time=now,
                scheduled_start=now,
                session_type=request.context or "lecture"
            )
            db.add(lecture)
        else:
            lecture.start_time = now
            lecture.end_time = None
        
        db.commit()
        db.refresh(lecture)

        # Force kill previous if exists
        if request.lecture_id in active_lecture_tasks:
            active_lecture_tasks[request.lecture_id]["stop_event"].set()
            await asyncio.sleep(1)

        stop_event = threading.Event()
        camera_url = request.camera_url or os.getenv("CLASSROOM_CAMERA_URL", "0")
        
        # Start Vision Pipeline in daemon thread (only if running locally with vision libs)
        if _VISION_AVAILABLE and vision_pipeline:
            vision_thread = threading.Thread(
                target=vision_pipeline.run_pipeline,
                args=(request.lecture_id, camera_url, stop_event, request.context, request.exam_id),
                daemon=True
            )
            vision_thread.start()
            active_lecture_tasks[request.lecture_id] = {"stop_event": stop_event, "thread": vision_thread}
        else:
            logger.info("[SESSION] Vision pipeline not available in cloud — running in API-only mode")
            active_lecture_tasks[request.lecture_id] = {"stop_event": stop_event, "thread": None}

        await manager.broadcast({
            "type": "session:start",
            "lecture_id": request.lecture_id,
            "lecturer_id": request.lecturer_id,
            "timestamp": now.isoformat() + "Z"
        })
        return {"status": "started", "lecture_id": request.lecture_id}
    except Exception as e:
        logger.error(f"start_session error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/end")
async def end_session(request: SessionEndRequest, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
    if lecture:
        lecture.end_time = datetime.utcnow()
        db.commit()

    if request.lecture_id in active_lecture_tasks:
        tasks = active_lecture_tasks.pop(request.lecture_id)
        tasks["stop_event"].set()

    await manager.broadcast({
        "type": "session:end",
        "lecture_id": request.lecture_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "ended", "lecture_id": request.lecture_id}

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            # Handle strikes...
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except:
        manager.disconnect(websocket)
