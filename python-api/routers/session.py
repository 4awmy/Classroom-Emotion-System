from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
import threading
import shutil
from pathlib import Path
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
        await asyncio.sleep(0.06)

@router.get("/video_feed/{lecture_id}")
async def video_feed(lecture_id: str):
    """Streaming endpoint for the live vision feed."""
    return StreamingResponse(gen_frames(lecture_id),
                             media_type="multipart/x-mixed-replace; boundary=frame")


class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    class_id: Optional[str] = None
    title: Optional[str] = None
    slide_url: Optional[str] = None
    camera_url: Optional[str] = None
    context: Optional[str] = "lecture"
    exam_id: Optional[str] = None

class SessionEndRequest(BaseModel):
    lecture_id: str

def stop_active_task(lecture_id: str):
    if lecture_id in active_lecture_tasks:
        tasks = active_lecture_tasks.pop(lecture_id)
        tasks["stop_event"].set()

def remove_snapshot_dir(lecture_id: str):
    snapshots_root = Path("data/snapshots").resolve()
    target = (snapshots_root / lecture_id).resolve()
    if snapshots_root in target.parents and target.exists():
        shutil.rmtree(target)

@router.get("/status/{lecture_id}")
async def session_status(lecture_id: str, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == lecture_id).first()
    
    if not lecture:
        return {"exists": False, "status": "not_started"}

    attendance_count = db.query(models.AttendanceLog).filter(
        models.AttendanceLog.lecture_id == lecture_id
    ).count()
    emotion_count = db.query(models.EmotionLog).filter(
        models.EmotionLog.lecture_id == lecture_id
    ).count()
    check_count = db.query(models.ComprehensionCheck).filter(
        models.ComprehensionCheck.lecture_id == lecture_id
    ).count()

    return {
        "lecture_id": lecture_id,
        "exists": True,
        "status": lecture.status or "not_started",
        "start_time": lecture.actual_start_time.isoformat() if lecture.actual_start_time else None,
        "end_time": lecture.actual_end_time.isoformat() if lecture.actual_end_time else None,
        "attendance_count": attendance_count,
        "emotion_count": emotion_count,
        "check_count": check_count,
        "frames_captured": lecture.total_frames_captured
    }

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    try:
        logger.info(f"[*] Starting session request: {request.lecture_id}")
        lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
        now = datetime.utcnow()

        if not lecture:
            lecture = models.Lecture(
                lecture_id=request.lecture_id,
                class_id=request.class_id,
                lecturer_id=request.lecturer_id,
                title=request.title or f"Lecture {request.lecture_id}",
                slide_url=request.slide_url,
                actual_start_time=now,
                status="live"
            )
            db.add(lecture)
        else:
            lecture.actual_start_time = now
            lecture.actual_end_time = None
            lecture.status = "live"
        
        db.commit()
        db.refresh(lecture)

        # Vision Thread Logic
        stop_event = threading.Event()
        camera_url = request.camera_url or os.getenv("CLASSROOM_CAMERA_URL", "0")
        
        if _VISION_AVAILABLE and vision_pipeline:
            vision_thread = threading.Thread(
                target=vision_pipeline.run_pipeline,
                args=(request.lecture_id, camera_url, stop_event, request.context, request.exam_id),
                daemon=True
            )
            vision_thread.start()
            active_lecture_tasks[request.lecture_id] = {"stop_event": stop_event, "thread": vision_thread}
        else:
            active_lecture_tasks[request.lecture_id] = {"stop_event": stop_event, "thread": None}

        await manager.broadcast({
            "type": "session:start",
            "lecture_id": request.lecture_id,
            "timestamp": now.isoformat() + "Z"
        })
        return {"status": "live", "lecture_id": request.lecture_id}
    except Exception as e:
        logger.error(f"start_session error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/end")
async def end_session(request: SessionEndRequest, db: Session = Depends(get_db)):
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
    if lecture:
        lecture.actual_end_time = datetime.utcnow()
        lecture.status = "ended"
        db.commit()

    stop_active_task(request.lecture_id)
    latest_frames.pop(request.lecture_id, None)

    await manager.broadcast({
        "type": "session:end",
        "lecture_id": request.lecture_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "ended", "lecture_id": request.lecture_id}

@router.post("/reset")
async def reset_session(request: SessionEndRequest, db: Session = Depends(get_db)):
    lecture_id = request.lecture_id
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == lecture_id).first()
    
    stop_active_task(lecture_id)
    latest_frames.pop(lecture_id, None)

    # SURGICAL DELETE (Option 2: Hard Reset)
    # Delete dependent data
    check_ids = [r[0] for r in db.query(models.ComprehensionCheck.id).filter(models.ComprehensionCheck.lecture_id == lecture_id).all()]
    if check_ids:
        db.query(models.StudentAnswer).filter(models.StudentAnswer.check_id.in_(check_ids)).delete(synchronize_session=False)
    
    db.query(models.ComprehensionCheck).filter(models.ComprehensionCheck.lecture_id == lecture_id).delete(synchronize_session=False)
    db.query(models.AttendanceLog).filter(models.AttendanceLog.lecture_id == lecture_id).delete(synchronize_session=False)
    db.query(models.EmotionLog).filter(models.EmotionLog.lecture_id == lecture_id).delete(synchronize_session=False)
    db.query(models.FocusStrike).filter(models.FocusStrike.lecture_id == lecture_id).delete(synchronize_session=False)
    db.query(models.Notification).filter(models.Notification.lecture_id_fk == lecture_id).delete(synchronize_session=False)

    if lecture:
        lecture.actual_start_time = None
        lecture.actual_end_time = None
        lecture.total_frames_captured = 0
        lecture.status = "not_started"
    
    db.commit()
    remove_snapshot_dir(lecture_id)

    await manager.broadcast({"type": "session:reset", "lecture_id": lecture_id})
    return {"status": "not_started", "lecture_id": lecture_id}

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except:
        manager.disconnect(websocket)
