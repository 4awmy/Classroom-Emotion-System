from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, notes, exam, roster, upload, auth
from database import engine
import models

# Create database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="AAST LMS API")

# Configure CORS
# allow_origins=["*"] is incompatible with allow_credentials=True per the CORS spec.
# Credentials (cookies/Authorization headers) require explicit origins.
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
