from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import logging
from services.websocket import manager

router = APIRouter(tags=["Session"])
logger = logging.getLogger(__name__)

class SessionStartRequest(BaseModel):
    lecture_id: str
    lecturer_id: str
    slide_url: str

class SessionEndRequest(BaseModel):
    lecture_id: str

class SessionBroadcastRequest(BaseModel):
    type: str
    question: str

@router.post("/start")
async def start_session(request: SessionStartRequest):
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
async def end_session(request: SessionEndRequest):
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
async def get_upcoming_sessions():
    return [
        {
            "lecture_id": "L1",
            "title": "Data Structures",
            "start_time": "2026-05-01T09:00:00",
            "subject": "CS201",
            "slide_url": "https://drive.google.com/file/d/abc123/view"
        }
    ]

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
            # Handle client -> server messages (e.g., focus_strike)
            if isinstance(data, dict) and data.get("type") == "focus_strike":
                logger.info("Received focus strike from %s", data.get("student_id"))
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as exc:
        logger.exception("WebSocket error: %s", exc)
        manager.disconnect(websocket)
