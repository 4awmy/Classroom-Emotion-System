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
    
    # Try to ensure tables exist via Direct SQL
    try:
        with engine.connect() as conn:
            tables_sql = [
                "CREATE TABLE IF NOT EXISTS admins (admin_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN DEFAULT false, phone VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);",
                "CREATE TABLE IF NOT EXISTS lecturers (lecturer_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN DEFAULT false, phone VARCHAR, photo_url VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);",
                "CREATE TABLE IF NOT EXISTS students (student_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR, needs_password_reset BOOLEAN DEFAULT false, department VARCHAR, year INTEGER, face_encoding BYTEA, photo_url VARCHAR, enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);"
            ]
            for sql in tables_sql:
                try:
                    conn.execute(text(sql))
                    conn.commit()
                except: pass
            
            # Create default admin
            demo_uuid = "2737e12f-5771-4cd9-b4af-4cc4c3349fa0"
            conn.execute(text(f"INSERT INTO admins (admin_id, auth_user_id, name, email, needs_password_reset) VALUES ('admin', '{demo_uuid}', 'System Admin', 'admin@aast.edu', false) ON CONFLICT DO NOTHING;"))
            conn.commit()
            logger.info("[INIT] Database initialization complete.")
    except Exception as e:
        logger.error(f"[INIT] Database pre-init failed: {e}")

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
