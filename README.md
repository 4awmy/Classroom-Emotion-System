<div align="center">

# Classroom Emotion System

### AI-Powered LMS & Real-Time Classroom Analytics Platform

**Arab Academy for Science, Technology & Maritime Transport (AAST)**

![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?style=flat&logo=fastapi&logoColor=white)
![R](https://img.shields.io/badge/R-4.3+-276DC3?style=flat&logo=r&logoColor=white)
![React Native](https://img.shields.io/badge/React_Native-Expo-20232A?style=flat&logo=react&logoColor=61DAFB)
![SQLite](https://img.shields.io/badge/SQLite-WAL_Mode-003B57?style=flat&logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/License-Academic-C9A84C?style=flat)

*A single classroom camera. Real-time emotion detection. AI-driven interventions.*

</div>

---

## Table of Contents

1. [What It Does](#1-what-it-does)
2. [System Architecture](#2-system-architecture)
3. [Vision Pipeline](#3-vision-pipeline)
4. [Engagement Model](#4-engagement-model)
5. [Database Schema](#5-database-schema)
6. [API Reference](#6-api-reference)
7. [WebSocket Protocol](#7-websocket-protocol)
8. [Admin & Lecturer Dashboard](#8-admin--lecturer-dashboard)
9. [Student Mobile App](#9-student-mobile-app)
10. [Exam Proctoring](#10-exam-proctoring)
11. [AI Features](#11-ai-features)
12. [Project Structure](#12-project-structure)
13. [Getting Started](#13-getting-started)
14. [Configuration](#14-configuration)
15. [Deployment](#15-deployment)
16. [Development Workflow](#16-development-workflow)
17. [Team & Responsibilities](#17-team--responsibilities)

---

## 1. What It Does

The Classroom Emotion System turns any standard classroom into an intelligent learning environment. A **single fixed camera** watches the student crowd, identifies each person by face, detects their emotional state, and streams that information in real time to:

- **Lecturers** — who see a live engagement dashboard and get AI-suggested questions when the class is confused
- **Admins** — who see cross-course analytics, at-risk student flags, and lecturer effectiveness scores
- **Students** — who receive live captions in Arabic/English, a focus mode with distraction tracking, and AI-generated personalized study notes

No student webcams. No invasive software. One camera, server-side AI, zero student setup friction.

---

## 2. System Architecture

### Interface Split

| Audience | Interface | Technology | Access |
|---|---|---|---|
| **Admin** | Web portal | R + Shiny | Browser |
| **Lecturer** | Web portal | R + Shiny | Browser |
| **Student** | Mobile app | React Native (Expo) | Android / iOS |
| All | Backend API | Python + FastAPI | HTTP / WebSocket |

> **This split is non-negotiable.** R/Shiny is for Admin and Lecturer only. React Native is for Students only.

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    LIVE LECTURE  (runtime)                      │
│                                                                 │
│   Classroom Camera                                              │
│        │                                                        │
│        ▼                                                        │
│   Vision Pipeline  ──────────────────────────────────────────┐ │
│   (1 frame / 5s)                                             │ │
│        │                                                     │ │
│        ▼                                                     ▼ │
│   FastAPI Backend ◄──── HTTP / WebSocket ───► R/Shiny      │ │
│        │                                       Dashboard    │ │
│        ▼                                                     │ │
│   SQLite DB (WAL)                                            │ │
│        │                                 React Native App ◄─┘ │
│        │                                 (WebSocket live feed) │
└────────│────────────────────────────────────────────────────────┘
         │
         │  APScheduler — every night at 02:00
         ▼
┌────────────────────────────────────────────────────────────────┐
│                  ANALYTICS LAYER  (read-only)                  │
│                                                                │
│   data/exports/  ←── export_service.py writes atomic CSVs    │
│        │                                                       │
│        └──── R/Shiny reads these CSVs (never touches SQLite)  │
└────────────────────────────────────────────────────────────────┘
```

### Why Two Layers?

Writing live emotion data directly to CSV causes file-lock conflicts when R/Shiny reads simultaneously. SQLite with WAL mode handles concurrent access safely. R/Shiny never touches the live database — it only reads the nightly static exports.

### Component Overview

```
python-api/          FastAPI backend — shared by both frontends
shiny-app/           R/Shiny portal — Admin & Lecturer ONLY
react-native-app/    Expo app — Students ONLY
data-schema/         SQLite schemas (locked after Week 1)
notebooks/           Synthetic data seeder
docs/                Academic project specification
```

---

## 3. Vision Pipeline

### How It Works

One frame is captured from the classroom camera every 5 seconds and passed through three sequential AI models:

```
Camera frame (every 5 seconds)
         │
         ▼
┌──────────────────┐
│   YOLOv8n        │  Detect all persons in the crowd frame
│   Person Detect  │  → list of bounding boxes [x1, y1, x2, y2]
└────────┬─────────┘
         │  For each bounding box:
         ▼
┌──────────────────┐
│  face_recognition│  Crop face ROI → compute 128-dim encoding
│  Identity Match  │  → compare against enrolled student encodings
└────────┬─────────┘  → student_id  (skip if "unknown")
         │  For each identified student:
         ▼
┌──────────────────┐
│  HSEmotion ONNX  │  Analyze emotion on cropped face ROI
│  enet_b0_8_best  │  → raw_label + softmax probability scores
└────────┬─────────┘
         │
         ▼
   map_emotion()          → educational state (6 categories)
   get_engagement_weight() → fixed score (see Section 4)
         │
         ▼
   INSERT emotion_log     (raw_emotion, raw_confidence, emotion, engagement_score)
   INSERT attendance_log  (first detection per session → method = "AI")
```

### Camera Source

| Mode | Configuration | Use case |
|---|---|---|
| Local webcam | `CLASSROOM_CAMERA_URL=0` (default) | Development, demo |
| IP camera (RTSP) | `CLASSROOM_CAMERA_URL=rtsp://192.168.x.x/stream` | Classroom deployment |
| Video file | `CLASSROOM_CAMERA_URL=/path/to/video.mp4` | Testing |

The pipeline converts the env var to an integer automatically when a webcam index is detected.

### Emotion Mapping

HSEmotion outputs 7 basic emotions. These are mapped to 6 educationally meaningful states:

| HSEmotion raw output | Condition | Educational State | Engagement Weight |
|---|---|---|---|
| `neutral` | — | **Focused** | 1.00 |
| `happy`, `surprise` | — | **Engaged** | 0.85 |
| `anger`, `disgust` | softmax < 0.65 | **Confused** | 0.55 |
| `anger`, `disgust` | softmax ≥ 0.65 | **Frustrated** | 0.25 |
| `fear` | — | **Anxious** | 0.35 |
| `sad` | — | **Disengaged** | 0.00 |

> **Important distinction:** Two confidence values are stored per reading:
> - `raw_confidence` — the actual HSEmotion softmax score (research use)
> - `confidence` / `engagement_score` — the fixed weight per educational state (analytics use)
>
> The engagement analytics use the fixed weights exclusively — not the model's softmax output. This makes the engagement score academically defensible and reproducible.

### RTSP Reconnection

The pipeline handles camera drops gracefully:
- Retries up to 5 times with 10-second backoff
- Stops cleanly when `POST /session/end` sets the `stop_event` threading flag

---

## 4. Engagement Model

### Fixed Engagement Weights

| State | Weight | Level | Action |
|---|---|---|---|
| Focused | **1.00** | High | No action |
| Engaged | **0.85** | High | No action |
| Confused | **0.55** | Moderate | Monitor |
| Anxious | **0.35** | Low | Flag to lecturer |
| Frustrated | **0.25** | Low | Flag to lecturer |
| Disengaged | **0.00** | Critical | Intervention alert |

**Thresholds:**

| Level | Score range | Action |
|---|---|---|
| High | ≥ 0.75 | — |
| Moderate | 0.45–0.74 | Monitor |
| Low | 0.25–0.44 | Flag |
| Critical | < 0.25 | Alert |

### Derived Class Metrics (computed in R)

```
engagement_score  = mean(fixed_weight) over all readings in window

cognitive_load    = confusion_rate + frustration_rate
                    > 0.50 → lecture pace too fast

class_valence     = (focused_rate + engaged_rate)
                    − (frustrated_rate + disengaged_rate + anxiety_rate)
                    positive = healthy classroom | negative = needs intervention

LES (Lecture      = 0.5 × avg_engagement
 Effectiveness      + 0.3 × (1 − confusion_rate)
 Score)             + 0.2 × attendance_rate
```

---

## 5. Database Schema

All data lives in a single SQLite file (`python-api/data/classroom_emotions.db`) with WAL mode enabled.

### Tables

#### `students`
```sql
student_id    TEXT PRIMARY KEY    -- 9-digit AAST number (e.g. 231006367)
name          TEXT NOT NULL
email         TEXT
face_encoding BLOB                -- 128-dim float64 numpy array as bytes
enrolled_at   DATETIME
```

#### `lectures`
```sql
lecture_id   TEXT PRIMARY KEY     -- e.g. "L1"
lecturer_id  TEXT NOT NULL
title        TEXT
subject      TEXT
start_time   DATETIME
end_time     DATETIME
slide_url    TEXT
```

#### `emotion_log`
```sql
id               INTEGER PK AUTOINCREMENT
student_id       TEXT → students
lecture_id       TEXT → lectures
timestamp        DATETIME
raw_emotion      TEXT              -- HSEmotion raw output (neutral, happy, ...)
raw_confidence   REAL              -- actual model softmax score
emotion          TEXT              -- mapped educational state
confidence       REAL              -- fixed engagement weight
engagement_score REAL              -- equals confidence
```

#### `attendance_log`
```sql
id            INTEGER PK AUTOINCREMENT
student_id    TEXT → students
lecture_id    TEXT → lectures
timestamp     DATETIME
status        TEXT              -- "Present" | "Absent"
method        TEXT              -- "AI" | "Manual" | "QR"
snapshot_path TEXT              -- optional face snapshot (AI attendance)
```

#### `materials`
```sql
material_id  TEXT PRIMARY KEY
lecture_id   TEXT → lectures
lecturer_id  TEXT
title        TEXT
drive_link   TEXT
uploaded_at  DATETIME
```

#### `incidents` (exam proctoring)
```sql
id            INTEGER PK AUTOINCREMENT
student_id    TEXT → students
exam_id       TEXT
timestamp     DATETIME
flag_type     TEXT              -- phone_on_desk | head_rotation | absent | ...
severity      INTEGER           -- 1 low | 2 medium | 3 high
evidence_path TEXT              -- screenshot in data/evidence/
```

#### `transcripts`
```sql
id          INTEGER PK AUTOINCREMENT
lecture_id  TEXT → lectures
timestamp   DATETIME
chunk_text  TEXT                -- Whisper output for 5s audio chunk
language    TEXT                -- "ar" | "en" | "mixed"
```

#### `notifications`
```sql
id          INTEGER PK AUTOINCREMENT
student_id  TEXT → students
lecturer_id TEXT
lecture_id  TEXT → lectures
reason      TEXT
created_at  DATETIME
read        INTEGER             -- 0 = unread | 1 = read
```

#### `focus_strikes`
```sql
id          INTEGER PK AUTOINCREMENT
student_id  TEXT → students
lecture_id  TEXT → lectures
timestamp   DATETIME
strike_type TEXT                -- "app_background"
```

### Nightly CSV Exports

R/Shiny reads only these files — column names are locked:

| File | Columns |
|---|---|
| `emotions.csv` | student_id, lecture_id, timestamp, raw_emotion, raw_confidence, emotion, confidence, engagement_score |
| `attendance.csv` | student_id, lecture_id, timestamp, status, method |
| `materials.csv` | material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at |
| `incidents.csv` | student_id, exam_id, timestamp, flag_type, severity, evidence_path |
| `transcripts.csv` | lecture_id, timestamp, chunk_text, language |
| `notifications.csv` | student_id, lecturer_id, lecture_id, reason, created_at, read |

---

## 6. API Reference

Base URL: `https://your-api.ondigitalocean.app` (production) or `http://localhost:8000` (local)

### Authentication

```
POST /auth/login
Body: { "student_id": "231006367", "password": "..." }
Response: { "token": "<jwt>", "role": "student" }
```

JWT payload: `{ student_id, role, exp }` — include as `Authorization: Bearer <token>` on protected routes.

### Health

```
GET  /health
Response: { "status": "ok" }
```

### Session

```
POST /session/start
Body: { "lecture_id": "L1", "lecturer_id": "...", "slide_url": "..." }
→ Creates lecture row, starts vision pipeline thread, starts Whisper coroutine
→ Broadcasts: { "type": "session:start", "lectureId": "L1", "slideUrl": "..." }

POST /session/end
Body: { "lecture_id": "L1" }
→ Sets stop_event, updates lectures.end_time
→ Broadcasts: { "type": "session:end" }

POST /session/broadcast
Body: { "type": "freshbrainer", "question": "..." }
→ Broadcasts any payload to all connected WebSocket clients

GET  /session/upcoming
Response: [ { "lecture_id", "title", "subject", "start_time" }, ... ]
```

### Emotion

```
GET  /emotion/live?lecture_id=L1&limit=60
Response: [ { student_id, emotion, engagement_score, timestamp }, ... ]

GET  /emotion/confusion-rate?lecture_id=L1&window=120
Response: { "confusion_rate": 0.42 }

POST /emotion/frame
Body: { "lecture_id": "L1", "student_id": "231006367", "emotion": "Confused", ... }
```

### Attendance

```
POST /attendance/start      Body: { lecture_id }     → begins AI attendance
POST /attendance/manual     Body: { lecture_id, records: [...] }
GET  /attendance/qr/{lecture_id}   → returns QR code image
```

### Roster

```
POST /roster/upload
Multipart: roster_xlsx (StudentPicsDataset.xlsx)
→ Parses XLSX, downloads Google Drive photos, encodes faces, stores BLOBs
Response: { "students_created": 127, "encodings_saved": 127 }
```

### AI / Gemini

```
POST /gemini/question
Body: { "lecture_id": "L1" }
→ Fetches slide text → Gemini → one clarifying question
Response: { "question": "Can you clarify what Big O notation means for nested loops?" }

GET  /notes/{student_id}/{lecture_id}
→ Generates smart notes from transcript with ✱ markers at distraction timestamps
Response: markdown string

GET  /notes/{student_id}/plan
→ Returns AI intervention plan (.md file)
Response: markdown string
```

### Upload

```
POST /upload/material
Multipart: file, lecture_id, title
→ Uploads to Google Drive, saves link in materials table
```

### Exam

```
POST /exam/start     Body: { exam_id, student_id }
POST /exam/submit    Body: { exam_id, student_id, reason }
GET  /exam/incidents/{exam_id}   → list of logged incidents
```

### Notifications

```
POST /notify/lecturer
Body: { "student_id": "231006367", "lecture_id": "L1", "reason": "Disengaged for 10+ minutes" }
→ Creates notification row + broadcasts via WebSocket
Response: { "status": "notified", "notification_id": 42 }

GET  /notify/{student_id}
Response: [ { id, reason, created_at, lecturer_id, lecture_id }, ... ]
```

---

## 7. WebSocket Protocol

Connect to: `ws://localhost:8000/session/ws`

All messages are JSON.

### Server → Clients (broadcast)

| `type` | Payload fields | Description |
|---|---|---|
| `session:start` | `lectureId`, `slideUrl` | Lecture started — students enter focus mode |
| `session:end` | `lectureId` | Lecture ended — release focus lock |
| `caption` | `text`, `lecture_id`, `language`, `timestamp` | Whisper transcript chunk (every ~5s) |
| `freshbrainer` | `question` | Gemini-generated clarifying question |
| `notification` | `student_id`, `lecture_id`, `reason`, `timestamp` | Student flagged |

### Client → Server

| `type` | Payload fields | Description |
|---|---|---|
| `focus_strike` | `student_id`, `lecture_id`, `strike_type`, `context?` | App went to background; set `context: "exam"` to route to incidents table |

---

## 8. Admin & Lecturer Dashboard

### Admin — 8 Analytics Panels

| # | Panel | Visualization | Key Logic |
|---|---|---|---|
| 1 | Attendance Overview | DT table | Per-course attendance %; filters by dept + date; XLSX export |
| 2 | Engagement Trend | Plotly line | x=week, y=avg engagement score, colored by department |
| 3 | Dept Engagement Heatmap | ggplot2 tile | x=week, y=dept, fill=avg engagement |
| 4 | At-Risk Cohort | DT table | >20% drop over 3 consecutive lectures; "Flag" button → POST /notify/lecturer |
| 5 | Lecture Effectiveness (LES) | DT table | Top 10% = green, bottom 10% = red |
| 6 | Emotion Distribution | Stacked bar | Normalized per dept, all 6 states |
| 7 | Lecturer Cluster Map | Plotly scatter | K-means k=3: High Performer / Consistent / Needs Support |
| 8 | Time-of-Day Heatmap | ggplot2 tile | x=weekday, y=08:00–20:00 slots, fill=avg engagement |

All panels use `reactivePoll` to check CSV file modification time every 60 seconds. Data only refreshes when the nightly export writes new files.

### Lecturer — 5 Submodules

**A — Roster Setup**
Upload `StudentPicsDataset.xlsx` (student_id, name, email, photo_link columns). The server downloads each Google Drive photo, computes a 128-dim face encoding, and stores it as a BLOB. Face identification starts immediately on the next lecture.

**B — Material Upload**
Upload lecture slides → stored in Google Drive → link saved in `materials` table → visible in the materials list below.

**C — Attendance**
Three modes: AI (camera-based, auto), Manual (editable DT table), QR fallback (rendered QR code students scan).

**D — Live Lecture Dashboard (7 panels)**

| Panel | What it shows |
|---|---|
| D1 Engagement Gauge | Mean engagement score of last 60 readings; red < 0.25 / amber / green |
| D2 Emotion Timeline | % of class in each state over the last 30 min (2-min buckets) |
| D3 Cognitive Load | confusion_rate + frustration_rate; red > 0.50 → "Overloaded — slow down" |
| D4 Class Valence Meter | −1.0 to +1.0 horizontal gauge; alert if < 0 for 5+ consecutive readings |
| D5 Per-Student Heatmap | ggplot2 tile — student × time segment, colored by dominant emotion |
| D6 Persistent Struggle Alerts | Students Confused/Frustrated for ≥ 3 consecutive readings |
| D7 Peak Confusion Detector | 2-minute window with highest cognitive load — shown post-lecture |

**Confusion Auto-Alert:** A Shiny observer checks every 10 seconds. When `confusion_rate ≥ 0.40` over the last 120 readings, it calls `POST /gemini/question`, and shows a `shinyalert` popup with the suggested question. The lecturer can click "Ask It" to broadcast it to all student devices.

**E — Student Reports**
Per-student card showing engagement trend, cognitive load timeline, dominant emotion, valence history, and AI intervention plan. PDF export via `rmarkdown::render()`.

---

## 9. Student Mobile App

### Screens

| Screen | Route | Description |
|---|---|---|
| Login | `/(auth)/login` | JWT auth with student_id + password |
| Home | `/(student)/home` | Upcoming lectures; last session engagement summary |
| Focus Mode | `/(student)/focus` | AppState monitor; strike counter; live session feed |
| Smart Notes | `/(student)/notes` | AI notes with ✱ highlights; native share export |

### Focus Mode

When a lecture is active, the student enters Focus Mode. The app uses React Native's `AppState` API to detect when the student switches away:

```
Student opens another app
  → AppState changes to "background"
  → WS message: { type: "focus_strike", student_id, lecture_id, strike_type: "app_background" }
  → Server: INSERT focus_strikes
  → FocusOverlay: increment strike counter

3 strikes reached
  → FocusOverlay turns red
  → Warning: "Lecturer has been notified"
  → Server: POST /notify/lecturer
```

No OS-level locks or device restrictions. AppState API only.

### Live Captions (CaptionBar)

- Listens for `{ type: "caption" }` WebSocket events
- Displays text in a bottom overlay with AAST navy background + gold left border
- Auto-clears after 4 seconds with fade animation
- Arabic text detected via Unicode range `\u0600–\u06FF` → right-aligned (RTL)

### Smart Notes

After a lecture ends, the student requests their notes from `GET /notes/{student_id}/{lecture_id}`. The backend pulls the lecture transcript and the student's distraction timestamps (from `focus_strikes`), sends both to Gemini, and returns markdown notes where content taught during distraction moments is re-explained and marked with `✱`.

---

## 10. Exam Proctoring

Fully camera-based. No browser lockdowns. No device restrictions.

### Detection Methods

| Flag | Detection method | Tool | Severity |
|---|---|---|---|
| `phone_on_desk` | COCO class 67 in YOLO output | YOLOv8n | 3 (high) |
| `absent` | No face detected for > 5 seconds | face_recognition | 3 (high) |
| `multiple_persons` | YOLO person count > 1 | YOLOv8n | 3 (high) |
| `head_rotation` | Extreme yaw/pitch via landmark geometry | MediaPipe FaceMesh | 2 (medium) |
| `identity_mismatch` | Detected face ≠ enrolled student encoding | face_recognition | 3 (high) |
| `app_background` | App state change during exam | React Native AppState | 1 (low) |

### Auto-Submit Rule

A background polling loop checks every 60 seconds:

```
IF count(severity=3 incidents in last 10 minutes) >= 3
  → POST /exam/submit  { exam_id, student_id, reason: "auto" }
  → Server broadcasts: { type: "exam:autosubmit" }
  → React Native: navigate to "Exam Submitted" screen
```

All incidents are saved with a screenshot path in `data/evidence/`.

---

## 11. AI Features

### Gemini 1.5 Flash — Three Functions

**1. Fresh-Brainer (confusion intervention)**
Triggered when `confusion_rate ≥ 0.40`. Receives the current lecture's slide text (extracted via pdfplumber). Returns one clarifying question in under two sentences.

**2. Smart Notes**
Receives the full lecture transcript + list of timestamps when the student was distracted. Returns clean markdown notes where distracted sections are re-explained with a `✱` marker.

**3. Intervention Plan**
Receives a student's emotion history across lectures. Returns a numbered markdown list of exactly 3 actionable steps for the lecturer.

### OpenAI Whisper

Every 5 seconds, a 5-second audio chunk from the classroom microphone is sent to Whisper. No language is declared — Whisper auto-detects Arabic/English code-switching (common in Egyptian university lectures). The transcript is saved to the `transcripts` table and broadcast to all connected students as a `caption` WebSocket event.

---

## 12. Project Structure

```
Classroom-Emotion-System/
│
├── CLAUDE.md                          ← Architecture decisions (single source of truth)
├── CONTRIBUTING.md                    ← Git workflow, branch rules, PR process
├── app.yaml                           ← DigitalOcean App Platform deployment spec
├── docker-compose.yml                 ← Local multi-service orchestration
│
├── python-api/                        ← FastAPI backend
│   ├── main.py                        ← App entry point, router registration
│   ├── database.py                    ← SQLite engine + session factory (WAL mode)
│   ├── models.py                      ← SQLAlchemy ORM (9 tables)
│   ├── schemas.py                     ← Pydantic request/response models
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── .env.example
│   ├── routers/
│   │   ├── auth.py                    ← JWT login
│   │   ├── emotion.py                 ← Vision results + live feed endpoints
│   │   ├── attendance.py              ← Attendance CRUD (AI / Manual / QR)
│   │   ├── session.py                 ← WebSocket manager + lecture lifecycle
│   │   ├── gemini.py                  ← AI question generation endpoint
│   │   ├── notes.py                   ← Smart notes + intervention plan
│   │   ├── exam.py                    ← Exam start/submit/incidents
│   │   ├── roster.py                  ← Student enrollment + face encoding
│   │   ├── upload.py                  ← Lecture material → Google Drive
│   │   └── notify.py                  ← Lecturer notifications
│   ├── services/
│   │   ├── vision_pipeline.py         ← YOLO → face_rec → HSEmotion loop
│   │   ├── whisper_service.py         ← Mic capture → Whisper → WS broadcast
│   │   ├── gemini_service.py          ← Three Gemini prompt functions
│   │   ├── proctor_service.py         ← Exam phone + head posture detection
│   │   ├── export_service.py          ← Nightly CSV export (APScheduler 02:00)
│   │   └── websocket.py               ← Connection manager (broadcast / send)
│   ├── scripts/
│   │   └── seed_mock_data.py          ← Seeds 1050–1350 rows for testing
│   └── data/
│       ├── classroom_emotions.db      ← SQLite live DB (gitignored)
│       ├── exports/                   ← Nightly CSV exports
│       ├── plans/                     ← Per-student AI intervention .md files
│       └── evidence/                  ← Exam incident screenshots
│
├── shiny-app/                         ← R/Shiny portal (Admin + Lecturer ONLY)
│   ├── app.R                          ← Entry point
│   ├── global.R                       ← Libraries + FASTAPI_BASE_URL
│   ├── ui/
│   │   ├── admin_ui.R                 ← 8 admin panels
│   │   └── lecturer_ui.R              ← 5 submodules
│   ├── server/
│   │   ├── admin_server.R             ← Panel logic + at-risk flagging
│   │   └── lecturer_server.R          ← Live dashboard + confusion observer
│   ├── modules/
│   │   ├── engagement_score.R         ← compute_engagement() — core metric
│   │   ├── clustering.R               ← K-means (lecturer + student clusters)
│   │   └── attendance.R               ← Attendance helpers
│   ├── www/
│   │   └── custom.css                 ← AAST branding (navy #002147 / gold #C9A84C)
│   └── reports/
│       └── student_report.Rmd         ← Per-student PDF (6 sections)
│
├── react-native-app/                  ← Expo student app (Students ONLY)
│   ├── app/
│   │   ├── (auth)/login.tsx
│   │   └── (student)/
│   │       ├── home.tsx
│   │       ├── focus.tsx              ← AppState + strikes + WS events
│   │       └── notes.tsx              ← Smart Notes markdown viewer
│   ├── components/
│   │   ├── CaptionBar.tsx             ← RTL-aware live caption overlay
│   │   ├── FocusOverlay.tsx           ← Strike counter UI (amber → red)
│   │   └── NotesViewer.tsx            ← Markdown renderer with ✱ highlight style
│   ├── store/
│   │   └── useStore.ts                ← Zustand global state
│   └── services/
│       └── api.ts                     ← HTTP + WebSocket clients
│
├── data-schema/
│   └── README.md                      ← Full SQL schema + CSV schemas (locked)
│
├── notebooks/
│   └── generate_synthetic_data.py     ← Legacy seeder
│
└── docs/
    └── Project.md                     ← Full academic specification (source of truth)
```

---

## 13. Getting Started

### Prerequisites

| Tool | Version | Required by |
|---|---|---|
| Python | 3.11 (exact) | python-api |
| R | 4.3+ | shiny-app |
| Node.js | 18 LTS | react-native-app |
| uv | latest | python-api (preferred) |
| Expo Go | latest | react-native-app (device testing) |

> Python 3.11 is required exactly — `face_recognition` (dlib) has build issues on 3.12+.

### 1. Clone

```bash
git clone https://github.com/4awmy/Classroom-Emotion-System.git
cd Classroom-Emotion-System
```

### 2. Backend (FastAPI)

```bash
cd python-api

# Create and activate virtual environment
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # macOS / Linux

# Install dependencies
pip install -r requirements.txt

# If face_recognition fails on Windows (dlib build error):
pip install cmake dlib face-recognition

# Set up environment
cp .env.example .env
# Edit .env and fill in your API keys (see Section 14)

# Create data directories
mkdir -p data/exports data/plans data/evidence

# Initialize database (creates all 9 tables)
python -c "from database import engine; import models; models.Base.metadata.create_all(bind=engine)"

# Seed with test data (1050–1350 rows)
python scripts/seed_mock_data.py

# Start the development server
uvicorn main:app --reload --port 8000
```

Verify at `http://localhost:8000/health` → `{"status": "ok"}`
API docs at `http://localhost:8000/docs`

### 3. R/Shiny App

Open RStudio and run:

```r
# Install packages (once)
install.packages(c(
  "shiny", "shinydashboard", "shinyalert", "shinyjs",
  "DT", "plotly", "ggplot2", "dplyr", "lubridate",
  "httr2", "openxlsx", "rmarkdown", "rsconnect"
))

# Edit global.R to point to your local FastAPI:
# FASTAPI_BASE <- "http://localhost:8000"

# Run the app
setwd("shiny-app")
shiny::runApp()
```

### 4. React Native App

```bash
cd react-native-app
npm install
cp .env.example .env
# Edit .env: set EXPO_PUBLIC_API_URL and EXPO_PUBLIC_WS_URL

npx expo start
# Press 'a' for Android emulator, 'i' for iOS simulator
# Scan QR code with Expo Go on a physical device
```

---

## 14. Configuration

### python-api/.env

```bash
# AI APIs
GEMINI_API_KEY=             # Google AI Studio → gemini-1.5-flash
OPENAI_API_KEY=             # OpenAI platform → Whisper only

# Google Drive (for roster photo downloads + material uploads)
GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json

# Auth
JWT_SECRET=                 # Any long random string

# Database
DATABASE_URL=sqlite:///./data/classroom_emotions.db

# Camera — omit or set to 0 for default webcam
CLASSROOM_CAMERA_URL=0      # 0 = webcam | rtsp://... = IP camera
```

### react-native-app/.env

```bash
EXPO_PUBLIC_API_URL=http://localhost:8000      # or production URL
EXPO_PUBLIC_WS_URL=ws://localhost:8000         # or wss:// in production
```

### shiny-app/global.R

```r
FASTAPI_BASE <- "http://localhost:8000"        # local dev
# FASTAPI_BASE <- "https://your-api.ondigitalocean.app"  # production
```

---

## 15. Deployment

### FastAPI → DigitalOcean App Platform

The repo includes a ready `app.yaml` at the root:

```bash
# Install doctl
# https://docs.digitalocean.com/reference/doctl/how-to/install/

# Authenticate
doctl auth init

# Create app from spec
doctl apps create --spec app.yaml

# Or use the DigitalOcean web dashboard:
# App Platform → Create App → GitHub → 4awmy/Classroom-Emotion-System
```

Set these environment variables in the App Platform dashboard:
- `GEMINI_API_KEY`
- `OPENAI_API_KEY`
- `JWT_SECRET`
- `CLASSROOM_CAMERA_URL` (RTSP URL for deployed classroom camera)

### R/Shiny → shinyapps.io

```r
library(rsconnect)

# Authenticate (tokens from shinyapps.io → Account → Tokens)
rsconnect::setAccountInfo(name="your-username", token="...", secret="...")

# Update FASTAPI_BASE in global.R to the production URL, then:
setwd("shiny-app")
rsconnect::deployApp(appName = "aast-lms")
```

### React Native → EAS Build (Android APK)

```bash
eas login
eas build:configure
eas build --platform android --profile preview
# Download link provided — install APK on device
```

---

## 16. Development Workflow

### Branch Strategy

```
main       ← stable releases only (protected)
dev        ← integration branch — all PRs target here
feature/*  ← individual feature branches
```

**Never commit directly to `main` or `dev`.** All work goes through PRs.

### PR Process

1. Branch from `dev`: `git checkout -b feature/your-feature dev`
2. Commit your changes with clear messages
3. Open PR targeting `dev`
4. Get review from at least one team member
5. S3 (Backend Lead) is the PR gatekeeper

### Commit Message Format

```
type: short description

Types: feat | fix | docs | refactor | test | chore
Examples:
  feat: add confusion observer to lecturer live dashboard
  fix: convert camera URL string to int for webcam index
  docs: update API reference with /notify endpoints
```

### Running Tests

```bash
# Backend
cd python-api
pytest tests/ -v

# Verify all model imports (vision pipeline)
python -c "import ultralytics, face_recognition, hsemotion_onnx, openai; print('All OK')"

# Verify DB schema
python -c "
from database import engine; import models
models.Base.metadata.create_all(bind=engine)
print('All tables created')
"

# Test nightly export manually
python -c "from services.export_service import export_all; export_all(); print('Export done')"
```

---

## 17. Team & Responsibilities

| Member | Role | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---|---|---|---|---|
| **S1** | AI Vision Lead | Vision environment setup, synthetic data | Full YOLO→HSEmotion pipeline, roster encoding, Whisper | Gemini service functions | Exam proctoring (phone + head) |
| **S2** | R/Shiny UI Lead | Shiny shell, AAST template injection | All 8 admin panels, engagement module, clustering | Live dashboard (D1–D7), confusion observer, student reports | Exam incident panel, PDF polish |
| **S3** | Backend Lead | Data contract, all mock endpoints, Railway deploy | Real DB endpoints, WebSocket, nightly export, auth | AI endpoints (/gemini, /notes) | Exam API, CI/CD, notify endpoint |
| **S4** | Mobile Lead | Expo scaffold, auth screen, WebSocket stub | AppState focus mode, CaptionBar, FocusOverlay, home screen | Smart Notes viewer, freshbrainer overlay | Exam screen, auto-submit handling |

### Key Delivery Milestones

| Milestone | When | What |
|---|---|---|
| Data Contract | End Week 1 | All 4 members approve schema PR — no feature code before this |
| Mock API Live | End Week 2 | All mock endpoints on Railway — S2 and S4 start building |
| Core Features | End Week 8 | Real data flowing, all 8 admin panels, roster working |
| AI Live | End Week 12 | Gemini + Whisper + live dashboard functional |
| Demo Ready | End Week 16 | End-to-end integration test passes |

---

<div align="center">

Built at **Arab Academy for Science, Technology & Maritime Transport (AAST)**

*Capstone Project — AI-Powered Learning Management System*

</div>
