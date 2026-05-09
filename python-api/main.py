import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth, notify, admin, courses
from services.lecture_scheduler import start_scheduler
from database import engine
import models
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize database tables (Fast on SQLite)
logger.info("[INIT] Initializing SQLite database...")
try:
    models.Base.metadata.create_all(bind=engine)
    logger.info("[INIT] Database initialized.")
except Exception as e:
    logger.error(f"[INIT] Database initialization failed: {e}")

# Start background schedulers
logger.info("[INIT] Starting background scheduler...")
start_scheduler()

app = FastAPI(title="AAST LMS API")

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
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
