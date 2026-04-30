from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, exam, roster, upload, auth
from database import engine
import models
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="AAST LMS API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# APScheduler Stub for Nightly Export Service
def start_scheduler():
    """
    Stub for APScheduler initialization.
    Phase 3 will implement the actual nightly CSV export logic.
    """
    logger.info("Initializing APScheduler stub for nightly exports...")
    # scheduler = BackgroundScheduler()
    # scheduler.add_job(export_nightly_csv, 'cron', hour=0)
    # scheduler.start()

@app.on_event("startup")
async def startup_event():
    start_scheduler()

# Health check
@app.get("/health")
def health_check():
    return {"status": "ok"}

# Include routers
app.include_router(auth.router,        prefix="/auth")
app.include_router(emotion.router,     prefix="/emotion")
app.include_router(attendance.router,  prefix="/attendance")
app.include_router(session.router,     prefix="/session")
app.include_router(gemini.router)      # No prefix because it handles /gemini and /notes
app.include_router(exam.router,        prefix="/exam")
app.include_router(roster.router,      prefix="/roster")
app.include_router(upload.router,      prefix="/upload")
