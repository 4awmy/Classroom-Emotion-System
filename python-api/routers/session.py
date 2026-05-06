from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
from sqlalchemy.orm import Session
from services.websocket import manager
from database import get_db, SessionLocal
import models
from schemas import LectureResponse

router = APIRouter()
logger = logging.getLogger(__name__)

class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: Optional[str] = None
    subject: Optional[str] = None
    slide_url: str

class SessionEndRequest(BaseModel):
    lecture_id: str

class SessionBroadcastRequest(BaseModel):
    type: str
    question: str
    lecture_id: str

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    # Persist lecture to DB
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

    # Broadcast session:start to all clients
    await manager.broadcast({
        "type": "session:start",
        "lecture_id": request.lecture_id,
        "slide_url": request.slide_url,
        "lecturer_id": request.lecturer_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "started", "lecture_id": request.lecture_id}

@router.post("/end")
async def end_session(request: SessionEndRequest, db: Session = Depends(get_db)):
    # Update lecture end_time in DB
    lecture = db.query(models.Lecture).filter(models.Lecture.lecture_id == request.lecture_id).first()
    if lecture:
        lecture.end_time = datetime.utcnow()
        db.commit()

    # Broadcast session:end to all clients
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
    # For Phase 1, we'll just return all lectures that haven't ended
    return db.query(models.Lecture).filter(models.Lecture.end_time == None).all()

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        # Send initial connection confirmation
        await websocket.send_json({
            "type": "connection_established",
            "message": "Connected to Classroom Emotion System WebSocket"
        })
        
        while True:
            # Keep connection alive and handle incoming messages
            data = await websocket.receive_json()
            # T058: Handle focus_strike — persist to DB and broadcast
            if isinstance(data, dict) and data.get("type") == "focus_strike":
                student_id = data.get("student_id")
                lecture_id = data.get("lecture_id")
                strike_type = data.get("strike_type", "app_background")
                logger.info("Focus strike: student=%s lecture=%s type=%s", student_id, lecture_id, strike_type)
                # Bug 5 fix: validate required fields before DB write
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
                else:
                    logger.warning("Ignoring focus_strike with missing student_id or lecture_id")
                # Bug 5 fix: only ack when persisted
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
