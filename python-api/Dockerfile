FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for OpenCV, face_recognition, and psycopg2
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    build-essential \
    cmake \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install server-only dependencies (no vision/ML — those run locally)
COPY requirements-server.txt ./
RUN pip install --no-cache-dir -r requirements-server.txt

# Copy the backend source
COPY . .

# Expose port 8000
EXPOSE 8000

# Start uvicorn
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
