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

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # --- Startup ---
    logger.info("[INIT] Production Startup...")
    
    # 0. Capture main loop for WebSocket broadcast_sync
    import asyncio
    from services.websocket import set_main_loop
    set_main_loop(asyncio.get_running_loop())
    
    # Try to ensure tables exist via Direct SQL
    try:
        with engine.connect() as conn:
            tables_sql = [
                "CREATE TABLE IF NOT EXISTS admins (admin_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN DEFAULT false, phone VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);",
                "CREATE TABLE IF NOT EXISTS lecturers (lecturer_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR UNIQUE, needs_password_reset BOOLEAN DEFAULT false, phone VARCHAR, photo_url VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);",
                "CREATE TABLE IF NOT EXISTS students (student_id VARCHAR PRIMARY KEY, auth_user_id UUID UNIQUE, name VARCHAR, email VARCHAR, needs_password_reset BOOLEAN DEFAULT false, department VARCHAR, year INTEGER, face_encoding BYTEA, photo_url VARCHAR, enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT now(), password_hash VARCHAR);",
                "CREATE TABLE IF NOT EXISTS comprehension_checks (id SERIAL PRIMARY KEY, lecture_id VARCHAR REFERENCES lectures(lecture_id) ON DELETE CASCADE, material_id VARCHAR REFERENCES materials(material_id) ON DELETE SET NULL, question TEXT NOT NULL, options TEXT NOT NULL, correct_option INTEGER NOT NULL, topic VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT now());",
                "CREATE TABLE IF NOT EXISTS student_answers (id SERIAL PRIMARY KEY, check_id INTEGER REFERENCES comprehension_checks(id) ON DELETE CASCADE, student_id VARCHAR REFERENCES students(student_id) ON DELETE CASCADE, chosen_option INTEGER NOT NULL, is_correct BOOLEAN NOT NULL, timestamp TIMESTAMP WITH TIME ZONE DEFAULT now());"
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

# CORS
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
@app.get("/api/health")
@app.get("/ping")
def health_check(db: Session = Depends(get_db)):
    db_ok = False
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except: pass
    return {"status": "ok" if db_ok else "error", "version": "3.5.1", "db": "connected" if db_ok else "disconnected"}

# One-shot DB seed endpoint
@app.post("/api/internal/seed")
@app.post("/internal/seed")
def seed_database(x_seed_secret: str = None):
    import os
    secret = os.getenv("JWT_SECRET", "aast-lms-secret-2026")
    if x_seed_secret != secret:
        raise HTTPException(status_code=403, detail="Forbidden")
    
    results = {"status": "starting"}
    try:
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

# Include routers
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
