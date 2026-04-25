from importlib.metadata import PackageNotFoundError, version

from fastapi import FastAPI

try:
    _version = version("classroom-emotion-system")
except PackageNotFoundError:
    _version = "0.1.0"

# Initialize the FastAPI application
app = FastAPI(
    title="Classroom Emotion Detection API",
    description="Backend API for storing and serving student emotion data",
    version=_version
)

# Root endpoint
@app.get("/")
def read_root():
    return {"message": "Welcome to the Classroom Emotion Detection API"}

# Health check endpoint (This fulfills Issue #7)
@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "message": "The API is up and running!"
    }