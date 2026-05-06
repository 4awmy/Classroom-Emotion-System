FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for OpenCV and AI
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install opencv-python requests python-dotenv

COPY . .

CMD ["python", "main.py"]
