# Classroom Emotion System
> AI-Powered LMS & Classroom Analytics Platform — AAST Capstone Project

An intelligent Learning Management System that uses computer vision, emotion recognition, and AI to monitor student engagement in real time during lectures at **Arab Academy for Science, Technology & Maritime Transport (AAST)**.

---

## Overview

A single classroom camera captures the entire student crowd. A sequential vision pipeline identifies each student, detects their emotional state, and streams results into SQLite in real time. An R/Shiny web portal provides Admin and Lecturer dashboards. A React Native mobile app gives students focus mode, live captions, and AI-generated smart notes.

```
Camera → YOLOv8 (detect persons)
       → face_recognition (identify students)
       → HSEmotion ONNX (detect emotion)
       → SQLite (live writes, WAL mode)
       → CSV exports at 02:00 nightly
       → R/Shiny dashboards (read CSV only)
       → React Native app (WebSocket live events)
```

---

## Interface Split

| Audience   | Interface        | Technology          |
|------------|------------------|---------------------|
| Admin      | Web portal       | R + Shiny           |
| Lecturer   | Web portal       | R + Shiny           |
| Student    | Mobile app       | React Native (Expo) |
| All        | Backend API      | Python + FastAPI    |
| Live data  | Runtime DB       | SQLite (WAL mode)   |
| Analytics  | Static exports   | CSV (nightly cron)  |

---

## Architecture

### Two-Layer Data Strategy

```
LIVE LECTURE (runtime)
  Camera → Vision Pipeline → FastAPI → SQLite DB
  (concurrent-safe, fast writes, WAL mode)
        ↓
  APScheduler at 02:00 nightly
        ↓
ANALYTICS LAYER (read-only)
  export_service.py → CSV files in data/exports/
  R/Shiny reads these static CSVs — never touches live DB
```

### WebSocket Events

| Event type       | Direction          | Description                                 |
|------------------|--------------------|---------------------------------------------|
| `session:start`  | Server → clients   | Lecture started, includes slideUrl          |
| `session:end`    | Server → clients   | Lecture ended, release focus lock           |
| `caption`        | Server → students  | Whisper transcript chunk (RTL-aware)        |
| `freshbrainer`   | Server → students  | Gemini-generated clarifying question        |
| `notification`   | Server → lecturer  | Student flagged as at-risk                  |
| `focus_strike`   | Student → server   | App went to background during focus mode    |

---

## Tech Stack

| Layer             | Technology                        | Notes                                         |
|-------------------|-----------------------------------|-----------------------------------------------|
| Vision detection  | YOLOv8n (Ultralytics)             | Person bounding boxes, phone detection        |
| Face ID           | face_recognition (dlib)           | 128-dim encodings stored as BLOB in SQLite    |
| Emotion model     | HSEmotion ONNX (`enet_b0_8_best_afew`) | AffectNet-trained, ~75–80% real-world accuracy |
| Head posture      | MediaPipe FaceMesh                | Exam proctoring head rotation detection       |
| Audio             | OpenAI Whisper (`whisper-1`)      | Handles Arabic/English code-switching         |
| AI generation     | Gemini 1.5 Flash                  | Smart notes, fresh-brainer, intervention plan |
| Backend           | FastAPI + SQLAlchemy              | SQLite (WAL), PostgreSQL-ready                |
| Scheduler         | APScheduler                       | Nightly CSV export at 02:00                   |
| Admin/Lecturer UI | R + Shiny + shinydashboard        | Reads nightly CSV exports only                |
| Student app       | React Native + Expo               | AppState focus mode, WebSocket captions       |
| Auth              | JWT (python-jose)                 | Role-based: admin / lecturer / student        |
| Deployment        | DigitalOcean App Platform         | `app.yaml` in repo root                       |

---

## Vision Pipeline

Processing runs **1 frame every 5 seconds** — sequential, rate-limited:

```
Frame (every 5s)
  → YOLOv8   : detect all persons → bounding boxes
  → face_rec : crop ROI → 128-dim encoding → match student_id
  → HSEmotion: analyze emotion → raw_label + softmax score
  → map_emotion() → educational state
  → get_engagement_weight() → fixed score
  → INSERT emotion_log (raw_emotion, raw_confidence, emotion, engagement_score)
  → INSERT attendance_log (first detection per session → method=AI)
```

