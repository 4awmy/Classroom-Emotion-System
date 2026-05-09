from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth, notify
from services import export_service
from database import engine
from sqlalchemy import text
import models
import uvicorn

# Create database tables
models.Base.metadata.create_all(bind=engine)

# Enable WAL mode and check migrations
if engine.url.drivername == "sqlite":
    with engine.connect() as conn:
        conn.execute(text("PRAGMA journal_mode=WAL"))
        existing_columns = {
            row[1] for row in conn.execute(text("PRAGMA table_info(attendance_log)"))
        }
        if "checkin_time" not in existing_columns:
            conn.execute(text("ALTER TABLE attendance_log ADD COLUMN checkin_time DATETIME"))
        if "duration_minutes" not in existing_columns:
            conn.execute(text("ALTER TABLE attendance_log ADD COLUMN duration_minutes FLOAT DEFAULT 0.0"))

        lecture_columns = {
            row[1] for row in conn.execute(text("PRAGMA table_info(lectures)"))
        }
        if "scheduled_start_time" not in lecture_columns:
            conn.execute(text("ALTER TABLE lectures ADD COLUMN scheduled_start_time DATETIME"))
        conn.commit()

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
app.include_router(emotion.router,     prefix="/emotion",    tags=["Emotion"])
app.include_router(attendance.router,  prefix="/attendance", tags=["Attendance"])
app.include_router(session.router,     prefix="/session",     tags=["Session"])
app.include_router(gemini.router,      prefix="/gemini",      tags=["Gemini"])
app.include_router(notes.router,       prefix="/notes",        tags=["Notes"])
app.include_router(exam.router,        prefix="/exam",        tags=["Exam"])
app.include_router(roster.router,      prefix="/roster",      tags=["Roster"])
app.include_router(upload.router,      prefix="/upload",      tags=["Upload"])
app.include_router(notify.router,      prefix="/notify",      tags=["Notify"])

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8003, reload=True)
