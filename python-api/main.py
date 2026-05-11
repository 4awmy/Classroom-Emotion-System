import logging
import threading
import contextlib
import os
import asyncio
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
    """Add new columns and tables without dropping data."""
    migrations = [
        # password_hash added after Supabase retirement
        "ALTER TABLE admins    ADD COLUMN IF NOT EXISTS password_hash TEXT",
        "ALTER TABLE lecturers ADD COLUMN IF NOT EXISTS password_hash TEXT",
        "ALTER TABLE students  ADD COLUMN IF NOT EXISTS password_hash TEXT",
        # auth_user_id made nullable (no longer required without Supabase)
        "ALTER TABLE admins    ALTER COLUMN auth_user_id DROP NOT NULL",
        "ALTER TABLE lecturers ALTER COLUMN auth_user_id DROP NOT NULL",
        "ALTER TABLE students  ALTER COLUMN auth_user_id DROP NOT NULL",
        # New Gemini Tables (if not created via metadata)
        "CREATE TABLE IF NOT EXISTS comprehension_checks (id SERIAL PRIMARY KEY, lecture_id VARCHAR REFERENCES lectures(lecture_id) ON DELETE CASCADE, material_id VARCHAR REFERENCES materials(material_id) ON DELETE SET NULL, question TEXT NOT NULL, options TEXT NOT NULL, correct_option INTEGER NOT NULL, topic VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now())",
        "CREATE TABLE IF NOT EXISTS student_answers (id SERIAL PRIMARY KEY, check_id INTEGER REFERENCES comprehension_checks(id) ON DELETE CASCADE, student_id VARCHAR REFERENCES students(student_id) ON DELETE CASCADE, chosen_option INTEGER NOT NULL, is_correct BOOLEAN NOT NULL, timestamp TIMESTAMP WITH TIME ZONE DEFAULT now())"
    ]
    with engine.begin() as conn:
        for sql in migrations:
            try:
                conn.execute(text(sql))
            except Exception as e:
                # Silently skip if table/column exists or error occurs
                pass

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup ---
    logger.info("[INIT] Production Startup (v3.6.0)...")

    # 0. Capture main loop for WebSocket broadcast_sync (Required for Gemini push)
    from services.websocket import set_main_loop
    set_main_loop(asyncio.get_running_loop())

    # 1. Schema migrations & Table Check
    try:
        run_migrations()
        # Also ensure base tables exist
        models.Base.metadata.create_all(bind=engine)
        logger.info("[INIT] Database schema verified.")
    except Exception as e:
        logger.error(f"[INIT] Database init failed: {e}")

    # 2. Start scheduler (Optional AI deps)
    try:
        from services.lecture_scheduler import start_scheduler
        start_scheduler()
        logger.info("[INIT] Scheduler active.")
    except Exception as e:
        logger.warning(f"[INIT] Scheduler skipped: {e}")

    yield
    # --- Shutdown ---
    stop_all_background_tasks()

app = FastAPI(title="AAST LMS API (Consolidated)", lifespan=lifespan)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root/Health (Enhanced diagnostics)
@app.get("/")
@app.get("/health")
@app.get("/api/health")
@app.get("/ping")
def health_check(db: Session = Depends(get_db)):
    db_ok = False
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except: pass
    return {
        "status": "ok" if db_ok else "error",
        "database": "connected" if db_ok else "disconnected",
        "version": "3.9.0", 
        "message": "Gemini Integration Stable"
    }

# Production Seed Trigger (Internal Only)
@app.post("/api/internal/seed")
@app.post("/internal/seed")
def seed_database(x_seed_secret: str = None):
    secret = os.getenv("JWT_SECRET", "aast-lms-secret-2026")
    if x_seed_secret != secret:
        raise HTTPException(status_code=403, detail="Forbidden")
    
    try:
        # Create default admin if missing
        db = SessionLocal()
        from routers.auth import get_password_hash
        import uuid
        
        admin = db.query(models.Admin).filter(models.Admin.admin_id == "admin").first()
        if not admin:
            new_admin = models.Admin(
                admin_id="admin",
                name="System Administrator",
                email="admin@aast.edu",
                password_hash=get_password_hash("aast2026"),
                auth_user_id=str(uuid.uuid4())
            )
            db.add(new_admin)
            db.commit()
            return {"status": "success", "message": "Admin account created."}
        db.close()
        return {"status": "ok", "message": "System already seeded."}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# Include routers twice: with and without /api prefix
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
