# CLAUDE.md — AI-Powered LMS & Classroom Analytics Platform (v3)
> Read this file fully before writing any code, creating any file, or running any command.
> This is the single source of truth for the entire project. Every architectural decision here supersedes any prior version.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Pre-Existing Assets](#2-pre-existing-assets)
3. [Monorepo Structure](#3-monorepo-structure)
4. [Prerequisite Accounts & Software](#4-prerequisite-accounts--software)
5. [Local Development Setup](#5-local-development-setup)
6. [Database Architecture](#6-database-architecture)
7. [Vision Pipeline](#7-vision-pipeline)
8. [Engagement Score](#8-engagement-score)
9. [Audio Pipeline — Whisper](#9-audio-pipeline--whisper)
10. [Roster Ingestion Pipeline](#10-roster-ingestion-pipeline)
11. [State Case Scenarios](#11-state-case-scenarios)
12. [Module Specifications](#12-module-specifications)
13. [FastAPI Backend](#13-fastapi-backend)
14. [Step-by-Step Development Guide](#14-step-by-step-development-guide)
15. [Deployment Guide](#15-deployment-guide)
16. [Granular Work Breakdown Structure](#16-granular-work-breakdown-structure)
17. [Key Constraints](#17-key-constraints)

---

## 1. Project Overview

An AI-powered Learning Management System (LMS) and Classroom Emotion Analytics Platform for **AAST (Arab Academy for Science, Technology & Maritime Transport)**.

A **single high-resolution classroom camera** captures the entire student crowd. A sequential vision pipeline identifies each student, detects their emotion, and streams the results into SQLite in real time. The R/Shiny web portal provides Admin and Lecturer interfaces. A React Native mobile app gives students their focus mode, live captions, and smart notes.

### Interface Split — This Is Non-Negotiable

| Audience | Interface | Technology | Who builds |
|---|---|---|---|
| **Admin** | Web portal | R + Shiny | S2 |
| **Lecturer** | Web portal | R + Shiny | S2 |
| **Student** | Mobile app | React Native (Expo) | S4 |
| All | Backend API | Python FastAPI | S3 |
| Live data | Runtime DB | SQLite | S3 |
| Analytics data | Static CSV exports | Nightly cron | S3 |

> R/Shiny is for Admin and Lecturer **only**. React Native is for Students **only**. Never mix these.

---

## 2. Pre-Existing Assets — Read Before Building Anything

### 2.1 AAST Portal Templates
The HTML/CSS templates for the AAST web portal **have already been created** by the UI team. They include full AAST branding: navy `#002147`, gold `#C9A84C`, Cairo bilingual font, and RTL support.

**S2 does NOT create UI from scratch.** S2 injects R/Shiny `renderUI` components and `output$` bindings into the slots in these existing templates using `htmlTemplate()` or `includeHTML()`. Do not rebuild or overwrite the existing chrome.

---

## 3. Monorepo Structure

```
/
├── CLAUDE.md                          ← this file (single source of truth)
├── data-schema/
│   └── README.md                      ← SQLite schemas + CSV export schemas (locked Week 1)
│
├── shiny-app/                         ← R/Shiny web portal (Admin + Lecturer ONLY)
│   ├── app.R                          ← entry point, sources ui/ and server/
│   ├── global.R                       ← libraries, FASTAPI_BASE_URL constant
│   ├── ui/
│   │   ├── admin_ui.R                 ← 8 admin analytics panels
│   │   └── lecturer_ui.R              ← 5 submodules: Roster, Materials, Attendance, Live, Reports
│   ├── server/
│   │   ├── admin_server.R
│   │   └── lecturer_server.R
│   ├── modules/
│   │   ├── engagement_score.R         ← core metric computation
│   │   ├── clustering.R               ← K-means lecturer + student clusters
│   │   └── attendance.R               ← attendance helpers
│   ├── www/
│   │   └── custom.css                 ← AAST theme — DO NOT OVERWRITE
│   └── reports/
│       └── student_report.Rmd         ← per-student PDF report template
│
├── python-api/                        ← FastAPI backend (shared by both frontends)
│   ├── main.py                        ← app entry point, router registration
│   ├── database.py                    ← SQLite engine + session factory
│   ├── models.py                      ← SQLAlchemy ORM models
│   ├── routers/
│   │   ├── emotion.py                 ← vision pipeline trigger + results
│   │   ├── attendance.py              ← attendance CRUD
│   │   ├── session.py                 ← WebSocket broadcast + lecture lifecycle
│   │   ├── gemini.py                  ← fresh-brainer + smart notes endpoints
│   │   ├── exam.py                    ← exam proctoring endpoints
│   │   ├── roster.py                  ← student image upload + face encoding
│   │   └── upload.py                  ← lecture material uploads
│   ├── services/
│   │   ├── vision_pipeline.py         ← YOLO → face_recognition → HSEmotion (1 frame/5s)
│   │   ├── whisper_service.py         ← Whisper transcription + WS caption broadcast
│   │   ├── gemini_service.py          ← Gemini API prompts (3 functions)
│   │   ├── proctor_service.py         ← exam YOLO phone detection + MediaPipe head posture
│   │   └── export_service.py          ← nightly SQLite → CSV export (APScheduler)
│   ├── data/
│   │   ├── classroom_emotions.db      ← SQLite live database (gitignored)
│   │   ├── exports/                   ← nightly CSV exports — only R/Shiny reads these
│   │   │   ├── emotions.csv
│   │   │   ├── attendance.csv
│   │   │   ├── materials.csv
│   │   │   ├── incidents.csv
│   │   │   ├── transcripts.csv
│   │   │   └── notifications.csv
│   │   ├── plans/                     ← per-student AI intervention .md files
│   │   └── evidence/                  ← exam incident screenshots
│   ├── .env.example                   ← env var keys (empty values — safe to commit)
│   └── requirements.txt
│
├── react-native-app/                  ← Student mobile app (React Native + Expo) ONLY
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login.tsx              ← JWT login screen
│   │   └── (student)/
│   │       ├── home.tsx               ← upcoming lectures + engagement summary
│   │       ├── focus.tsx              ← AppState monitor + strike sender
│   │       └── notes.tsx              ← Smart Notes markdown viewer
│   ├── components/
│   │   ├── CaptionBar.tsx             ← live WS caption overlay
│   │   ├── FocusOverlay.tsx           ← strike counter + focus lock UI
│   │   └── NotesViewer.tsx            ← markdown renderer with ✱ highlights
│   ├── store/
│   │   └── useStore.ts                ← Zustand: studentId, strikes, caption, focusActive
│   ├── services/
│   │   └── api.ts                     ← FastAPI HTTP client + WebSocket client
│   ├── .env.example
│   └── package.json
│
└── notebooks/
    └── generate_synthetic_data.py     ← seeds SQLite with 1000+ rows for testing
```

---

## 4. Prerequisite Accounts & Software

Every team member must complete **all** of the following before Week 1 ends. S3 must complete the backend accounts by end of Day 2.

### 4.1 Accounts to Create

#### GitHub (All members)
1. Create account at https://github.com if you don't have one
2. Share your GitHub username with S3 (repo owner: `4awmy`)
3. Accept the collaborator invitation to `4awmy/Classroom-Emotion-System`
4. Enable two-factor authentication (required for branch protection)
5. Set up SSH key: `ssh-keygen -t ed25519 -C "your@email.com"` → add public key to GitHub Settings → SSH keys

#### Google AI Studio — Gemini API Key (S1 + S3)
1. Go to https://aistudio.google.com
2. Sign in with your Google account
3. Click **Get API Key** → **Create API key in new project**
4. Copy the key — this is your `GEMINI_API_KEY`
5. Free tier: 15 requests/minute, 1M tokens/day — sufficient for this project
6. Model to use: `gemini-1.5-flash` (do not use pro — not free)

#### OpenAI — Whisper API Key (S1 + S3)
1. Go to https://platform.openai.com
2. Create account → Add billing (minimum $5 credit)
3. Go to API Keys → **Create new secret key**
4. Copy the key — this is your `OPENAI_API_KEY`
5. Whisper API cost: ~$0.006/minute of audio — a 1-hour lecture costs ~$0.36
6. **Do not use GPT models** — only Whisper (`whisper-1`) is used in this project

#### Google Cloud Platform — Drive API (S3)
1. Go to https://console.cloud.google.com
2. Create a new project: `aast-lms`
3. Enable the **Google Drive API**:
   - APIs & Services → Library → search "Google Drive API" → Enable
4. Create a Service Account:
   - APIs & Services → Credentials → Create Credentials → Service Account
   - Name: `aast-drive-service`
   - Role: Editor
5. Create a JSON key:
   - Click the service account → Keys → Add Key → Create new key → JSON
   - Download as `gcloud_key.json` → place in `python-api/` (gitignored)
6. This path goes into `GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json`

#### Railway.app — FastAPI Hosting (S3)
1. Go to https://railway.app
2. Sign up with GitHub
3. Create a new project → **Deploy from GitHub repo**
4. Select `4awmy/Classroom-Emotion-System`
5. Set root directory to `python-api/`
6. After first deploy, go to Settings → Domains → **Generate Domain**
7. Copy the URL — this is your `FASTAPI_BASE_URL`
8. Free tier: 500 hours/month (enough for development)

#### shinyapps.io — R/Shiny Hosting (S2)
1. Go to https://www.shinyapps.io
2. Create a free account
3. After creating account, go to **Account → Tokens**
4. Click **Show** → copy the `rsconnect::setAccountInfo(...)` command
5. Run that command in RStudio — you are now authenticated
6. Free tier: 5 applications, 25 active hours/month

#### Expo — React Native Build (S4)
1. Go to https://expo.dev
2. Create a free account
3. Install Expo Go on your physical Android/iOS device from the app store
4. This account is used for EAS Build (free APK generation) in Phase 4

### 4.2 Software to Install Locally

#### All Members
```bash
# Git
# Windows: https://git-scm.com/download/win
# Mac: brew install git
git --version  # verify: 2.x+

# VS Code (recommended IDE)
# https://code.visualstudio.com
```

#### S1 & S3 — Python Stack
```bash
# Python 3.11 (exact version — face_recognition has issues on 3.12)
# Windows: https://www.python.org/downloads/release/python-3119/
# Mac: brew install python@3.11
python --version  # verify: 3.11.x

# pip (comes with Python)
pip --version

# Optional but recommended: uv (fast package manager)
pip install uv
```

#### S2 — R Stack
```bash
# R 4.3+ — https://cran.r-project.org
# RStudio Desktop — https://posit.co/download/rstudio-desktop/

# Verify in R console:
R.version.string  # should show "R version 4.3.x"
```

#### S4 — Node.js Stack
```bash
# Node.js 18 LTS — https://nodejs.org
node --version   # verify: v18.x
npm --version    # verify: 9.x or 10.x

# Expo CLI
npm install -g expo-cli eas-cli
expo --version   # verify installed
```

#### S1 — Additional Vision Dependencies (Windows)
```bash
# cmake (required by face_recognition / dlib)
# https://cmake.org/download/ → add to PATH during install

# Visual Studio Build Tools (Windows only — required by dlib)
# https://visualstudio.microsoft.com/visual-cpp-build-tools/
# Install "Desktop development with C++" workload

# Verify cmake:
cmake --version
```

---

## 5. Local Development Setup

### 5.1 Clone the Repository (All Members)

```bash
# Clone via SSH (preferred)
git clone git@github.com:4awmy/Classroom-Emotion-System.git
cd Classroom-Emotion-System

# Or via HTTPS
git clone https://github.com/4awmy/Classroom-Emotion-System.git
cd Classroom-Emotion-System

# Checkout dev branch — never commit directly to main
git checkout dev
git pull origin dev
```

### 5.2 Python API — Local Setup (S1 + S3)

```bash
cd python-api

# Create virtual environment
python -m venv .venv

# Activate (Windows)
.venv\Scripts\activate

# Activate (Mac/Linux)
source .venv/bin/activate

# Install all dependencies
pip install -r requirements.txt

# If face_recognition fails on Windows, install dlib manually first:
pip install cmake
pip install dlib
pip install face-recognition

# Copy environment file
cp .env.example .env
# → Open .env and fill in your API keys (see Section 4.1)

# Create the data directories
mkdir -p data/exports data/plans data/evidence

# Initialize SQLite database (creates all tables)
python -c "from database import engine; import models; models.Base.metadata.create_all(bind=engine)"

# Verify database created:
ls data/   # should show classroom_emotions.db

# Seed with synthetic data for testing
python ../notebooks/generate_synthetic_data.py

# Run the development server
uvicorn main:app --reload --port 8000

# Test it works:
curl http://localhost:8000/health
# Expected: {"status": "ok"}

# View API docs:
# Open browser: http://localhost:8000/docs
```

**Verify all model imports work (S1):**
```bash
python -c "
import ultralytics
import face_recognition
import hsemotion_onnx
import openai
import cv2
print('All vision imports OK')
"
```

### 5.3 R/Shiny App — Local Setup (S2)

Open RStudio, then run the following in the R console:

```r
# Install all required packages (run once)
install.packages(c(
  "shiny",
  "shinydashboard",
  "shinyalert",
  "shinyjs",
  "DT",
  "plotly",
  "ggplot2",
  "dplyr",
  "lubridate",
  "httr2",
  "openxlsx",
  "rmarkdown",
  "rsconnect"
))

# Verify key packages loaded:
library(shiny)
library(httr2)
library(DT)
library(plotly)
cat("All R packages OK\n")
```

**Configure the API URL in `shiny-app/global.R`:**
```r
# During local development, point to local FastAPI:
FASTAPI_BASE <- "http://localhost:8000"

# After Railway deployment, change to:
# FASTAPI_BASE <- "https://your-app.railway.app"
```

**Run the app locally:**
```r
# In RStudio, open shiny-app/app.R and click "Run App"
# Or from R console:
setwd("shiny-app")
shiny::runApp()
# Opens at http://127.0.0.1:XXXX
```

**Test connection to FastAPI:**
```r
# Run in R console while FastAPI is running locally
library(httr2)
resp <- request("http://localhost:8000/health") |> req_perform()
resp_body_json(resp)
# Expected: list(status = "ok")
```

### 5.4 React Native App — Local Setup (S4)

```bash
cd react-native-app

# Install dependencies
npm install

# Copy environment file
cp .env.example .env
# Open .env and set:
# EXPO_PUBLIC_API_URL=http://localhost:8000
# EXPO_PUBLIC_WS_URL=ws://localhost:8000

# Start the Expo development server
npx expo start

# Options shown in terminal:
# Press 'a' → open on Android emulator
# Press 'i' → open on iOS simulator (Mac only)
# Scan QR code → open on physical device with Expo Go app
```

**Test WebSocket connection:**
```typescript
// In services/api.ts, the WS_URL should be ws://localhost:8000/session/ws
// After starting expo, open focus.tsx screen and check console for:
// "WebSocket connected"
```

**Recommended VS Code extensions for S4:**
- ESLint
- Prettier
- React Native Tools
- Expo Tools

---

## 6. Database Architecture

### 6.1 The Two-Layer Data Strategy

```
┌─────────────────────────────────────────────────────┐
│             LIVE LECTURE (runtime)                  │
│  Camera → Vision Pipeline → FastAPI → SQLite DB     │
│  (concurrent-safe, fast writes, no locking issues)  │
└──────────────────────┬──────────────────────────────┘
                       │  APScheduler runs at 02:00 nightly
                       ▼
┌─────────────────────────────────────────────────────┐
│            ANALYTICS LAYER (read-only)              │
│  export_service.py → CSV files in data/exports/     │
│  R/Shiny reads these static CSVs — no live DB conn  │
└─────────────────────────────────────────────────────┘
```

**Why:** Writing live emotion data directly to CSV causes concurrent read/write file locks when R/Shiny is simultaneously reading. SQLite handles concurrent access safely. R/Shiny never touches the live database — it reads only the nightly-exported static CSVs.

### 6.2 SQLite Table Schemas — LOCKED Week 1

All 4 members must sign off on this schema via PR before any feature code is written. **Never rename a column after lock.**

#### `students`
```sql
CREATE TABLE students (
    student_id    TEXT PRIMARY KEY,        -- e.g. S01
    name          TEXT NOT NULL,
    email         TEXT,
    face_encoding BLOB,                    -- 128-dim float64 numpy array as bytes
    enrolled_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### `lectures`
```sql
CREATE TABLE lectures (
    lecture_id   TEXT PRIMARY KEY,         -- e.g. L1
    lecturer_id  TEXT NOT NULL,
    title        TEXT,
    subject      TEXT,
    start_time   DATETIME,
    end_time     DATETIME,
    slide_url    TEXT
);
```

#### `emotion_log`
```sql
CREATE TABLE emotion_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id       TEXT NOT NULL REFERENCES students(student_id),
    lecture_id       TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp        DATETIME DEFAULT CURRENT_TIMESTAMP,
    emotion          TEXT NOT NULL,        -- Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    confidence       REAL NOT NULL,        -- fixed per emotion state (see Section 8.2)
    engagement_score REAL NOT NULL         -- equals confidence (computed at write time)
);
```

#### `attendance_log`
```sql
CREATE TABLE attendance_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    status      TEXT NOT NULL,             -- Present | Absent
    method      TEXT NOT NULL             -- AI | Manual | QR
);
```

#### `materials`
```sql
CREATE TABLE materials (
    material_id  TEXT PRIMARY KEY,         -- e.g. M01
    lecture_id   TEXT NOT NULL REFERENCES lectures(lecture_id),
    lecturer_id  TEXT NOT NULL,
    title        TEXT NOT NULL,
    drive_link   TEXT,
    uploaded_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### `incidents`
```sql
CREATE TABLE incidents (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id     TEXT REFERENCES students(student_id),
    exam_id        TEXT,
    timestamp      DATETIME DEFAULT CURRENT_TIMESTAMP,
    flag_type      TEXT NOT NULL,          -- phone_on_desk | head_rotation | absent | multiple_persons | identity_mismatch | app_background
    severity       INTEGER NOT NULL,       -- 1 low | 2 medium | 3 high
    evidence_path  TEXT                    -- path to screenshot in data/evidence/
);
```

#### `transcripts`
```sql
CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    chunk_text  TEXT NOT NULL,             -- Whisper output for this 5s audio chunk
    language    TEXT                       -- detected language: ar | en | mixed
);
```

#### `notifications`
```sql
CREATE TABLE notifications (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecturer_id TEXT NOT NULL,
    lecture_id  TEXT REFERENCES lectures(lecture_id),
    reason      TEXT NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    read        INTEGER DEFAULT 0          -- 0 = unread | 1 = read
);
```

#### `focus_strikes`
```sql
CREATE TABLE focus_strikes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    strike_type TEXT NOT NULL              -- app_background (React Native AppState only)
);
```

### 6.3 Nightly CSV Export Schemas (read by R/Shiny — column names locked)

```
exports/emotions.csv:
    student_id, lecture_id, timestamp, emotion, confidence, engagement_score

exports/attendance.csv:
    student_id, lecture_id, timestamp, status, method

exports/materials.csv:
    material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at

exports/incidents.csv:
    student_id, exam_id, timestamp, flag_type, severity, evidence_path

exports/transcripts.csv:
    lecture_id, timestamp, chunk_text, language

exports/notifications.csv:
    student_id, lecturer_id, lecture_id, reason, created_at, read
```

### 6.4 Nightly Export Script

File: `python-api/services/export_service.py`

```python
import pandas as pd
from apscheduler.schedulers.background import BackgroundScheduler
from database import SessionLocal

EXPORT_DIR = "data/exports"

def export_all():
    db = SessionLocal()
    try:
        queries = {
            "emotions":      "SELECT student_id, lecture_id, timestamp, emotion, confidence, engagement_score FROM emotion_log",
            "attendance":    "SELECT student_id, lecture_id, timestamp, status, method FROM attendance_log",
            "materials":     "SELECT material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at FROM materials",
            "incidents":     "SELECT student_id, exam_id, timestamp, flag_type, severity, evidence_path FROM incidents",
            "transcripts":   "SELECT lecture_id, timestamp, chunk_text, language FROM transcripts",
            "notifications": "SELECT student_id, lecturer_id, lecture_id, reason, created_at, read FROM notifications",
        }
        for name, query in queries.items():
            df = pd.read_sql(query, db.bind)
            df.to_csv(f"{EXPORT_DIR}/{name}.csv", index=False)
    finally:
        db.close()

scheduler = BackgroundScheduler()
scheduler.add_job(export_all, "cron", hour=2, minute=0)
scheduler.start()
```

---

## 7. Vision Pipeline

### 7.1 Hardware Assumption

**ONE fixed high-resolution IP camera** mounted at the front of the classroom facing the student crowd. No student webcams, no mobile cameras, no per-student devices. All processing is server-side in `vision_pipeline.py`.

Camera connects via **RTSP stream**: `rtsp://192.168.x.x/stream` — set in `CLASSROOM_CAMERA_URL` env var.

### 7.2 Sequential Pipeline — 1 Frame Every 5 Seconds

```
Camera frame (every 5s)
        │
        ▼
┌───────────────┐
│  YOLOv8       │  Detect all persons in crowd frame
│  Person detect│  Output: list of bounding boxes [x1,y1,x2,y2]
└───────┬───────┘
        │  For each bounding box:
        ▼
┌─────────────────┐
│ face_recognition│  Crop face ROI → 128-dim encoding
│ ID match        │  Compare against SQLite student encodings
└───────┬─────────┘  Output: student_id (or "unknown" → skip)
        │  For each identified student:
        ▼
┌───────────────┐
│  HSEmotion    │  Analyze emotion on cropped face ROI
│  Emotion      │  Output: raw_label + softmax scores
└───────┬───────┘
        │
        ▼
  map_emotion() → educational state
  get_confidence() → fixed score (switch-case)
  INSERT into emotion_log + attendance_log (first detection)
```

**Why 5 seconds:** 3 sequential models on a crowd frame is compute-heavy. 1 frame/5s = 12 samples/minute per student — sufficient resolution without overloading the server.

### 7.3 HSEmotion Model & Emotion Mapping

**Model:** `hsemotion-onnx` (`enet_b0_8_best_afew`) — trained on AffectNet (450K+ manually annotated images, ~75–80% real-world accuracy).

| HSEmotion raw output | Educational state | Intensity rule |
|---|---|---|
| `neutral` | **Focused** | Always |
| `happy`, `surprise` | **Engaged** | Always |
| `fear` | **Anxious** | Always |
| `anger`, `disgust` | **Confused** | softmax score < 0.65 |
| `anger`, `disgust` | **Frustrated** | softmax score ≥ 0.65 |
| `sad` | **Disengaged** | Always |

### 7.4 Pipeline Implementation

File: `python-api/services/vision_pipeline.py`

```python
import cv2, time, os, numpy as np, face_recognition
from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
from ultralytics import YOLO
from datetime import datetime
from database import SessionLocal
from models import EmotionLog, AttendanceLog

FRAME_INTERVAL = 5  # seconds — do not change

def map_emotion(raw_label: str, raw_score: float) -> str:
    HIGH_INTENSITY = 0.65
    match raw_label.lower():
        case "neutral":           return "Focused"
        case "happy" | "surprise": return "Engaged"
        case "fear":              return "Anxious"
        case "anger" | "disgust": return "Frustrated" if raw_score >= HIGH_INTENSITY else "Confused"
        case "sad":               return "Disengaged"
        case _:                   return "Focused"

EMOTION_CONFIDENCE = {
    "Focused": 1.00, "Engaged": 0.85, "Confused": 0.55,
    "Anxious": 0.35, "Frustrated": 0.25, "Disengaged": 0.00,
}

def get_confidence(emotion: str) -> float:
    return EMOTION_CONFIDENCE.get(emotion, 0.50)

yolo_model    = YOLO("yolov8n.pt")
hs_recognizer = HSEmotionRecognizer(model_name="enet_b0_8_best_afew")

def load_student_encodings(db) -> dict:
    rows = db.execute(
        "SELECT student_id, face_encoding FROM students WHERE face_encoding IS NOT NULL"
    ).fetchall()
    return {r.student_id: np.frombuffer(r.face_encoding, dtype=np.float64) for r in rows}

def identify_face(face_enc, known: dict, tolerance=0.5) -> str:
    if not known:
        return "unknown"
    ids, encs = list(known.keys()), list(known.values())
    distances = face_recognition.face_distance(encs, face_enc)
    best = int(np.argmin(distances))
    return ids[best] if distances[best] <= tolerance else "unknown"

def run_pipeline(lecture_id: str, camera_url: str):
    cap = cv2.VideoCapture(camera_url)
    db  = SessionLocal()
    known = load_student_encodings(db)
    seen_today = set()  # track attendance per session

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        results = yolo_model(frame, classes=[0], verbose=False)
        boxes   = results[0].boxes.xyxy.cpu().numpy().astype(int) if results[0].boxes else []

        for box in boxes:
            x1, y1, x2, y2 = box[:4]
            roi = frame[y1:y2, x1:x2]
            if roi.size == 0:
                continue
            rgb_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)

            encs = face_recognition.face_encodings(rgb_roi)
            if not encs:
                continue
            student_id = identify_face(encs[0], known)
            if student_id == "unknown":
                continue

            try:
                raw_label, scores = hs_recognizer.predict_emotions(roi, logits=False)
                raw_score  = float(max(scores))
                emotion    = map_emotion(raw_label, raw_score)
                confidence = get_confidence(emotion)
            except Exception:
                continue

            db.add(EmotionLog(
                student_id=student_id, lecture_id=lecture_id,
                timestamp=datetime.utcnow(), emotion=emotion,
                confidence=confidence, engagement_score=confidence
            ))

            if student_id not in seen_today:
                seen_today.add(student_id)
                db.add(AttendanceLog(
                    student_id=student_id, lecture_id=lecture_id,
                    timestamp=datetime.utcnow(), status="Present", method="AI"
                ))

            db.commit()

        time.sleep(FRAME_INTERVAL)

    cap.release()
    db.close()
```

---

## 8. Engagement Score — LOCKED, implement exactly

### 8.1 Design Principle

Confidence is **not** taken from the model's softmax output. It is a **fixed, predetermined value per educational emotion state** — deterministic, reproducible, and academically defensible. `engagement_score == confidence`. No multiplication needed.

### 8.2 Fixed Confidence (Switch-Case) — LOCKED

| Educational State | Fixed Confidence | Engagement Level | Rationale |
|---|---|---|---|
| Focused | **1.00** | High | Active attentive processing |
| Engaged | **0.85** | High | Positive affect |
| Confused | **0.55** | Moderate | Productive struggle — monitor |
| Anxious | **0.35** | Low | Stress — flag, especially in exams |
| Frustrated | **0.25** | Low | Blocked — intervene urgently |
| Disengaged | **0.00** | Critical | Withdrawn — immediate alert |

### 8.3 Engagement Level Thresholds

| Level | Score range | Action |
|---|---|---|
| High | ≥ 0.75 | No action |
| Moderate | 0.45–0.74 | Monitor |
| Low | 0.25–0.44 | Flag to lecturer |
| Critical | < 0.25 | Intervention alert |

### 8.4 Derived Class Metrics (computed in R)

```
cognitive_load = confusion_rate + frustration_rate
                 (> 0.50 → lecture pace too fast)

class_valence  = (focused_rate + engaged_rate)
                 - (frustrated_rate + disengaged_rate + anxiety_rate)
                 (positive = healthy | negative = intervention needed)
```

### 8.5 R Aggregation Module

File: `shiny-app/modules/engagement_score.R`

```r
library(dplyr)

compute_engagement <- function(emotions_df) {

  by_lecture <- emotions_df |>
    group_by(student_id, lecture_id) |>
    summarise(
      engagement_score  = round(mean(engagement_score), 3),
      dominant_emotion  = names(which.max(table(emotion))),
      confusion_rate    = round(mean(emotion == "Confused"),    3),
      frustration_rate  = round(mean(emotion == "Frustrated"),  3),
      anxiety_rate      = round(mean(emotion == "Anxious"),     3),
      disengaged_rate   = round(mean(emotion == "Disengaged"),  3),
      focused_rate      = round(mean(emotion == "Focused"),     3),
      engaged_rate      = round(mean(emotion == "Engaged"),     3),
      n_observations    = n(),
      .groups = "drop"
    ) |>
    mutate(
      cognitive_load   = round(confusion_rate + frustration_rate, 3),
      class_valence    = round((focused_rate + engaged_rate)
                               - (frustration_rate + disengaged_rate + anxiety_rate), 3),
      engagement_level = case_when(
        engagement_score >= 0.75 ~ "High",
        engagement_score >= 0.45 ~ "Moderate",
        engagement_score >= 0.25 ~ "Low",
        TRUE                     ~ "Critical"
      )
    )

  by_student <- by_lecture |>
    group_by(student_id) |>
    summarise(
      avg_engagement     = round(mean(engagement_score), 3),
      avg_cognitive_load = round(mean(cognitive_load),   3),
      trend_slope        = coef(lm(engagement_score ~ seq_along(engagement_score)))[2],
      lectures_attended  = n(),
      .groups = "drop"
    )

  list(by_lecture = by_lecture, by_student = by_student)
}
```


---

## 9. Audio Pipeline — Whisper

### 9.1 Why Whisper

The lecturer code-switches between **Egyptian Arabic (ar-EG)** and **English**. Google Cloud Speech-to-Text requires a single declared language and fails on code-switching. OpenAI Whisper auto-detects language per chunk and handles mixed-language audio natively.

### 9.2 Implementation

File: `python-api/services/whisper_service.py`

```python
import openai, asyncio, io, wave, numpy as np
import sounddevice as sd
from database import SessionLocal
from models import Transcript
from datetime import datetime

SAMPLE_RATE   = 16000
CHUNK_SECONDS = 5
openai_client = openai.OpenAI()  # uses OPENAI_API_KEY

active_connections = []  # shared with session.py WebSocket manager

def capture_chunk() -> np.ndarray:
    audio = sd.rec(int(CHUNK_SECONDS * SAMPLE_RATE),
                   samplerate=SAMPLE_RATE, channels=1, dtype="int16")
    sd.wait()
    return audio

def audio_to_wav_bytes(audio: np.ndarray) -> io.BytesIO:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio.tobytes())
    buf.seek(0)
    buf.name = "audio.wav"
    return buf

async def stream_captions(lecture_id: str):
    """Run in background — captures mic, transcribes, broadcasts, saves to DB."""
    loop = asyncio.get_event_loop()
    db   = SessionLocal()

    while True:
        audio_chunk = await loop.run_in_executor(None, capture_chunk)
        wav_buf     = audio_to_wav_bytes(audio_chunk)

        try:
            response = openai_client.audio.transcriptions.create(
                model="whisper-1",
                file=wav_buf,
                # No language set — Whisper auto-detects ar/en code-switching
            )
            text = response.text.strip()
            if not text:
                continue

            # Save to transcripts table
            db.add(Transcript(
                lecture_id=lecture_id,
                timestamp=datetime.utcnow(),
                chunk_text=text,
                language="mixed"
            ))
            db.commit()

            # Broadcast to all connected WebSocket clients
            payload = {"event": "caption", "text": text, "lecture_id": lecture_id}
            for ws in active_connections:
                await ws.send_json(payload)

        except Exception as e:
            print(f"Whisper error: {e}")
```

---

## 10. Roster Ingestion Pipeline

### 10.1 Overview

Before any lecture, the lecturer uploads the student roster so the vision pipeline can identify faces. This is a one-time per-course operation performed from the Shiny Lecturer panel.

### 10.2 Data Flow

```
Lecturer in Shiny → Submodule A (Roster Setup)
    │  uploads: roster.csv + images.zip
    ▼
httr2 multipart POST /roster/upload
    │
    ▼
FastAPI roster.py:
    │  1. Parse roster.csv → INSERT into students (student_id, name, email)
    │  2. Unzip images.zip — each file named {student_id}.jpg
    │  3. face_recognition.face_encodings(image) → 128-dim numpy array
    │  4. encoding.tobytes() → store as BLOB in students.face_encoding
    ▼
SQLite students table ready — vision pipeline can now identify this cohort
```

### 10.3 Implementation

File: `python-api/routers/roster.py`

```python
import face_recognition, numpy as np, zipfile, io, csv
from fastapi import APIRouter, UploadFile, File, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import Student

router = APIRouter()

@router.post("/upload")
async def upload_roster(
    roster_csv: UploadFile = File(...),
    images_zip: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Parse roster CSV
    content = (await roster_csv.read()).decode("utf-8").splitlines()
    students_created = 0
    for row in csv.DictReader(content):
        if not db.query(Student).filter_by(student_id=row["student_id"]).first():
            db.add(Student(student_id=row["student_id"],
                           name=row["name"], email=row.get("email")))
            students_created += 1
    db.commit()

    # 2. Extract images and encode faces
    zip_bytes = await images_zip.read()
    encodings_saved = 0
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        for filename in zf.namelist():
            student_id = filename.split(".")[0]
            img_array  = face_recognition.load_image_file(io.BytesIO(zf.read(filename)))
            encs       = face_recognition.face_encodings(img_array)
            if not encs:
                continue
            db.query(Student).filter_by(student_id=student_id).update(
                {"face_encoding": encs[0].astype(np.float64).tobytes()}
            )
            encodings_saved += 1
    db.commit()

    return {"students_created": students_created, "encodings_saved": encodings_saved}
```

---

## 11. State Case Scenarios — Chronological Data Flows

### State 1: Roster Initialization

```
Step 1  Lecturer opens Shiny → Roster Setup tab
Step 2  Uploads roster.csv (columns: student_id, name, email) + images.zip
Step 3  Shiny: httr2 multipart POST /roster/upload
Step 4  FastAPI:
          a. Parses CSV → INSERT Student rows into SQLite
          b. Unzips images → face_recognition.face_encodings() per image
          c. Serializes 128-dim numpy array → BLOB
          d. Stores in students.face_encoding
Step 5  FastAPI returns {students_created: N, encodings_saved: N}
Step 6  Shiny shows success notification
Step 7  Next lecture start → load_student_encodings() picks up new encodings
```

### State 2: Live Lecture Loop

```
Step 1  Lecturer clicks "Start Lecture" in Shiny
          httr2 POST /session/start {lecture_id, lecturer_id, slide_url}
Step 2  FastAPI session.py:
          a. INSERT into lectures table
          b. Broadcasts WS: {event: "session:start", slideUrl, lectureId}
          c. Spawns background thread → vision_pipeline.run_pipeline()
          d. Spawns background coroutine → whisper_service.stream_captions()
Step 3  Vision pipeline (every 5 seconds):
          a. Capture frame from classroom camera (RTSP)
          b. YOLOv8 → person bounding boxes
          c. Crop ROI → face_recognition → student_id match
          d. HSEmotion → raw_label + score → map_emotion() → educational state
          e. get_confidence() → fixed score
          f. INSERT emotion_log
          g. INSERT attendance_log (first detection only, method=AI)
Step 4  Whisper loop (every 5 seconds):
          a. Capture 5s audio from classroom mic
          b. Whisper API → transcript text (handles ar-EG/en-US code-switching)
          c. INSERT into transcripts table
          d. Broadcast WS: {event: "caption", text: "..."}
Step 5  React Native student app:
          a. AppState listener: app goes background → WS emit strike
             {event: "strike", student_id, lecture_id, type: "app_background"}
          b. FastAPI → INSERT focus_strikes
          c. Caption received → CaptionBar displays for 4s
Step 6  Shiny live dashboard (reactiveTimer every 10s):
          a. GET /emotion/live?lecture_id= → last 60 emotion_log rows
          b. D1: engagement gauge updated
          c. D2–D7: all panels refreshed
Step 7  Confusion spike check (Shiny observer, every 10s):
          a. confusion_rate = mean(emotion == "Confused") over last 120 rows
          b. If ≥ 0.40 → triggers State 3
Step 8  Lecturer clicks "End Lecture"
          POST /session/end → updates lectures.end_time
          Broadcasts {event: "session:end"}
          Background threads stopped
Step 9  Nightly 02:00: APScheduler → export_all() → CSV files written
          R/Shiny reactivePoll detects mtime change → analytics dashboards refresh
```

### State 3: AI Intervention (Confusion Spike)

```
Step 1  Shiny observer: confusion_rate ≥ 0.40 over last 2 minutes
Step 2  Shiny: httr2 POST /gemini/question {lecture_id: "L1"}
Step 3  FastAPI gemini.py:
          a. Retrieves slide_url from lectures table
          b. Extracts text via pdfplumber
          c. gemini_service.generate_fresh_brainer(slide_text)
Step 4  Gemini 1.5 Flash generates ONE clarifying question (≤ 2 sentences)
Step 5  FastAPI returns {question: "Can you clarify...?"}
Step 6  Shiny: shinyalert() popup
          "⚠ Class confused (42% rate)"
          "Suggested: Can you clarify...?"
          Buttons: "Ask it" | "Dismiss"
Step 7  Lecturer clicks "Ask it"
          Shiny: httr2 POST /session/broadcast
          FastAPI broadcasts WS: {event: "freshbrainer", question: "..."}
Step 8  React Native: bottom-sheet overlay in focus.tsx
          Shows question to student
```

---

## 12. Module Specifications

### 12.1 Admin View — R/Shiny (8 Panels)

File: `shiny-app/ui/admin_ui.R` + `shiny-app/server/admin_server.R`

All panels read from `data/exports/*.csv` via `reactivePoll` (checks file mtime every 60s). Injected into pre-existing AAST HTML template slots.

| # | Panel | Chart type | Key logic |
|---|---|---|---|
| 1 | Attendance Overview | `DT::datatable` | Columns: Course, Lecturer, Attendance%. Filters: dept + date range. Export: xlsx |
| 2 | Engagement Trend | `plotly` line | x=week, y=avg engagement_score, color=department |
| 3 | Dept Engagement Heatmap | `ggplot2 geom_tile` | x=week, y=dept, fill=avg engagement |
| 4 | At-Risk Cohort | `DT::datatable` | >20% engagement drop over 3 consecutive lectures. "Flag" → POST /notify/lecturer |
| 5 | Lecture Effectiveness (LES) | `DT::datatable` | LES = 0.5×avg_engagement + 0.3×(1−confusion_rate) + 0.2×attendance_rate. Top 10% green, bottom 10% red |
| 6 | Emotion Distribution | `ggplot2 geom_col(position="fill")` | Stacked bar per dept, normalized. All 6 emotion states shown |
| 7 | Lecturer Cluster Map | `plotly` scatter | kmeans(avg_LES, attendance_variance, k=3). Labels: High/Consistent/Needs Support |
| 8 | Time-of-Day Heatmap | `ggplot2 geom_tile` | x=weekday, y=slot 08:00–20:00, fill=avg engagement |


### 12.2 Lecturer View — R/Shiny (5 Submodules)

File: `shiny-app/ui/lecturer_ui.R` + `shiny-app/server/lecturer_server.R`

---

**Submodule A — Roster Setup**
- `fileInput("roster_csv")` + `fileInput("images_zip")`
- Progress bar during upload
- `httr2 POST /roster/upload` (multipart)
- Success notification shows `encodings_saved` count

---

**Submodule B — Material Upload**
- `fileInput` + `selectInput(lecture_id)` + title text input
- `httr2 POST /upload/material` (multipart) → Google Drive → materials table
- Material list below refreshes from `materials.csv`

---

**Submodule C — Attendance**
- **Manual mode:** editable `DT::datatable()` → save → `httr2 POST /attendance/manual`
- **AI mode:** button → `httr2 POST /attendance/start` → status polling every 5s
- **QR fallback:** `httr2 GET /attendance/qr/{lecture_id}` → `renderImage()`

---

**Submodule D — Live Lecture Dashboard (7 panels)**

Polls `GET /emotion/live?lecture_id=` every 10 seconds via `reactiveTimer(10000)`.

**D1 — Engagement Gauge**
- `plotly::plot_ly(type="indicator", mode="gauge+number")`
- Value = `mean(engagement_score)` of last 60 readings
- Zones: red < 0.25 | amber 0.25–0.45 | green > 0.45

**D2 — Real-Time Emotion Timeline**
- `plotly::plot_ly(type="scatter", mode="lines")`
- x = timestamp (last 30 min), y = % of class per state, 6 lines
- Shows the lecturer *when* confusion started during the lecture

```r
live_timeline <- live_data |>
  mutate(time_bucket = floor_date(timestamp, "2 minutes")) |>
  group_by(time_bucket, emotion) |>
  summarise(pct = n() / nrow(live_data), .groups = "drop")
```

**D3 — Cognitive Load Indicator**
- Value box: `cognitive_load = confusion_rate + frustration_rate`
- green < 0.30 | amber 0.30–0.50 | red > 0.50 → "Overloaded — slow down"

**D4 — Class Valence Meter**
- Horizontal gauge: `class_valence = (focused + engaged) - (frustrated + disengaged + anxious)`
- Range −1.0 to +1.0. If valence < 0 for > 5 readings → `shinyalert` warning

**D5 — Per-Student Emotion Heatmap**
- `ggplot2::geom_tile()`
- x = 5-min segments, y = student_id, fill = dominant emotion
- Colors: Focused=dark green | Engaged=green | Confused=amber | Frustrated=orange | Anxious=purple | Disengaged=red

**D6 — Persistent Struggle Alert Table**
- `DT::datatable()` — students Confused/Frustrated for ≥ 3 consecutive readings
- Columns: Student ID, Name, Current Emotion, Duration (s), Consecutive Readings
- Amber = Confused×3 | Red = Frustrated×3

```r
persistent <- live_data |>
  arrange(student_id, timestamp) |>
  group_by(student_id) |>
  mutate(
    is_struggling = emotion %in% c("Confused", "Frustrated"),
    streak        = cumsum(!is_struggling),
    consecutive   = ave(is_struggling, student_id, streak, FUN = cumsum)
  ) |>
  filter(consecutive >= 3) |>
  slice_tail(n = 1) |>
  ungroup()
```

**D7 — Peak Confusion Moment Detector**
- Value box: "Most confusing moment: 10:42 AM"
- Logic: 2-minute window with highest `confusion_rate + frustration_rate`
- Displayed after lecture ends as post-session insight

---

**Submodule E — Student Reports**
- `selectInput(student_id)` → per-student card
- Shows: engagement trend chart, cognitive load trend, dominant emotion, valence history
- AI plan: `httr2 GET /notes/{student_id}/plan` → `renderMarkdown()`
- PDF: `downloadHandler()` → `rmarkdown::render("reports/student_report.Rmd", params=list(student_id=input$student_id))`

**student_report.Rmd sections:**
1. Executive Summary (avg engagement, dominant emotion, cognitive load)
2. Engagement trend chart across all lectures
3. Emotion distribution pie chart
4. Cognitive load timeline
5. AI intervention plan (3 Gemini-generated steps)
6. Attendance record

### 12.3 Student Mobile App — React Native

> **Students only.** Admin and Lecturer do not use this app.

**Login** (`app/(auth)/login.tsx`)
- Calls `POST /auth/login` with student_id + password
- Stores JWT in Zustand store
- Navigates to home screen on success

**Home** (`app/(student)/home.tsx`)
- Fetches upcoming lectures from `GET /session/upcoming`
- Shows engagement summary from last lecture
- Navigation entry point to focus mode and notes

**Focus Mode** (`app/(student)/focus.tsx`)
```typescript
import { AppState, AppStateStatus } from 'react-native';

useEffect(() => {
  const sub = AppState.addEventListener('change', (next: AppStateStatus) => {
    if (next !== 'active' && focusActive) {
      socket.emit('strike', {
        student_id: studentId,
        lecture_id: activeLectureId,
        type: 'app_background',
      });
      setStrikes(s => s + 1);
    }
  });
  return () => sub.remove();
}, [focusActive]);
```
- No OS-level locks — AppState API only
- Receives `session:start` → shows slide URL + locks focus
- Receives `session:end` → releases focus
- Receives `freshbrainer` → renders bottom-sheet question

**CaptionBar** (`components/CaptionBar.tsx`)
- WS event `caption` → display text overlay, auto-clear after 4s
- RTL-aware for Arabic text

**Smart Notes** (`app/(student)/notes.tsx`)
- Fetches `GET /notes/{student_id}/{lecture_id}` after session ends
- `react-native-markdown-display` for rendering
- ✱ sections get highlight style via custom `StyleSheet`
- `Share.share()` to export notes natively

### 12.4 Exam Proctoring — Camera-Based

**No JavaScript browser lockdowns. No device locks. Camera handles everything.**

| Detection | Tool | Flag written | Severity |
|---|---|---|---|
| Phone on desk | YOLOv8 class: cell phone | `phone_on_desk` | 3 |
| No face > 5s | face_recognition | `absent` | 3 |
| Multiple persons | YOLO person count > 1 | `multiple_persons` | 3 |
| Extreme head rotation | MediaPipe FaceMesh | `head_rotation` | 2 |
| Identity mismatch | face_recognition vs enrolled | `identity_mismatch` | 3 |
| App goes to background | React Native AppState | `app_background` | 1 |

**Auto-submit:** 3 × Severity-3 incidents within any 10-minute window → `POST /exam/submit` automatically.

All incidents saved to SQLite `incidents` table with screenshot in `data/evidence/`.

---

## 13. FastAPI Backend

### 13.1 `python-api/main.py`

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import emotion, attendance, session, gemini, exam, roster, upload
from services.export_service import scheduler
from database import engine
import models

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="AAST LMS API")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                  allow_methods=["*"], allow_headers=["*"])

app.include_router(emotion.router,     prefix="/emotion")
app.include_router(attendance.router,  prefix="/attendance")
app.include_router(session.router,     prefix="/session")
app.include_router(gemini.router,      prefix="/gemini")
app.include_router(exam.router,        prefix="/exam")
app.include_router(roster.router,      prefix="/roster")
app.include_router(upload.router,      prefix="/upload")
```

### 13.2 `python-api/requirements.txt`

```
fastapi
uvicorn[standard]
sqlalchemy
alembic
hsemotion-onnx          # AffectNet-trained emotion recognition
opencv-python-headless
face-recognition
ultralytics             # YOLOv8
mediapipe               # head posture estimation for exam
openai                  # Whisper API
google-generativeai     # Gemini API
pdfplumber              # slide text extraction
google-api-python-client  # Google Drive uploads
apscheduler             # nightly CSV export cron
python-multipart        # file upload
pandas
sounddevice             # microphone capture
numpy
python-jose[cryptography]  # JWT
python-dotenv
```

### 13.3 Gemini Service

File: `python-api/services/gemini_service.py`

```python
import google.generativeai as genai, os

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-1.5-flash")

def generate_smart_notes(transcript: str, distraction_timestamps: list[str]) -> str:
    ts = ", ".join(distraction_timestamps)
    return model.generate_content(f"""
You are a study assistant. Generate concise study notes from the lecture transcript.
For content taught during these timestamps when the student was distracted: [{ts}],
add a ✱ marker and a plain-English re-explanation.
TRANSCRIPT: {transcript}
Return only clean markdown.
""").text

def generate_fresh_brainer(slide_text: str) -> str:
    return model.generate_content(f"""
Based on this lecture content, generate ONE clarifying question (under 2 sentences)
to help confused students refocus.
SLIDE CONTENT: {slide_text}
""").text

def generate_intervention_plan(student_emotion_history: str) -> str:
    return model.generate_content(f"""
You are an academic advisor. A student has shown this emotion pattern across lectures:
{student_emotion_history}
Suggest exactly 3 concrete, actionable steps the lecturer can take.
Return as a numbered markdown list.
""").text
```

### 13.4 Environment Variables

```bash
# python-api/.env  — NEVER commit this file. Only commit .env.example.
GEMINI_API_KEY=                              # from Google AI Studio
OPENAI_API_KEY=                              # from OpenAI platform (Whisper)
GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json  # Google Drive service account
JWT_SECRET=                                  # any long random string
FASTAPI_BASE_URL=https://your-app.railway.app
CLASSROOM_CAMERA_URL=rtsp://192.168.1.x/stream
DATABASE_URL=sqlite:///./data/classroom_emotions.db

# react-native-app/.env
EXPO_PUBLIC_API_URL=https://your-app.railway.app
EXPO_PUBLIC_WS_URL=wss://your-app.railway.app
```

---

## 14. Step-by-Step Development Guide

### Phase 1 — Foundation (Weeks 1–3)

#### Week 1: Data Contract (Blocks everything — finish first)

**S3 does this, all 4 members review:**

1. Create `data-schema/README.md` with all 9 SQLite table schemas from Section 6.2
2. Include CSV export schemas from Section 6.3
3. Include JWT token payload structure: `{student_id, role, exp}`
4. Open PR → all 4 members must approve before merge
5. After merge: S3 creates `database.py` + `models.py` and runs `python -c "...create_all()"` to verify all tables create without errors

#### Week 1–2: S3 builds all mock endpoints

```bash
# For each router file, add stub routes returning hardcoded JSON
# Example: routers/emotion.py
@router.get("/live")
def get_live_emotions():
    return [
        {"student_id": "S01", "emotion": "Focused", "confidence": 1.0, "engagement_score": 1.0},
        {"student_id": "S02", "emotion": "Confused", "confidence": 0.55, "engagement_score": 0.55},
    ]

# Deploy to Railway after each router is stubbed
railway up

# Share Railway URL with S2 and S4 immediately
```

**All mock routes that must exist before S2 and S4 start:**
- `GET /health` → `{"status": "ok"}`
- `POST /auth/login` → `{"token": "mock.jwt.token"}`
- `GET /emotion/live?lecture_id=L1` → array of emotion rows
- `POST /session/start` → `{"status": "started"}`
- `GET /session/upcoming` → array of lecture objects
- `POST /roster/upload` → `{"students_created": 5, "encodings_saved": 5}`
- `GET /notes/{student_id}/{lecture_id}` → markdown string
- `GET /notes/{student_id}/plan` → markdown string
- `POST /gemini/question` → `{"question": "What is the difference between X and Y?"}`

#### Week 1–3: S1 Vision Environment

```bash
# 1. Install all packages
cd python-api
pip install -r requirements.txt

# 2. Test camera connection
python -c "
import cv2
cap = cv2.VideoCapture('rtsp://YOUR_CAMERA_URL')
ret, frame = cap.read()
print('Camera OK:', ret)
cv2.imwrite('test_frame.jpg', frame)
cap.release()
"

# 3. Test YOLO
python -c "
from ultralytics import YOLO
model = YOLO('yolov8n.pt')
results = model('test_frame.jpg')
print('Persons detected:', len(results[0].boxes))
"

# 4. Test HSEmotion
python -c "
from hsemotion_onnx.facial_emotions import HSEmotionRecognizer
import cv2
rec = HSEmotionRecognizer(model_name='enet_b0_8_best_afew')
img = cv2.imread('test_frame.jpg')
label, scores = rec.predict_emotions(img, logits=False)
print('Emotion:', label, 'Score:', max(scores))
"

# 5. Generate synthetic data
python notebooks/generate_synthetic_data.py
# Verify: python -c "import sqlite3; c=sqlite3.connect('python-api/data/classroom_emotions.db'); print(c.execute('SELECT COUNT(*) FROM emotion_log').fetchone())"
```

#### Week 1–3: S2 Shiny Shell

```r
# 1. Verify all packages installed
library(shiny); library(shinydashboard); library(DT)
library(plotly); library(ggplot2); library(dplyr); library(httr2)
cat("All packages loaded\n")

# 2. Set up global.R
# FASTAPI_BASE <- "https://your-railway-url.railway.app"

# 3. Test connection to mock API
library(httr2)
request(paste0(FASTAPI_BASE, "/health")) |>
  req_perform() |>
  resp_body_json()
# Expected: list(status = "ok")

# 4. Read synthetic CSV data
emotions <- read.csv("python-api/data/exports/emotions.csv")
source("shiny-app/modules/engagement_score.R")
result <- compute_engagement(emotions)
str(result$by_lecture)
# Expected: data frame with engagement_score, dominant_emotion, etc.

# 5. Run app shell
setwd("shiny-app")
shiny::runApp()
```

#### Week 1–3: S4 Expo Scaffold

```bash
cd react-native-app

# 1. Install and verify
npm install
npx expo start

# 2. Test auth against mock API
# Open app on Expo Go → login screen → enter any credentials
# Should navigate to home screen with mock JWT

# 3. Test WebSocket connection
# Open focus.tsx → check console for "WebSocket connected"
# In another terminal: curl -X POST https://railway-url/session/start
# Check console for session:start event

# 4. Test AppState
# On physical device: press home button while on focus screen
# Check console for "AppState changed to background"
# Check console for "Strike sent"
```

---

### Phase 2 — Core Features (Weeks 4–8)

#### S1: Full Vision Pipeline

```bash
# 1. Test face_recognition with test images
python -c "
import face_recognition, numpy as np
img = face_recognition.load_image_file('test_student.jpg')
enc = face_recognition.face_encodings(img)
print('Encodings found:', len(enc))
print('Encoding shape:', enc[0].shape)  # should be (128,)
"

# 2. Run single-frame pipeline test
python -c "
from services.vision_pipeline import run_pipeline
# Use a video file instead of RTSP for testing:
run_pipeline('L1', 'test_video.mp4')
"

# 3. Verify DB writes
python -c "
import sqlite3
db = sqlite3.connect('data/classroom_emotions.db')
rows = db.execute('SELECT * FROM emotion_log LIMIT 5').fetchall()
for r in rows: print(r)
"

# 4. Test nightly export manually
python -c "
from services.export_service import export_all
export_all()
import os
print(os.listdir('data/exports'))
"
```

#### S2: Admin Panels & Lecturer Submodules

Build panels in order of data dependency:
1. Panel 1 (Attendance) — simplest, just a DT table
2. `engagement_score.R` module — required by all other panels
3. Panel 2 (Trend) — depends on engagement_score
4. Panel 3 (Heatmap) — depends on engagement_score
5. `clustering.R` — write K-means with dplyr
6. Panel 7 (Cluster Map) — depends on clustering.R
7. Panels 4, 5, 6, 8 — all depend on engagement_score

For each panel, test with synthetic CSV data before connecting live API.

#### S3: Real Endpoints

Replace mock returns with real DB queries in each router:

```python
# Example: real emotion live endpoint
@router.get("/live")
def get_live_emotions(lecture_id: str, limit: int = 60, db: Session = Depends(get_db)):
    rows = db.query(EmotionLog)\
             .filter(EmotionLog.lecture_id == lecture_id)\
             .order_by(EmotionLog.timestamp.desc())\
             .limit(limit).all()
    return rows
```

#### S4: AppState Focus Mode & CaptionBar

```typescript
// Test AppState integration
// 1. Start a lecture session from Shiny
// 2. Confirm student app receives session:start
// 3. Press home button on device
// 4. Confirm strike logged in DB:
//    SELECT * FROM focus_strikes ORDER BY timestamp DESC LIMIT 5;
// 5. Return to app
// 6. Confirm strike counter shows on FocusOverlay
```

---

### Phase 3 — AI + Live Systems (Weeks 9–12)

#### S1: Gemini Services

```bash
# Test each prompt function
python -c "
from services.gemini_service import generate_fresh_brainer
result = generate_fresh_brainer('Today we covered Big O notation and its application in sorting algorithms.')
print(result)
"

python -c "
from services.gemini_service import generate_smart_notes
result = generate_smart_notes(
    transcript='Today we discussed recursion...',
    distraction_timestamps=['10:05', '10:12']
)
print(result)
"

python -c "
from services.gemini_service import generate_intervention_plan
result = generate_intervention_plan('Week 1: Mostly Confused. Week 2: Disengaged. Week 3: Frustrated.')
print(result)
"
```

#### S2: Live Dashboard + Reports

```r
# Test confusion alert with synthetic high-confusion data
high_confusion <- data.frame(
  student_id = "S01",
  lecture_id = "L1",
  timestamp  = Sys.time(),
  emotion    = rep("Confused", 50),
  confidence = 0.55,
  engagement_score = 0.55
)
# Load this into Shiny and verify shinyalert fires
```

#### S3: AI Endpoints

```bash
# Test all new endpoints
curl -X POST https://railway-url/gemini/question \
  -H "Content-Type: application/json" \
  -d '{"lecture_id": "L1"}'

curl https://railway-url/notes/S01/L1

curl https://railway-url/notes/S01/plan
```

---

### Phase 4 — Exam + Polish (Weeks 13–16)

#### S1: Exam Proctoring

```bash
# Test phone detection
python -c "
from ultralytics import YOLO
model = YOLO('yolov8n.pt')
results = model('test_exam_frame.jpg')
for box in results[0].boxes:
    cls = int(box.cls)
    if cls == 67:  # COCO class 67 = cell phone
        print('Phone detected!')
"

# Test head posture (MediaPipe FaceMesh)
python -c "
import mediapipe as mp, cv2
mp_face_mesh = mp.solutions.face_mesh
with mp_face_mesh.FaceMesh(static_image_mode=True) as face_mesh:
    img = cv2.imread('test_face.jpg')
    results = face_mesh.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    if results.multi_face_landmarks:
        print('Landmarks detected:', len(results.multi_face_landmarks[0].landmark))
"
```

#### S4: Exam Screen

```typescript
// Test exam lifecycle:
// 1. Navigate to /exam screen
// 2. Confirm POST /exam/start called on mount
// 3. Press home button → confirm app_background incident logged
// 4. Simulate auto-submit: emit exam:autosubmit from backend
// 5. Confirm navigation to "Exam Submitted" screen
```

---

## 15. Deployment Guide

### 15.1 FastAPI → Railway (S3)

**First-time setup:**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login with GitHub
railway login

# In the python-api/ directory:
cd python-api
railway init
# Select: "Empty Project" → name it "aast-lms-api"

# Set environment variables (do this BEFORE first deploy)
railway variables set GEMINI_API_KEY=your_key
railway variables set OPENAI_API_KEY=your_key
railway variables set JWT_SECRET=your_long_random_secret
railway variables set DATABASE_URL=sqlite:///./data/classroom_emotions.db
railway variables set CLASSROOM_CAMERA_URL=rtsp://192.168.x.x/stream
railway variables set GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json

# Upload gcloud_key.json as a Railway volume or secret file
# (Railway doesn't support file secrets natively — use a base64 env var instead)
railway variables set GCLOUD_KEY_B64=$(base64 -w 0 gcloud_key.json)
# Then in your code: decode it back at startup

# Create a Procfile in python-api/
echo "web: uvicorn main:app --host 0.0.0.0 --port \$PORT" > Procfile

# Deploy
railway up

# Get your URL
railway domain
# Example output: aast-lms-api.up.railway.app

# Test deployment
curl https://aast-lms-api.up.railway.app/health
# Expected: {"status": "ok"}
```

**Subsequent deploys:**
```bash
cd python-api
railway up
# Railway auto-deploys on push to main via GitHub integration (after first setup)
```

**Set up GitHub auto-deploy:**
1. Go to railway.app → your project → Settings
2. Connect to GitHub → select `4awmy/Classroom-Emotion-System`
3. Set root directory: `python-api`
4. Branch: `main`
5. Now every push to `main` auto-deploys the API

---

### 15.2 R/Shiny → shinyapps.io (S2)

**First-time setup:**
```r
# 1. Install rsconnect
install.packages("rsconnect")
library(rsconnect)

# 2. Authenticate (get tokens from shinyapps.io → Account → Tokens)
rsconnect::setAccountInfo(
  name   = "your-shinyapps-username",
  token  = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)

# 3. Set the production API URL in global.R before deploying
# FASTAPI_BASE <- "https://aast-lms-api.up.railway.app"

# 4. Deploy from the shiny-app/ directory
setwd("path/to/Classroom-Emotion-System/shiny-app")
rsconnect::deployApp(
  appName = "aast-lms",
  account = "your-shinyapps-username"
)

# 5. Your app is now at:
# https://your-shinyapps-username.shinyapps.io/aast-lms/
```

**Subsequent deploys:**
```r
setwd("path/to/shiny-app")
rsconnect::deployApp(appName = "aast-lms")
```

**Environment variables on shinyapps.io:**
shinyapps.io does not have environment variable support on the free tier. Use a `config.yml` file instead (gitignored) and load it with the `config` package:

```r
# shiny-app/config.yml (gitignored)
default:
  fastapi_base: "https://aast-lms-api.up.railway.app"

# shiny-app/global.R
library(config)
cfg          <- config::get()
FASTAPI_BASE <- cfg$fastapi_base
```

---

### 15.3 React Native → Expo (S4)

**Development (physical device):**
```bash
cd react-native-app

# Set production API URL in .env
echo "EXPO_PUBLIC_API_URL=https://aast-lms-api.up.railway.app" > .env
echo "EXPO_PUBLIC_WS_URL=wss://aast-lms-api.up.railway.app"   >> .env

# Start Expo
npx expo start

# Scan QR code with Expo Go on Android/iOS
# App is now connected to production backend
```

**Production APK build (EAS Build — free):**
```bash
# 1. Login to Expo
eas login

# 2. Configure EAS build
eas build:configure
# Creates eas.json in project root

# 3. Build Android APK (free tier)
eas build --platform android --profile preview
# Takes ~10–15 minutes
# Download link provided in terminal and expo.dev dashboard

# 4. Install APK on device
# Download APK → transfer to Android device → install
# (Enable "Install from unknown sources" in Android settings)

# 5. For iOS (requires Apple Developer account — not free)
# eas build --platform ios
```

**`eas.json` configuration:**
```json
{
  "build": {
    "preview": {
      "android": {
        "buildType": "apk"
      }
    },
    "production": {
      "android": {
        "buildType": "app-bundle"
      }
    }
  }
}
```

---

### 15.4 GitHub Actions CI/CD (S3 — Phase 4)

File: `.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Railway CLI
        run: npm install -g @railway/cli
      - name: Deploy FastAPI to Railway
        run: railway up --service python-api
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}

  notify:
    needs: deploy-api
    runs-on: ubuntu-latest
    steps:
      - name: Deployment complete
        run: echo "FastAPI deployed to Railway successfully"
```

**Set up GitHub secrets:**
1. Go to `4awmy/Classroom-Emotion-System` → Settings → Secrets → Actions
2. Add `RAILWAY_TOKEN`: get from railway.app → Account Settings → Tokens

---

### 15.5 Deployment URLs Summary

| Service | URL | Who sets it up |
|---|---|---|
| FastAPI (Railway) | `https://aast-lms-api.up.railway.app` | S3 |
| R/Shiny (shinyapps.io) | `https://[username].shinyapps.io/aast-lms/` | S2 |
| React Native (Expo Go) | Scan QR code | S4 |
| React Native (APK) | Downloaded from EAS Build | S4 |

---

## 16. Granular Work Breakdown Structure — 16 Weeks, 4 Phases

### Critical Path Rules

1. **Week 1: Data Contract.** No feature code until all 4 approve the SQLite schema PR.
2. **End of Week 2: S3 mock endpoints live on Railway.** S2 and S4 start building against these — they must never wait on S1's AI models.
3. **S1's real models are not required until Phase 2.** Phase 1 uses mocks and synthetic data only.
4. **All work via PRs against `dev`.** Never commit directly to `main`. S3 (Backend Lead) is the PR gatekeeper.

---

### Phase 1 — Foundation (Weeks 1–3)
**Milestone: All shells deployed. All mock routes live. S2 and S4 unblocked.**

#### S3 — Backend Lead (Week 1 is highest priority)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P1-S3-01 | Data Contract | `data-schema/README.md` with all 9 SQLite schemas + 6 CSV export schemas + JWT payload | All 4 members approve PR |
| P1-S3-02 | SQLite + ORM | `database.py` + `models.py` with all ORM models | `create_all()` succeeds, all 9 tables created |
| P1-S3-03 | FastAPI skeleton | `main.py` with 7 routers, CORS, `/health` | `curl /health` returns 200 on Railway |
| P1-S3-04 | All mock endpoints | Every route returns hardcoded valid JSON | All routes in Postman collection pass |
| P1-S3-05 | JWT auth stub | `POST /auth/login` returns signed JWT | Token verified by S2 (httr2) and S4 (fetch) |
| P1-S3-06 | WebSocket skeleton | `/session/ws` + `POST /session/start` broadcasts mock event | S4 confirms receipt in console |
| P1-S3-07 | `.env.example` files | All env var keys documented (empty values) | Both `.env.example` files committed |

#### S1 — AI Vision Lead (Week 1–3)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P1-S1-01 | Python environment | All packages in `requirements.txt` installed | `python -c "import ultralytics, face_recognition, hsemotion_onnx, openai"` succeeds |
| P1-S1-02 | Camera connectivity | Script opens RTSP stream, saves frame | `test_frame.jpg` created without error |
| P1-S1-03 | Vision pipeline stub | `vision_pipeline.py` with correct structure, no models | File imports cleanly, placeholder functions defined |
| P1-S1-04 | Synthetic data seeder | `notebooks/generate_synthetic_data.py` inserts 1000+ rows into all tables | S2 can run `compute_engagement()` against it |
| P1-S1-05 | YOLO test | Script runs YOLO on sample classroom photo | Bounding boxes drawn on output image |

#### S2 — R/Shiny UI Lead (Week 1–3, uses mock endpoints from S3)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P1-S2-01 | Audit AAST templates | `shiny-app/www/slot-map.md` — which HTML slots exist for injection | Slot map reviewed and committed |
| P1-S2-02 | Shiny shell | `app.R` + `global.R` wired, `htmlTemplate()` injection working | App loads in browser showing AAST chrome |
| P1-S2-03 | Admin UI shell | `admin_ui.R` — 8 empty tab panels, navigation works | All 8 tabs clickable |
| P1-S2-04 | Lecturer UI shell | `lecturer_ui.R` — 5 submodule tabs: Roster, Materials, Attendance, Live, Reports | All 5 tabs render |
| P1-S2-05 | httr2 connection | R script GETs `/health` from Railway mock | Prints `{"status":"ok"}` |
| P1-S2-06 | Synthetic data test | `compute_engagement()` runs against seeded CSV | Returns valid data frame, no errors |
| P1-S2-07 | Analytics module stub | S2 writes `compute_engagement` skeleton and validates it runs against synthetic CSV | Returns valid data frame, no errors |

#### S4 — Mobile Lead (Week 1–3, uses mock WS from S3)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P1-S4-01 | Expo scaffold | `react-native-app/` with Expo Router, NativeWind, Zustand, socket.io-client | `npx expo start` launches without errors |
| P1-S4-02 | Auth screen | `login.tsx` calls `POST /auth/login`, stores JWT | Login works against mock endpoint |
| P1-S4-03 | Home screen stub | `home.tsx` renders after login | Screen shows placeholder lecture cards |
| P1-S4-04 | WebSocket client | `api.ts` connects to mock WS, logs events | `session:start` appears in console |
| P1-S4-05 | AppState stub | `focus.tsx` logs AppState changes | Background/foreground transitions logged |

---

### Phase 2 — Core Features (Weeks 4–8)
**Milestone: Real data flowing. All 8 admin panels functional. Roster ingestion working.**

#### S1 (Weeks 4–6)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P2-S1-01 | YOLO person detection | Detects persons in live classroom frame | Bounding boxes shown on test image |
| P2-S1-02 | face_recognition ID match | Crop ROI → encoding → SQLite match | Correct student_id returned |
| P2-S1-03 | HSEmotion integration | Full 3-step pipeline, fixed confidence lookup | Educational state + confidence written to SQLite |
| P2-S1-04 | 5-second loop | `run_pipeline()` loops continuously | `emotion_log` grows during 1-min test run |
| P2-S1-05 | Roster encoding | `roster.py` processes ZIP, writes BLOBs | 10 test images → 10 encodings in DB |
| P2-S1-06 | Auto attendance | First detection per lecture → INSERT attendance_log | `attendance_log` populated after test |
| P2-S1-07 | Whisper integration | Captures mic, transcribes via Whisper API | Arabic + English phrases transcribed correctly |

#### S2 (Weeks 4–8)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P2-S2-01 | `engagement_score.R` | `compute_engagement()` returns by_lecture + by_student | Unit test passes against synthetic data |
| P2-S2-02 | `clustering.R` | `cluster_lecturers()` + `cluster_student_subject()` with K-means (k=3) | 3 clusters with correct labels |
| P2-S2-03 | Admin Panel 1 | Attendance DT + filters + xlsx export | Filter and download work |
| P2-S2-04 | Admin Panel 2 | Engagement trend plotly line | Chart renders |
| P2-S2-05 | Admin Panel 3 | Dept heatmap ggplot2 | Heatmap renders |
| P2-S2-06 | Admin Panel 4 | At-risk cohort DT + Flag button | Button calls API |
| P2-S2-07 | Admin Panel 5 | LES table + conditional formatting | Top 10% green, bottom 10% red |
| P2-S2-08 | Admin Panel 6 | Emotion distribution stacked bar (6 states) | Normalized bars render |
| P2-S2-09 | Admin Panel 7 | Lecturer cluster scatter | Cluster map renders |
| P2-S2-10 | Admin Panel 8 | Time-of-day heatmap | Heatmap renders |
| P2-S2-11 | Lecturer: Roster | File inputs + httr2 POST /roster/upload | Upload succeeds, count shown |
| P2-S2-12 | Lecturer: Materials | fileInput + httr2 POST /upload/material | Upload succeeds, list refreshes |
| P2-S2-13 | Lecturer: Attendance | Manual DT + AI mode + QR | All 3 modes work |

#### S3 (Weeks 4–8)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P2-S3-01 | Real emotion endpoints | `POST /emotion/frame` writes; `GET /emotion/live` reads | Vision pipeline and Shiny both work |
| P2-S3-02 | Attendance endpoints | `POST /attendance/start`, `/manual`, `GET /qr/{id}` | All 3 functional |
| P2-S3-03 | Roster endpoint | `POST /roster/upload` parses CSV + ZIP | Encodings saved to DB |
| P2-S3-04 | Materials + Drive | `POST /upload/material` → Drive → materials table | Drive link in DB |
| P2-S3-05 | Session WS (real) | `POST /session/start` → DB row + broadcast + threads | S4 and Shiny receive events |
| P2-S3-06 | Nightly export | APScheduler at 02:00 → CSVs written | Manual `export_all()` produces correct CSVs |
| P2-S3-07 | Notify endpoint | `POST /notify/lecturer` → notifications table | Returns 200, row in DB |

#### S4 (Weeks 4–8)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P2-S4-01 | Home screen (real) | Fetches `GET /session/upcoming`, renders cards | Real lectures displayed |
| P2-S4-02 | AppState focus mode | Background → WS strike → FastAPI logs to focus_strikes | Strike appears in SQLite |
| P2-S4-03 | CaptionBar | WS caption events → RTL overlay → auto-clears 4s | Arabic + English display correctly |
| P2-S4-04 | Strike counter | FocusOverlay shows count, warns at 3 | Counter increments on each strike |

---

### Phase 3 — AI + Live Systems (Weeks 9–12)
**Milestone: Gemini live. Confusion alert working. Smart Notes delivered to students.**

#### S1 (Weeks 9–10)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P3-S1-01 | Gemini smart notes | `generate_smart_notes()` → markdown with ✱ | Test transcript → correct output |
| P3-S1-02 | Gemini fresh-brainer | `generate_fresh_brainer()` → 1–2 sentence question | Question generated from test slide |
| P3-S1-03 | Gemini intervention | `generate_intervention_plan()` → 3-item list | Valid plan for test history |
| P3-S1-04 | Nightly plan job | APScheduler writes `data/plans/{student_id}.md` | Plans appear after manual trigger |

#### S2 (Weeks 9–12)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P3-S2-01 | D1–D7 live dashboard | All 7 panels built, reactiveTimer(10000) | Gauge + all charts update every 10s |
| P3-S2-02 | Confusion observer | confusion_rate ≥ 0.40 → shinyalert with question | Alert fires with test data |
| P3-S2-03 | Student report cards | selectInput → engagement + cognitive load + plan | Plan rendered from API |
| P3-S2-04 | PDF export | `rmarkdown::render()` → PDF download | PDF with all 6 sections downloads |

#### S3 (Weeks 9–11)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P3-S3-01 | `/gemini/question` | Fetches slide text → Gemini → returns question | Shiny receives question string |
| P3-S3-02 | `/notes/{sid}/{lid}` | Reads transcripts → smart notes → returns markdown | Markdown correct |
| P3-S3-03 | `/notes/{sid}/plan` | Reads latest plan .md → returns content | Plan markdown returned |
| P3-S3-04 | Confusion rate endpoint | `GET /emotion/confusion-rate?lecture_id=&window=120` | Returns float 0.0–1.0 |
| P3-S3-05 | Strike WS handler | WS `strike` event → INSERT focus_strikes | Strike in DB |

#### S4 (Weeks 9–12)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P3-S4-01 | Smart Notes viewer | Fetches after session ends, ✱ sections highlighted | Notes display with highlight |
| P3-S4-02 | Fresh-brainer overlay | WS `freshbrainer` → bottom-sheet | Overlay appears on trigger |
| P3-S4-03 | Notes export | `Share.share()` native share | Export works on device |

---

### Phase 4 — Exam + Polish (Weeks 13–16)
**Milestone: Full demo ready. Exam proctoring working. CI/CD live.**

#### S1 (Weeks 13–14)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P4-S1-01 | YOLO phone detection | `proctor_service.py` detects phones on desks | Test image → `phone_on_desk` in incidents |
| P4-S1-02 | Head posture | MediaPipe FaceMesh → extreme rotation flagged | Rotated face → `head_rotation` in incidents |
| P4-S1-03 | Auto-submit trigger | 3 × Severity-3 in 10 min → `POST /exam/submit` | Fires in integration test |
| P4-S1-04 | Evidence screenshot | Each incident saves frame to `data/evidence/` | Screenshot file present |

#### S2 (Weeks 13–16)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P4-S2-01 | Exam incident panel | DT from `incidents.csv`, severity colors, xlsx export | Incidents display correctly |
| P4-S2-02 | AAST UI polish | All panels reviewed against templates, consistent branding | Design review sign-off |
| P4-S2-03 | student_report.Rmd | AAST header/footer, all 6 sections, clean PDF | PDF passes visual review |

#### S3 (Weeks 13–15)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P4-S3-01 | Exam API | `POST /exam/start`, `/exam/submit`, `GET /exam/incidents/{id}` | All 3 functional |
| P4-S3-02 | Notify (full) | `POST /notify/lecturer` → notifications table + WS broadcast | Notification in Shiny without reload |
| P4-S3-03 | GitHub Actions CI/CD | `deploy.yml` → Railway auto-deploy on push to main | Pipeline passes |

#### S4 (Weeks 13–15)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| P4-S4-01 | Exam screen | `app/(exam)/exam.tsx` → `POST /exam/start` on mount, AppState strike | Exam starts, background triggers incident |
| P4-S4-02 | Auto-submit handling | WS `exam:autosubmit` → navigates to submitted screen | Screen transitions correctly |

#### Team Integration (Weeks 15–16)

| ID | Task | Deliverable | Done when |
|---|---|---|---|
| INT-01 | End-to-end test | Full flow: Roster → Start lecture → Vision → Captions → Shiny live → Confusion alert → Smart Notes | All steps pass in 15-minute test session |
| INT-02 | Full demo dry run | 10-minute simulated lecture, all 4 members present | No critical bugs, all features demonstrated |
| INT-03 | Final README | Clone-to-run guide for all 3 services | Reviewed and merged to main |

---

## 17. Key Constraints — Claude Code Must Respect These Always

1. **One classroom camera only** — never suggest student webcams or mobile cameras for emotion detection
2. **Vision pipeline: YOLO → face_recognition → HSEmotion, 1 frame/5s** — sequential, rate-limited, no exceptions
3. **R/Shiny is for Admin and Lecturer ONLY** — never build student features in Shiny
4. **React Native is for Students ONLY** — never build admin or lecturer features in React
5. **Live data goes to SQLite** — never write live lecture data directly to CSV files
6. **R/Shiny reads nightly CSV exports ONLY** — never connect R/Shiny directly to SQLite
7. **Nightly export at 02:00** — APScheduler in `export_service.py`, not a manual script
8. **Whisper for audio** — lecturer code-switches ar-EG/en; no Google Cloud Speech
9. **Engagement confidence values are locked** — Focused=1.00, Engaged=0.85, Confused=0.55, Anxious=0.35, Frustrated=0.25, Disengaged=0.00 — fixed switch-case, never from model softmax
10. **AppState API for mobile focus mode** — no OS-level device locks
11. **Camera-based exam proctoring only** — no JS browser lockdowns; YOLO + MediaPipe
12. **R/Shiny injects into pre-existing AAST templates** — do not rebuild HTML/CSS chrome
13. **S2 writes all R analytics directly** — follow the formulas in Section 8 exactly for engagement and K-means
14. **SQLite column names locked after Week 1** — never rename any column
15. **S3 mock endpoints live by end of Week 2** — S2 and S4 must never be blocked on AI models
16. **All tooling free or low-cost** — Railway/shinyapps.io/Expo free tiers + Gemini 1.5 Flash + Whisper pay-per-use