### Emotion Mapping

| HSEmotion output    | Educational state | Fixed engagement weight |
|---------------------|-------------------|-------------------------|
| `neutral`           | Focused           | **1.00**                |
| `happy`, `surprise` | Engaged           | **0.85**                |
| `anger`, `disgust` (< 0.65) | Confused | **0.55**            |
| `anger`, `disgust` (≥ 0.65) | Frustrated | **0.25**           |
| `fear`              | Anxious           | **0.35**                |
| `sad`               | Disengaged        | **0.00**                |

> `engagement_score` = fixed weight per state (not raw model softmax). Raw model confidence is also stored separately as `raw_confidence` for research use.

### Engagement Levels

| Level    | Score range | Action                  |
|----------|-------------|-------------------------|
| High     | ≥ 0.75      | No action               |
| Moderate | 0.45–0.74   | Monitor                 |
| Low      | 0.25–0.44   | Flag to lecturer        |
| Critical | < 0.25      | Intervention alert      |

### Camera Source

- **Default:** Local webcam (index 0) — works out of the box for demos
- **Override:** Set `CLASSROOM_CAMERA_URL` env var to an RTSP stream URL for deployment with an IP camera

---

## Database Schema

All tables in SQLite (`data/classroom_emotions.db`, WAL mode):

| Table             | Key columns                                                    |
|-------------------|----------------------------------------------------------------|
| `students`        | student_id (9-digit), name, email, face_encoding (BLOB)        |
| `lectures`        | lecture_id, lecturer_id, title, subject, start_time, end_time  |
| `emotion_log`     | student_id, lecture_id, raw_emotion, raw_confidence, emotion, confidence, engagement_score |
| `attendance_log`  | student_id, lecture_id, status (Present/Absent), method (AI/Manual/QR), snapshot_path |
| `materials`       | material_id, lecture_id, title, drive_link                     |
| `incidents`       | student_id, exam_id, flag_type, severity (1–3), evidence_path  |
| `transcripts`     | lecture_id, chunk_text, language (ar/en/mixed)                 |
| `notifications`   | student_id, lecturer_id, lecture_id, reason, read (0/1)        |
| `focus_strikes`   | student_id, lecture_id, strike_type (app_background)           |

---

## Features

### Admin Dashboard (R/Shiny — 8 panels)
1. **Attendance Overview** — DT table with filters, XLSX export
2. **Engagement Trend** — Plotly line chart by department/week
3. **Dept Engagement Heatmap** — ggplot2 tile by week × department
4. **At-Risk Cohort** — >20% engagement drop over 3 lectures → Flag button → POST /notify/lecturer
5. **Lecture Effectiveness Score (LES)** — 0.5×engagement + 0.3×(1−confusion) + 0.2×attendance; top/bottom 10% highlighted
6. **Emotion Distribution** — Normalized stacked bar per department (all 6 states)
7. **Lecturer Cluster Map** — K-means (k=3) scatter: High/Consistent/Needs Support
8. **Time-of-Day Heatmap** — weekday × time slot, fill = avg engagement

### Lecturer Dashboard (R/Shiny — 5 submodules)
- **Roster Setup** — Upload StudentPicsDataset.xlsx → downloads Google Drive photos → encodes faces → stores as BLOB
- **Material Upload** — Upload lecture slides → Google Drive → materials table
- **Attendance** — Manual DT editing, AI-assisted mode, QR fallback
- **Live Lecture (7 panels)** — Engagement gauge, emotion timeline, cognitive load, class valence, per-student heatmap, persistent struggle alerts, peak confusion detector
- **Student Reports** — Per-student engagement cards + AI intervention plan + PDF export (R Markdown)

### Student App (React Native)
- **Login** — JWT auth, stores token in Zustand
- **Home** — Upcoming lectures, engagement summary from last session
- **Focus Mode** — AppState monitoring, strike counter (max 3), receives session events via WebSocket
- **Live Captions** — RTL-aware caption bar, auto-clears after 4s, Arabic Unicode detection
- **Smart Notes** — AI-generated notes with ✱ highlights for distraction moments, native share export

### Exam Proctoring (Camera-Based)

