import logging
import threading
import contextlib
import os
from fastapi import FastAPI, Header, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text, inspect
from database import engine, SessionLocal, get_db
import models
import uvicorn

# Routers
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth, notify, admin, courses

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def stop_all_background_tasks():
    """Ensure clean shutdown."""
    logger.info("[SHUTDOWN] Stopping background tasks...")
    try:
        from services.lecture_scheduler import scheduler
        if scheduler.running:
            scheduler.shutdown()
    except: pass

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup ---
    logger.info("[INIT] Production Startup...")
    
    # Start scheduler (Optional AI deps)
    try:
        from services.lecture_scheduler import start_scheduler
        start_scheduler()
    except:
        logger.warning("[INIT] Scheduler skipped")
        
    yield
    stop_all_background_tasks()

app = FastAPI(title="AAST LMS API", lifespan=lifespan)

# WIDE OPEN CORS for production stability
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root/Health
@app.get("/")
@app.get("/health")
@app.get("/ping")
def health_check():
    return {"status": "ok", "version": "3.4.0", "message": "pong"}

# Include routers
# We include them TWICE: with and without /api to handle internal/external routing perfectly
for prefix in ["", "/api"]:
    app.include_router(auth.router,        prefix=f"{prefix}/auth",       tags=["Auth"])
    app.include_router(admin.router,       prefix=f"{prefix}/admin",      tags=["Admin"])
    app.include_router(courses.router,     prefix=f"{prefix}/courses",    tags=["Courses"])
    app.include_router(emotion.router,     prefix=f"{prefix}/emotion",    tags=["Emotion"])
    app.include_router(attendance.router,  prefix=f"{prefix}/attendance", tags=["Attendance"])
    app.include_router(session.router,     prefix=f"{prefix}/session",    tags=["Session"])
    app.include_router(gemini.router,      prefix=f"{prefix}/gemini",     tags=["Gemini"])
    app.include_router(notes.router,       prefix=f"{prefix}/notes",      tags=["Notes"])
    app.include_router(exam.router,        prefix=f"{prefix}/exam",       tags=["Exam"])
    app.include_router(roster.router,      prefix=f"{prefix}/roster",     tags=["Roster"])
    app.include_router(upload.router,      prefix=f"{prefix}/upload",     tags=["Upload"])
    app.include_router(notify.router,      prefix=f"{prefix}/notify",     tags=["Notify"])

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
