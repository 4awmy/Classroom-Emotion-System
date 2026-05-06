FROM astral-sh/uv:python3.13-slim

WORKDIR /app

# Install system dependencies for OpenCV and AI
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt ./
RUN uv pip install --system -r requirements.txt

# Copy the backend source
COPY . .

# Expose port 8000
EXPOSE 8000

# Start uvicorn
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
