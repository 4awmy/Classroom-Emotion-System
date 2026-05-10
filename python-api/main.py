import logging
import threading
import contextlib
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth, notify, admin, courses
from database import engine
import models
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def stop_all_background_tasks():
    """Ensure clean shutdown of vision threads and schedulers."""
    logger.info("[SHUTDOWN] Stopping all background tasks...")
    # 1. Shutdown scheduler
    try:
        from services.lecture_scheduler import scheduler
        if scheduler.running:
            scheduler.shutdown()
            logger.info("[SHUTDOWN] Scheduler stopped.")
    except: pass
    
    # 2. Signal all active vision sessions to stop
    try:
        from services.session import active_sessions
        for sid, event in active_sessions.items():
            logger.info(f"[SHUTDOWN] Signalling session {sid} to stop...")
            event.set()
    except: pass

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup ---
    logger.info("[INIT] Performing background initializations...")
    
    # 0. Fix permissions for managed DB (if needed)
    try:
        from sqlalchemy import text
        with engine.connect() as conn:
            conn.execute(text("GRANT ALL ON SCHEMA public TO public;"))
            conn.execute(text("GRANT ALL ON SCHEMA public TO CURRENT_USER;"))
            conn.commit()
            logger.info("[INIT] Schema permissions verified.")
    except Exception as e:
        logger.warning(f"[INIT] Schema permission grant skipped: {e}")

    # 1. Initialize database tables
    try:
        models.Base.metadata.create_all(bind=engine)
        logger.info("[INIT] Database initialization call completed (or table already exists).")
    except Exception as e:
        logger.warning(f"[INIT] Database table creation skipped or failed: {e}")
        logger.warning("[INIT] Note: You may need to run 'python do_manager.py seed-db' or manual SQL if tables are missing.")
        
    # 2. Start background schedulers
    try:
        from services.lecture_scheduler import start_scheduler
        start_scheduler()
        logger.info("[INIT] Scheduler started.")
    except Exception as e:
        logger.error(f"[INIT] Scheduler failed to start: {e}")
        
    yield
    # --- Shutdown ---
    stop_all_background_tasks()

app = FastAPI(title="AAST LMS API (Hybrid v3)", lifespan=lifespan)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check (matches app.yaml route)
@app.get("/api/health")
@app.get("/health")
def health_check():
    return {"status": "ok"}

# One-shot DB seed endpoint — protected by secret header
@app.post("/api/internal/seed")
@app.post("/internal/seed")
def seed_database(x_seed_secret: str = None):
    import os
    from fastapi import Header, HTTPException
    secret = os.getenv("JWT_SECRET", "aast-lms-secret-2026")
    if x_seed_secret != secret:
        raise HTTPException(status_code=403, detail="Forbidden")
    
    from database import engine, SessionLocal
    import models
    from sqlalchemy import text, inspect

    results = {"status": "starting"}
    try:
        # 1. Try to create all tables (might fail)
        try:
            models.Base.metadata.create_all(bind=engine)
            results["metadata_create"] = "success"
        except Exception as e:
            results["metadata_create"] = f"failed: {e}"

        # 2. Manual SQL injection for the 'admins' and 'lecturers' tables
        with engine.connect() as conn:
            conn.execute(text("CREATE TABLE IF NOT EXISTS admins (admin_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN, phone VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now());"))
            conn.execute(text("CREATE TABLE IF NOT EXISTS lecturers (lecturer_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN, phone VARCHAR, photo_url VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now());"))
            conn.execute(text("CREATE TABLE IF NOT EXISTS students (student_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR, needs_password_reset BOOLEAN, department VARCHAR, year INTEGER, face_encoding BYTEA, photo_url VARCHAR, enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT now());"))
            
            # Insert demo admin if not exists
            demo_uuid = "2737e12f-5771-4cd9-b4af-4cc4c3349fa0"
            conn.execute(text(f"INSERT INTO admins (admin_id, auth_user_id, name, email, needs_password_reset) VALUES ('admin', '{demo_uuid}', 'System Admin', 'admin@aast.edu', false) ON CONFLICT DO NOTHING;"))
            conn.commit()
            results["manual_sql"] = "success"

        # 3. Check counts
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        counts = {}
        db = SessionLocal()
        for t in tables:
            try:
                counts[t] = db.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar()
            except: pass
        db.close()
        results["status"] = "ok"
        results["tables"] = tables
        results["counts"] = counts
        return results
    except Exception as e:
        return {"status": "error", "error": str(e), "results": results}

# Include routers with /api prefix for DigitalOcean routing
app.include_router(auth.router,        prefix="/api/auth",       tags=["Auth"])
app.include_router(admin.router,       prefix="/api/admin",      tags=["Admin"])
app.include_router(courses.router,     prefix="/api/courses",    tags=["Courses"])
app.include_router(emotion.router,     prefix="/api/emotion",    tags=["Emotion"])
app.include_router(attendance.router,  prefix="/api/attendance", tags=["Attendance"])
app.include_router(session.router,     prefix="/api/session",    tags=["Session"])
app.include_router(gemini.router,      prefix="/api/gemini",     tags=["Gemini"])
app.include_router(notes.router,       prefix="/api/notes",      tags=["Notes"])
app.include_router(exam.router,        prefix="/api/exam",       tags=["Exam"])
app.include_router(roster.router,      prefix="/api/roster",     tags=["Roster"])
app.include_router(upload.router,      prefix="/api/upload",     tags=["Upload"])
app.include_router(notify.router,      prefix="/api/notify",     tags=["Notify"])


if __name__ == "__main__":
    logger.info("[INIT] Launching server on port 8000...")
    # reload=False is safer for Windows background threads
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