| Detection           | Tool                | Flag type            | Severity |
|---------------------|---------------------|----------------------|----------|
| Phone on desk       | YOLOv8 class 67     | `phone_on_desk`      | 3        |
| No face > 5s        | face_recognition    | `absent`             | 3        |
| Multiple persons    | YOLO person count   | `multiple_persons`   | 3        |
| Head rotation       | MediaPipe FaceMesh  | `head_rotation`      | 2        |
| Identity mismatch   | face_recognition    | `identity_mismatch`  | 3        |
| App background      | React Native AppState | `app_background`   | 1        |

**Auto-submit:** 3 × Severity-3 incidents within any 10-minute window triggers automatic submission.

---

## Project Structure

```
/
├── CLAUDE.md                    ← Single source of truth for all architecture decisions
├── app.yaml                     ← DigitalOcean App Platform deployment config
├── python-api/
│   ├── main.py                  ← FastAPI app, router registration
│   ├── database.py              ← SQLite engine + session factory
│   ├── models.py                ← SQLAlchemy ORM models (9 tables)
│   ├── schemas.py               ← Pydantic request/response models
│   ├── routers/
│   │   ├── auth.py              ← JWT login
│   │   ├── emotion.py           ← Vision results + live feed
│   │   ├── attendance.py        ← Attendance CRUD
│   │   ├── session.py           ← WebSocket + lecture lifecycle
│   │   ├── gemini.py            ← AI question generation
│   │   ├── notes.py             ← Smart notes endpoints
│   │   ├── exam.py              ← Exam proctoring
│   │   ├── roster.py            ← Student enrollment + face encoding
│   │   ├── upload.py            ← Material uploads → Google Drive
│   │   └── notify.py            ← Lecturer notifications
│   ├── services/
│   │   ├── vision_pipeline.py   ← YOLO → face_rec → HSEmotion (1 frame/5s)
│   │   ├── whisper_service.py   ← Whisper transcription + WS captions
│   │   ├── gemini_service.py    ← Gemini prompts (3 functions)
│   │   ├── proctor_service.py   ← Exam phone + head posture detection
│   │   ├── export_service.py    ← Nightly CSV export (APScheduler 02:00)
│   │   └── websocket.py         ← WebSocket connection manager
│   ├── scripts/
│   │   └── seed_mock_data.py    ← Seeds SQLite with 1000+ rows
│   ├── data/
│   │   ├── classroom_emotions.db  ← SQLite live DB (gitignored)
│   │   └── exports/             ← Nightly CSV exports (read by R/Shiny)
│   ├── Dockerfile
│   └── requirements.txt
│
├── shiny-app/
│   ├── app.R                    ← Entry point
│   ├── global.R                 ← Libraries + FASTAPI_BASE_URL
│   ├── ui/
│   │   ├── admin_ui.R           ← 8 admin panels
│   │   └── lecturer_ui.R        ← 5 lecturer submodules
│   ├── server/
│   │   ├── admin_server.R       ← Admin panel logic
│   │   └── lecturer_server.R    ← Lecturer + confusion observer
│   ├── modules/
│   │   ├── engagement_score.R   ← compute_engagement() — core metric
│   │   ├── clustering.R         ← K-means lecturer + student clusters
│   │   └── attendance.R         ← Attendance helpers
│   ├── www/
│   │   └── custom.css           ← AAST theme (DO NOT OVERWRITE)
│   └── reports/
│       └── student_report.Rmd   ← Per-student PDF template
│
├── react-native-app/
│   ├── app/
│   │   ├── (auth)/login.tsx     ← JWT login screen
│   │   └── (student)/
│   │       ├── home.tsx         ← Upcoming lectures + summary
│   │       ├── focus.tsx        ← AppState monitor + strike sender
│   │       └── notes.tsx        ← Smart Notes markdown viewer
│   ├── components/
│   │   ├── CaptionBar.tsx       ← Live WebSocket caption overlay (T054)
│   │   ├── FocusOverlay.tsx     ← Strike counter + focus lock UI (T055)
│   │   └── NotesViewer.tsx      ← Markdown renderer with ✱ highlights
│   ├── store/useStore.ts        ← Zustand: studentId, strikes, caption, focusActive
│   └── services/api.ts          ← HTTP client + WebSocket client
│
├── data-schema/
│   └── README.md                ← SQLite schemas + CSV export schemas (locked)
│
├── notebooks/
│   └── generate_synthetic_data.py
│
└── docs/
    └── Project.md               ← Full academic project specification
```

