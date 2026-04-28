from fastapi import FastAPI
from . import models
from .database import engine

# Create tables on startup
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Classroom Emotion API")

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "backend"}

@app.get("/")
def read_root():
    return {"message": "Welcome to the Classroom Emotion Detection System API"}
