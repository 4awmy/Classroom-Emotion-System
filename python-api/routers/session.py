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
from services import vision_pipeline
import os
import asyncio

router = APIRouter()
logger = logging.getLogger(__name__)

# Global tracking for active lecture tasks
active_lecture_tasks = {}

async def gen_frames(lecture_id: str):
    """MJPEG Frame Generator with low latency."""
    while True:
        if lecture_id in vision_pipeline.latest_frames:
            frame = vision_pipeline.latest_frames[lecture_id]
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        else:
            pass
        # Throttled to ~15 FPS to balance smoothness and CPU
        await asyncio.sleep(0.06)

@router.get("/video_feed/{lecture_id}")
async def video_feed(lecture_id: str):
    """Streaming endpoint for the live vision feed."""
    return StreamingResponse(gen_frames(lecture_id),
                             media_type="multipart/x-mixed-replace; boundary=frame")


class SessionStartRequest(BaseModel):
    lecturer_id: str
    lecture_id: Optional[str] = None
    title: Optional[str] = None
    class_id: Optional[str] = None
    slide_url: Optional[str] = None
    camera_url: Optional[str] = None
    context: Optional[str] = "lecture"
    exam_id: Optional[str] = None

class SessionEndRequest(BaseModel):
    lecture_id: str

class SessionBroadcastRequest(BaseModel):
    type: str
    question: str
    lecture_id: str

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    try:
        import uuid
        if not request.lecture_id:
            short_id = uuid.uuid4().hex[:8]
            if request.class_id:
                request.lecture_id = f"LEC_{request.class_id}_{short_id}"
            else:
                request.lecture_id = f"LEC_{short_id}"
                
        lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
        scheduled = datetime.utcnow().replace(minute=0, second=0, microsecond=0)

        if not lecture:
            lecture_kwargs = dict(
                lecture_id=request.lecture_id,
                lecturer_id=request.lecturer_id,
                title=request.title or f"Lecture {request.lecture_id}",
                slide_url=request.slide_url,
                start_time=datetime.utcnow(),
                scheduled_start=scheduled
            )
            if request.class_id is not None:
                lecture_kwargs["class_id"] = request.class_id
            lecture = models.Lecture(**lecture_kwargs)
            db.add(lecture)
        else:
            lecture.start_time = datetime.utcnow()
            lecture.end_time = None
            if request.slide_url:
                lecture.slide_url = request.slide_url
            if not lecture.scheduled_start:
                lecture.scheduled_start = scheduled
        
        db.commit()
        db.refresh(lecture)

        if request.lecture_id not in active_lecture_tasks:
            stop_event = threading.Event()
            camera_url = request.camera_url or os.getenv("CLASSROOM_CAMERA_URL", "0")
            vision_thread = threading.Thread(
                target=vision_pipeline.run_pipeline,
                args=(request.lecture_id, camera_url, stop_event, request.context, request.exam_id),
                daemon=True
            )
            vision_thread.start()
            active_lecture_tasks[request.lecture_id] = {"stop_event": stop_event}

        # Ensure start_time is serializable
        st_str = lecture.start_time.isoformat() + "Z" if lecture.start_time else datetime.utcnow().isoformat() + "Z"

        await manager.broadcast({
            "type": "session:start",
            "lecture_id": request.lecture_id,
            "slide_url": request.slide_url,
            "lecturer_id": request.lecturer_id,
            "start_time": st_str,
            "context": request.context,
            "exam_id": request.exam_id,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        })
        return {"status": "started", "lecture_id": request.lecture_id}
    except Exception as e:
        logger.error(f"FATAL start_session error: {str(e)}", exc_info=True)
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

@router.post("/broadcast")
async def broadcast_event(request: SessionBroadcastRequest):
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
                context = data.get("context")
                persisted = False
                if student_id and lecture_id:
                    db: Session = SessionLocal()
                    try:
                        if context == "exam":
                            db.add(models.Incident(
                                student_id=student_id, exam_id=lecture_id,
                                flag_type="app_background", severity=1, timestamp=datetime.utcnow()
                            ))
                        else:
                            db.add(FocusStrike(
                                student_id=student_id, lecture_id=lecture_id,
                                timestamp=datetime.utcnow(), strike_type=strike_type
                            ))
                        db.commit()
                        persisted = True
                    except Exception as e:
                        db.rollback()
                    finally:
                        db.close()

                if persisted:
                    await websocket.send_json({
                        "type": "strike_ack",
                        "student_id": student_id,
                        "context": context or "lecture",
                        "timestamp": datetime.utcnow().isoformat() + "Z"
                    })
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as exc:
        manager.disconnect(websocket)