---

## Local Development

### Prerequisites

- Python 3.11 (exact — face_recognition has issues on 3.12+)
- R 4.3+ + RStudio
- Node.js 18 LTS
- `uv` (fast Python package manager): `pip install uv`

### Backend (FastAPI)

```bash
cd python-api
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # Mac/Linux
pip install -r requirements.txt
cp .env.example .env          # fill in your API keys
mkdir -p data/exports data/plans data/evidence
uvicorn main:app --reload --port 8000
# API docs: http://localhost:8000/docs
```

Seed the database with test data:
```bash
python scripts/seed_mock_data.py
```

### R/Shiny App

```r
install.packages(c("shiny","shinydashboard","shinyalert","shinyjs","DT",
                   "plotly","ggplot2","dplyr","lubridate","httr2","openxlsx",
                   "rmarkdown","rsconnect"))
setwd("shiny-app")
shiny::runApp()
```

Set `FASTAPI_BASE <- "http://localhost:8000"` in `global.R` for local dev.

### React Native App

```bash
cd react-native-app
npm install
cp .env.example .env          # set EXPO_PUBLIC_API_URL and EXPO_PUBLIC_WS_URL
npx expo start
# Scan QR code with Expo Go, or press 'a' for Android emulator
```

---

## Environment Variables

| Variable                       | Service        | Description                                    |
|--------------------------------|----------------|------------------------------------------------|
| `GEMINI_API_KEY`               | python-api     | Google AI Studio key (Gemini 1.5 Flash)        |
| `OPENAI_API_KEY`               | python-api     | OpenAI key (Whisper only)                      |
| `JWT_SECRET`                   | python-api     | Long random string for JWT signing             |
| `CLASSROOM_CAMERA_URL`         | python-api     | Webcam index (0) or RTSP URL (optional)        |
| `DATABASE_URL`                 | python-api     | `sqlite:///./data/classroom_emotions.db`       |
| `GOOGLE_APPLICATION_CREDENTIALS` | python-api   | Path to Google Drive service account JSON      |
| `EXPO_PUBLIC_API_URL`          | react-native   | FastAPI base URL                               |
| `EXPO_PUBLIC_WS_URL`           | react-native   | WebSocket URL (ws:// or wss://)                |

---

## Deployment

The project deploys to **DigitalOcean App Platform** using `app.yaml` in the repo root.

```bash
# Deploy via DigitalOcean CLI
doctl apps create --spec app.yaml

# Or connect via DigitalOcean dashboard:
# App Platform → Create App → GitHub → 4awmy/Classroom-Emotion-System
```

R/Shiny deploys to **shinyapps.io**:
```r
rsconnect::deployApp(appName = "aast-lms", account = "your-username")
```

React Native builds via **EAS Build**:
```bash
eas build --platform android --profile preview
```

---

## Team

| Member | Role              | Responsibilities                                               |
|--------|-------------------|----------------------------------------------------------------|
| S1     | AI Vision Lead    | Vision pipeline, HSEmotion, Whisper, Gemini services, exam AI |
| S2     | R/Shiny UI Lead   | Admin + Lecturer dashboards, analytics modules, PDF reports   |
| S3     | Backend Lead      | FastAPI, SQLite, WebSocket, auth, CI/CD, deployment           |
| S4     | Mobile Lead       | React Native app, focus mode, captions, smart notes UI        |

---

## Key Constraints

1. One classroom camera only — no student webcams
2. Vision pipeline: YOLO → face_recognition → HSEmotion, 1 frame/5s — sequential, rate-limited
3. R/Shiny for Admin and Lecturer ONLY — never build student features in Shiny
4. React Native for Students ONLY — never build admin/lecturer features in the app
5. Live data goes to SQLite — never write live lecture data directly to CSV
6. R/Shiny reads nightly CSV exports ONLY — never connects to SQLite directly
7. Engagement weights are locked: Focused=1.00, Engaged=0.85, Confused=0.55, Anxious=0.35, Frustrated=0.25, Disengaged=0.00
8. AppState API for mobile focus mode — no OS-level device locks
9. Camera-based exam proctoring only — no JS browser lockdowns
10. Student IDs are 9-digit AAST numbers (e.g. `231006367`)

---

## License

Academic project — Arab Academy for Science, Technology & Maritime Transport (AAST).
