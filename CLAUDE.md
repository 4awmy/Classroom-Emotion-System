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
9. [Audio Pipeline — RETIRED](#9-audio-pipeline--retired)
10. [Roster Ingestion Pipeline](#10-roster-ingestion-pipeline)
11. [State Case Scenarios](#11-state-case-scenarios)
12. [Module Specifications](#12-module-specifications)
13. [FastAPI Backend](#13-fastapi-backend)
14. [Step-by-Step Development Guide](#14-step-by-step-development-guide)
15. [Deployment Guide](#15-deployment-guide)
16. [Work Breakdown Structure](#16-work-breakdown-structure)
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
    student_id    TEXT PRIMARY KEY,        -- e.g. 231006367 (9-digit AAST student number)
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
            # Atomic write: write to temp file then os.replace to avoid partial-read
            import os, tempfile
            tmp = f"{EXPORT_DIR}/{name}.tmp.csv"
            df.to_csv(tmp, index=False, encoding="utf-8-sig")  # utf-8-sig for Arabic names
            os.replace(tmp, f"{EXPORT_DIR}/{name}.csv")
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
┌────────────────────────┐
│  Stage 1 — yolov8n.pt  │  Detect all persons in crowd frame
│  Person Detection      │  Output: list of [x1,y1,x2,y2] boxes
└──────────┬─────────────┘
           │  For each person box → person_roi
           ▼
┌──────────────────────────────────────────────────────────┐
│  Task A — Identity / Attendance                          │
│  face_recognition.face_encodings(person_roi)             │
│  → 128-dim encoding → compare SQLite encodings          │
│  → student_id (distance ≤ 0.5) or skip                  │
│  → INSERT attendance_log on first detection              │
│  → save snapshot (person_roi, for lecturer review)       │
└──────────┬───────────────────────────────────────────────┘
           │  For each identified student:
           ▼
┌──────────────────────────────────────────────────────────┐
│  Task B — Emotion with tight face crop                   │
│  Stage 2 — yolov8n-face.pt run on person_roi            │
│  → face_roi = tight face bounding box                    │
│  → HSEmotion (enet_b0_8_best_afew) on face_roi          │
│  → raw_label + softmax scores (AffectNet-trained input)  │
└──────────┬───────────────────────────────────────────────┘
           │
           ▼
  map_emotion() → educational state
  get_confidence() → fixed score (§8.2)
  INSERT emotion_log (raw_emotion, raw_confidence, emotion, engagement_score)
```

**Why Approach B (two-stage):** HSEmotion was trained on AffectNet face-only images. Passing a full-body person ROI is an out-of-domain input that degrades accuracy. `yolov8n-face.pt` provides a tight face crop before classification. Identity matching still uses the full person ROI (face_recognition handles it correctly).

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

See `python-api/services/vision_pipeline.py` for the authoritative implementation.

Key design points:
- `yolo_person = YOLO("yolov8n.pt")` — person bounding boxes from full crowd frame
- `yolo_face = YOLO("yolov8n-face.pt")` — tight face crop from each person ROI
- `_ensure_yolo_face()` auto-downloads `yolov8n-face.pt` at startup if absent
- **Task A** (identity): `face_recognition.face_encodings(person_roi)` → SQLite match → `student_id`
- **Task B** (emotion): `yolo_face(person_roi)` → `face_roi` → `HSEmotionRecognizer.predict_emotions(face_roi)`
- Attendance logged on first detection per session; snapshot saved as person ROI
- Emotion and engagement_score always written per 5-second cycle per identified student

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

## 9. Audio Pipeline — RETIRED

> **Audio transcription and live captions have been removed from scope.**
> `whisper_service.py`, the `transcripts` table, `transcripts.csv` export, and `CaptionBar.tsx` are all deleted.
> The `GET /notes/{student_id}/{lecture_id}` endpoint returns a placeholder until an alternative note source is defined.

---

## 10. Roster Ingestion Pipeline

### 10.1 Overview

Before any lecture, the lecturer uploads the student roster so the vision pipeline can identify faces. This is a one-time per-course operation performed from the Shiny Lecturer panel.

**Real dataset format:** `StudentPicsDataset.xlsx` — 127 students, 9-digit IDs (e.g. `231006367`), Arabic names, and Google Drive photo links (`https://drive.google.com/open?id=FILE_ID`). There is no ZIP file of images — photos are downloaded from Drive at ingestion time.

### 10.2 Data Flow

```
Lecturer in Shiny → Submodule A (Roster Setup)
    │  uploads: StudentPicsDataset.xlsx (or derived XLSX/CSV)
    ▼
httr2 multipart POST /roster/upload
    │
    ▼
FastAPI roster.py:
    │  1. Parse XLSX → extract student_id (9-digit), name, email, photo_link columns
    │  2. INSERT into students (student_id, name, email) — skip if already exists
    │  3. For each student with a Drive photo link:
    │     a. Extract file_id from URL: url.split("id=")[1]
    │     b. Download: https://drive.google.com/uc?export=download&id={file_id}
    │     c. face_recognition.face_encodings(image) → 128-dim numpy array
    │     d. encoding.tobytes() → store as BLOB in students.face_encoding
    │  4. Return {students_created: N, encodings_saved: M}
    ▼
SQLite students table ready — vision pipeline can now identify this cohort
```

### 10.3 Implementation

File: `python-api/routers/roster.py`

```python
import face_recognition, numpy as np, io, requests
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Student
import openpyxl

router = APIRouter()

MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB guard

def download_drive_image(photo_link: str) -> np.ndarray | None:
    """Download a photo from a Google Drive share link and return as numpy array."""
    try:
        file_id = photo_link.split("id=")[1].split("&")[0]
        download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
        resp = requests.get(download_url, timeout=15)
        resp.raise_for_status()
        return face_recognition.load_image_file(io.BytesIO(resp.content))
    except Exception:
        return None

@router.post("/upload")
async def upload_roster(
    roster_xlsx: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # Guard against oversized uploads
    content = await roster_xlsx.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="File too large (max 10 MB)")

    # 1. Parse XLSX — expects columns: student_id, name, email, photo_link
    wb = openpyxl.load_workbook(io.BytesIO(content))
    ws = wb.active
    headers = [str(cell.value).strip() for cell in ws[1]]

    students_created = 0
    encodings_saved = 0

    for row in ws.iter_rows(min_row=2, values_only=True):
        data = dict(zip(headers, row))
        student_id = str(data.get("student_id", "")).strip()
        name       = str(data.get("name", "")).strip()
        email      = str(data.get("email", "")).strip() or None
        photo_link = str(data.get("photo_link", "")).strip()

        if not student_id or not name:
            continue

        # 2. Insert student if not already present
        if not db.query(Student).filter_by(student_id=student_id).first():
            db.add(Student(student_id=student_id, name=name, email=email))
            students_created += 1
            db.commit()

        # 3. Download photo and encode face
        if photo_link and "drive.google.com" in photo_link:
            img_array = download_drive_image(photo_link)
            if img_array is not None:
                encs = face_recognition.face_encodings(img_array)
                if encs:
                    db.query(Student).filter_by(student_id=student_id).update(
                        {"face_encoding": encs[0].astype(np.float64).tobytes()}
                    )
                    encodings_saved += 1
                    db.commit()

    return {"students_created": students_created, "encodings_saved": encodings_saved}
```

**Add `openpyxl` and `requests` to `requirements.txt`** (both are pure-Python, no build deps).

---

## 11. State Case Scenarios — Chronological Data Flows

### State 1: Roster Initialization

```
Step 1  Lecturer opens Shiny → Roster Setup tab
Step 2  Uploads StudentPicsDataset.xlsx (columns: student_id, name, email, photo_link)
          student_id = 9-digit AAST number (e.g. 231006367)
          photo_link = Google Drive share URL per student
Step 3  Shiny: httr2 multipart POST /roster/upload (single XLSX file)
Step 4  FastAPI:
          a. Parses XLSX → INSERT Student rows into SQLite
          b. For each student: extract Drive file_id from photo_link
          c. Download image via https://drive.google.com/uc?export=download&id={file_id}
          d. face_recognition.face_encodings() → 128-dim numpy array
          e. Serializes array → BLOB → stores in students.face_encoding
Step 5  FastAPI returns {students_created: N, encodings_saved: M}
Step 6  Shiny shows success notification
Step 7  Next lecture start → load_student_encodings() picks up new encodings
```

### State 2: Live Lecture Loop

```
Step 1  Lecturer clicks "Start Lecture" in Shiny
          httr2 POST /session/start {lecture_id, lecturer_id, slide_url}
Step 2  FastAPI session.py:
          a. INSERT into lectures table
          b. Broadcasts WS: {type: "session:start", slideUrl, lectureId}
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
Step 4  React Native student app:
          a. AppState listener: app goes background → WS emit strike
             {type: "focus_strike", student_id, lecture_id, strike_type: "app_background"}
             (exam context: add context: "exam" → routes to incidents table instead)
          b. FastAPI → INSERT focus_strikes
Step 5  Shiny live dashboard (reactiveTimer every 10s):
          a. GET /emotion/live?lecture_id= → last 60 emotion_log rows
          b. D1: engagement gauge updated
          c. D2–D7: all panels refreshed
Step 6  Confusion spike check (Shiny observer, every 10s):
          a. confusion_rate = mean(emotion == "Confused") over last 120 rows
          b. If ≥ 0.40 → triggers State 3
Step 7  Lecturer clicks "End Lecture"
          POST /session/end → updates lectures.end_time
          Broadcasts {type: "session:end"}
          Background threads stopped gracefully via threading.Event stop flag
Step 8  Nightly 02:00: APScheduler → export_all() → CSV files written
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
          FastAPI broadcasts WS: {type: "freshbrainer", question: "..."}
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
- `fileInput("roster_xlsx", accept = c(".xlsx"))` — accepts `StudentPicsDataset.xlsx` directly
- Progress bar during upload (Drive downloads are slow — show spinner)
- `httr2 POST /roster/upload` (multipart, single XLSX file)
- Success notification shows `students_created` and `encodings_saved` counts
- Note: Drive photo download happens server-side; no ZIP file needed

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
      socket.emit('focus_strike', {
        type: 'focus_strike',
        student_id: studentId,
        lecture_id: activeLectureId,
        strike_type: 'app_background',
        // context: 'exam'  ← add this field during exam sessions to route to incidents table
      });
      setStrikes(s => s + 1);
    }
  });
  return () => sub.remove();
}, [focusActive]);
```
- No OS-level locks — AppState API only
- Receives `{type: "session:start"}` → shows slide URL + locks focus
- Receives `{type: "session:end"}` → releases focus
- Receives `{type: "freshbrainer"}` → renders bottom-sheet question

**CaptionBar** (`components/CaptionBar.tsx`)
- WS event `{type: "caption"}` → display text overlay, auto-clear after 4s
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
from routers import auth  # real JWT auth router
from services.export_service import scheduler
from database import engine
from sqlalchemy import text
import models

models.Base.metadata.create_all(bind=engine)

# Enable WAL mode for concurrent reads (vision pipeline thread + API)
with engine.connect() as conn:
    conn.execute(text("PRAGMA journal_mode=WAL"))

app = FastAPI(title="AAST LMS API")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                  allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router,        prefix="/auth")
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
openpyxl                # XLSX parsing for roster upload
requests                # Drive photo download in roster.py
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
        {"student_id": "231006367", "emotion": "Focused", "confidence": 1.0, "engagement_score": 1.0},
        {"student_id": "231006368", "emotion": "Confused", "confidence": 0.55, "engagement_score": 0.55},
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
- `POST /roster/upload` (XLSX file) → `{"students_created": 127, "encodings_saved": 127}`
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
  student_id = "231006367",
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

curl https://railway-url/notes/231006367/L1

curl https://railway-url/notes/231006367/plan
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

## 16. Work Breakdown Structure

> **Single source of truth for tasks: [`TASKS.md`](./TASKS.md)**
> Do not duplicate task status here. All task tracking, assignees, and status columns live in `TASKS.md` only.

### Critical Path Rules

1. **Week 1: Data Contract.** No feature code until all 4 approve the SQLite schema PR.
2. **End of Week 2: S3 mock endpoints live on DigitalOcean.** S2 and S4 start building against these — they must never wait on S1's AI models.
3. **S1's real models are not required until Phase 3.** Phase 2 uses mocks and synthetic data only.
4. **All work via PRs against `dev`.** Never commit directly to `main`. S3 (Backend Lead) is the PR gatekeeper.

---

## 17. Key Constraints — Claude Code Must Respect These Always

1. **One classroom camera only** — never suggest student webcams or mobile cameras for emotion detection
2. **Vision pipeline: YOLO → face_recognition → HSEmotion, 1 frame/5s** — sequential, rate-limited, no exceptions
3. **R/Shiny is for Admin and Lecturer ONLY** — never build student features in Shiny
4. **React Native is for Students ONLY** — never build admin or lecturer features in React
5. **Live data goes to SQLite** — never write live lecture data directly to CSV files
6. **R/Shiny reads nightly CSV exports ONLY** — never connect R/Shiny directly to SQLite
7. **Nightly export at 02:00** — APScheduler in `export_service.py`, not a manual script
8. **Engagement confidence values are locked** — Focused=1.00, Engaged=0.85, Confused=0.55, Anxious=0.35, Frustrated=0.25, Disengaged=0.00 — fixed switch-case, never from model softmax
9. **AppState API for mobile focus mode** — no OS-level device locks
10. **Camera-based exam proctoring only** — no JS browser lockdowns; YOLO + MediaPipe
11. **R/Shiny injects into pre-existing AAST templates** — do not rebuild HTML/CSS chrome
12. **S2 writes all R analytics directly** — follow the formulas in Section 8 exactly for engagement and K-means
13. **SQLite column names locked after Week 1** — never rename any column
14. **S3 mock endpoints live by end of Week 2** — S2 and S4 must never be blocked on AI models
15. **All tooling free or low-cost** — shinyapps.io/Expo free tiers + Gemini 1.5 Flash

<!-- SPECKIT START -->
This file (CLAUDE.md) is the single source of truth for architecture, constraints, and specs.
Task tracking lives in: TASKS.md
Technical contracts live in: ARCHITECTURE.md
<!-- SPECKIT END -->
