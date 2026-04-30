from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
from sqlalchemy.orm import Session
from database import get_db, SessionLocal
from models import Lecture, FocusStrike, Incident
from services.websocket import manager

router = APIRouter(tags=["Session"])
logger = logging.getLogger(__name__)

class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    title: str
    subject: str
    slide_url: Optional[str] = None

class SessionEndRequest(BaseModel):
    lecture_id: str

class SessionBroadcastRequest(BaseModel):
    type: str
    question: str

@router.post("/start")
async def start_session(request: SessionStartRequest, db: Session = Depends(get_db)):
    # Check if lecture exists, update or create
    lecture = db.query(Lecture).filter(Lecture.lecture_id == request.lecture_id).first()
    if lecture:
        lecture.start_time = datetime.utcnow()
        lecture.lecturer_id = request.lecturer_id
        lecture.title = request.title
        lecture.subject = request.subject
        lecture.slide_url = request.slide_url
    else:
        lecture = Lecture(
            lecture_id=request.lecture_id,
            lecturer_id=request.lecturer_id,
            title=request.title,
            subject=request.subject,
            start_time=datetime.utcnow(),
            slide_url=request.slide_url
        )
        db.add(lecture)
    
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
    lecture = db.query(Lecture).filter(Lecture.lecture_id == request.lecture_id).first()
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")
    
    lecture.end_time = datetime.utcnow()
    db.commit()

    # Broadcast session:end to all clients
    await manager.broadcast({
        "type": "session:end",
        "lecture_id": request.lecture_id,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"status": "ended"}

@router.post("/broadcast")
async def broadcast_event(request: SessionBroadcastRequest):
    # Broadcast the event (e.g., freshbrainer)
    await manager.broadcast({
        "type": request.type,
        "question": request.question,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })
    return {"delivered_to": len(manager.active_connections)}

@router.get("/upcoming")
async def get_upcoming_sessions(db: Session = Depends(get_db)):
    # Return lectures that haven't ended yet or are scheduled for the future
    # For now, return all lectures as upcoming if end_time is null
    lectures = db.query(Lecture).filter(Lecture.end_time == None).all()
    return lectures

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    # Open a dedicated DB session for this websocket connection
    db = SessionLocal()
    try:
        # Send initial connection confirmation
        await websocket.send_json({
            "type": "connection_established",
            "message": "Connected to Classroom Emotion System WebSocket"
        })
        
        while True:
            # Keep connection alive and handle incoming messages
            data = await websocket.receive_json()
            
            # Handle client -> server messages (e.g., focus_strike)
            if isinstance(data, dict) and data.get("type") == "focus_strike":
                student_id = data.get("student_id")
                lecture_id = data.get("lecture_id")
                strike_type = data.get("strike_type", "app_background")
                context = data.get("context") # 'exam' or null
                
                logger.info("Received focus strike from %s in %s (context: %s)", 
                           student_id, lecture_id, context)
                
                if context == "exam":
                    # For exams, strikes are recorded as incidents
                    new_incident = Incident(
                        student_id=student_id,
                        exam_id=lecture_id, # exam_id is passed as lecture_id in mobile app
                        flag_type=strike_type,
                        severity=1, # app_background is severity 1 per CLAUDE.md
                    )
                    db.add(new_incident)
                else:
                    # Regular lecture focus strike
                    new_strike = FocusStrike(
                        student_id=student_id,
                        lecture_id=lecture_id,
                        strike_type=strike_type
                    )
                    db.add(new_strike)
                
                db.commit()
                
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as exc:
        logger.exception("WebSocket error: %s", exc)
        manager.disconnect(websocket)
    finally:
        db.close()
