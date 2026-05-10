FROM python:3.11-slim

WORKDIR /app

# System deps: OpenCV runtime + dlib build tools + psycopg2
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libpq-dev \
    build-essential \
    cmake \
    libopenblas-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-server.txt ./
# Install cmake pip package first so dlib can find it, then install all deps
RUN pip install --no-cache-dir cmake && \
    pip install --no-cache-dir -r requirements-server.txt

# Copy the backend source
COPY . .

# Expose port 8000
EXPOSE 8000

# Start uvicorn
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
