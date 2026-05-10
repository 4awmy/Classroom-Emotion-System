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
    try:
        # 1. Initialize database tables
        models.Base.metadata.create_all(bind=engine)
        logger.info("[INIT] Database initialized.")
        
        # 2. Start background schedulers
        from services.lecture_scheduler import start_scheduler
        start_scheduler()
        logger.info("[INIT] Scheduler started.")
    except Exception as e:
        logger.error(f"[INIT] Startup failed: {e}")
        
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

# Health check
@app.get("/health")
def health_check():
    return {"status": "ok"}

# One-shot DB seed endpoint — protected by secret header
@app.post("/internal/seed")
def seed_database(x_seed_secret: str = None):
    import os
    from fastapi import Header, HTTPException
    secret = os.getenv("JWT_SECRET", "")
    if x_seed_secret != secret:
        raise HTTPException(status_code=403, detail="Forbidden")
    from database import SessionLocal
    import models
    models.Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        from sqlalchemy import text, inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        counts = {}
        for t in tables:
            try:
                counts[t] = db.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar()
            except: pass
        return {"status": "ok", "tables": tables, "counts": counts}
    finally:
        db.close()

# Include routers
app.include_router(auth.router,        prefix="/auth",       tags=["Auth"])
app.include_router(admin.router,       prefix="/admin",      tags=["Admin"])
app.include_router(courses.router,     prefix="/courses",    tags=["Courses"])
app.include_router(emotion.router,     prefix="/emotion",    tags=["Emotion"])
app.include_router(attendance.router,  prefix="/attendance", tags=["Attendance"])
app.include_router(session.router,     prefix="/session",    tags=["Session"])
app.include_router(gemini.router,      prefix="/gemini",     tags=["Gemini"])
app.include_router(notes.router,       prefix="/notes",      tags=["Notes"])
app.include_router(exam.router,        prefix="/exam",       tags=["Exam"])
app.include_router(roster.router,      prefix="/roster",     tags=["Roster"])
app.include_router(upload.router,      prefix="/upload",     tags=["Upload"])
app.include_router(notify.router,      prefix="/notify",     tags=["Notify"])

if __name__ == "__main__":
    logger.info("[INIT] Launching server on port 8000...")
    # reload=False is safer for Windows background threads
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
