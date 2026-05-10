import logging
import threading
import contextlib
import os
from fastapi import FastAPI, Header, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text, inspect
from sqlalchemy.orm import Session
from database import engine, SessionLocal, get_db
import models
import uvicorn

# Routers
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth, notify, admin, courses, vision

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

def run_migrations():
    """Add new columns to existing tables without dropping data."""
    migrations = [
        # password_hash added after Supabase retirement
        "ALTER TABLE admins    ADD COLUMN IF NOT EXISTS password_hash TEXT",
        "ALTER TABLE lecturers ADD COLUMN IF NOT EXISTS password_hash TEXT",
        "ALTER TABLE students  ADD COLUMN IF NOT EXISTS password_hash TEXT",
        # auth_user_id made nullable (no longer required without Supabase)
        "ALTER TABLE admins    ALTER COLUMN auth_user_id DROP NOT NULL",
        "ALTER TABLE lecturers ALTER COLUMN auth_user_id DROP NOT NULL",
        "ALTER TABLE students  ALTER COLUMN auth_user_id DROP NOT NULL",
    ]
    with engine.begin() as conn:
        for sql in migrations:
            try:
                conn.execute(text(sql))
            except Exception as e:
                logger.warning(f"[MIGRATION] Skipped: {sql[:60]}... — {e}")

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup ---
    logger.info("[INIT] Production Startup...")

    # Schema migrations (idempotent — safe to run every startup)
    try:
        run_migrations()
        logger.info("[INIT] Migrations applied")
    except Exception as e:
        logger.error(f"[INIT] Migration error: {e}")

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
def health_check(db: Session = Depends(get_db)):
    db_ok = False
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except Exception as e:
        logger.error(f"Health check DB error: {e}")
        
    return {
        "status": "ok" if db_ok else "error",
        "database": "connected" if db_ok else "disconnected",
        "version": "3.5.0", 
        "message": "pong"
    }

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
    app.include_router(vision.router,      prefix=f"{prefix}/vision",     tags=["Vision"])

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
