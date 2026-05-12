# AAST Classroom Emotion System — Technical Documentation

**Version:** 4.0 | **Platform:** AAST (Arab Academy for Science, Technology & Maritime Transport)

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Database Schema](#3-database-schema)
4. [Vision Pipeline](#4-vision-pipeline)
5. [Engagement Score Model](#5-engagement-score-model)
6. [FastAPI Backend](#6-fastapi-backend)
7. [R/Shiny Analytics Portal](#7-rshiny-analytics-portal)
8. [AI Features (Gemini)](#8-ai-features-gemini)
9. [Student Mobile App](#9-student-mobile-app)
10. [Exam Proctoring](#10-exam-proctoring)
11. [Data Flows (End-to-End)](#11-data-flows-end-to-end)
12. [Deployment](#12-deployment)

---

## 1. System Overview

The AAST Classroom Emotion System is an AI-powered Learning Management System with real-time classroom analytics. A single high-resolution camera mounted at the front of each classroom feeds a sequential computer vision pipeline that identifies every student in the crowd, classifies their emotional state, and streams the results to the backend in real time.

### Interface Split

| Audience | Interface | Technology | Purpose |
|---|---|---|---|
| **Admin** | Web portal | R + Shiny | Institution-wide analytics, at-risk flagging |
| **Lecturer** | Web portal | R + Shiny | Live dashboard, roster, materials, attendance |
| **Student** | Mobile app | React Native (Expo) | Focus mode, smart notes, live captions |
| All | Backend API | Python FastAPI | Shared data layer and WebSocket hub |
| Runtime | Database | PostgreSQL | Live writes from vision pipeline |

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  DigitalOcean App Platform                      │
│                                                                 │
│  ┌─────────────────────┐     ┌──────────────────────────────┐  │
│  │   FastAPI Backend   │────▶│   Managed PostgreSQL DB      │  │
│  │   (python-api/)     │     │   16 normalized tables       │  │
│  │                     │◀───▶│   +WAL concurrent writes     │  │
│  │  • REST endpoints   │     └──────────────────────────────┘  │
│  │  • WebSocket hub    │                                        │
│  │  • Background tasks │     ┌──────────────────────────────┐  │
│  │  • APScheduler      │────▶│   Nightly CSV Exports        │  │
│  └──────────┬──────────┘     │   data/exports/*.csv         │  │
│             │                └──────────────────────────────┘  │
└─────────────│───────────────────────────────────────────────────┘
              │  HTTP / WebSocket
    ┌─────────┴──────────────────────────────────────┐
    │                                                │
    ▼                                                ▼
┌──────────────────────┐               ┌────────────────────────┐
│  R/Shiny Portal      │               │  React Native App      │
│  (shinyapps.io)      │               │  (Expo / APK)          │
│                      │               │                        │
│  • Admin panels (8)  │               │  • JWT auth            │
│  • Lecturer panels   │               │  • Focus mode          │
│  • Live dashboard    │               │  • Smart notes         │
│  • Student reports   │               │  • WS real-time events │
│                      │               │                        │
│  Reads: PostgreSQL   │               │  Calls: FastAPI REST   │
│  + FastAPI /api/*    │               │  + FastAPI WebSocket   │
└──────────────────────┘               └────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Classroom Edge (vision_pipeline.py)                         │
│                                                              │
│  IP Camera (RTSP) → YOLOv8 Person → YOLOv8 Face             │
│  → face_recognition (identity) → HSEmotion (emotion)        │
│  → HTTP POST /emotion/log  (every 5 seconds per student)    │
└──────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Single classroom camera** — All vision processing is server-side. No student webcams, no per-seat devices.
- **PostgreSQL with WAL** — Concurrent writes from the vision thread and reads from the API are safe. R/Shiny also queries PostgreSQL directly via `RPostgres`.
- **Nightly CSV export** — `APScheduler` exports all tables to `data/exports/*.csv` at 02:00. These CSVs back up historical data and are available for offline analytics.
- **WebSocket hub** — `session.py` maintains a per-lecture connection pool. All real-time events (emotion alerts, slide changes, Gemini questions) are broadcast through it.

---

## 3. Database Schema

The database contains **16 tables** managed by SQLAlchemy ORM (`models.py`). All primary keys are strings (business IDs) except for high-volume log tables which use auto-increment `BigInteger`.

### 3.1 User Tables

#### `admins`
| Column | Type | Notes |
|---|---|---|
| `admin_id` | String PK | e.g. `"admin"` |
| `auth_user_id` | UUID | nullable, legacy Supabase field |
| `name` | String | |
| `email` | String unique | |
| `password_hash` | String | bcrypt |
| `needs_password_reset` | Boolean | default `true` |
| `phone` | String | nullable |
| `created_at` | DateTime TZ | server default |

#### `lecturers`
| Column | Type | Notes |
|---|---|---|
| `lecturer_id` | String PK | |
| `auth_user_id` | UUID | nullable |
| `name` | String | |
| `email` | String unique | |
| `password_hash` | String | bcrypt |
| `department` | String | nullable |
| `title` | String | nullable |
| `photo_url` | String | nullable |
| `created_at` | DateTime TZ | |

Relationships: `classes`, `lectures`, `materials`, `notifications`

#### `students`
| Column | Type | Notes |
|---|---|---|
| `student_id` | String PK | 9-digit AAST ID, e.g. `231006367` |
| `auth_user_id` | UUID | nullable |
| `name` | String | Arabic names supported (UTF-8) |
| `email` | String | nullable |
| `password_hash` | String | bcrypt |
| `department` | String | nullable |
| `year` | Integer | nullable |
| `face_encoding` | LargeBinary | 512-dim float32 ArcFace embedding as BYTEA (written by `roster.py` via InsightFace) |
| `photo_url` | String | Google Drive URL |
| `enrolled_at` | DateTime TZ | |

Relationships: `enrollments`, `emotion_logs`, `attendance_logs`, `incidents`, `notifications`, `focus_strikes`

### 3.2 Course / Class Structure

#### `courses`
| Column | Type | Notes |
|---|---|---|
| `course_id` | String PK | |
| `title` | String | |
| `department` | String | nullable |
| `credit_hours` | Integer | nullable |
| `semester` | String | nullable |
| `year` | Integer | nullable |

#### `classes`
Links a `Course` to a `Lecturer` for a specific semester/section.

| Column | Type | Notes |
|---|---|---|
| `class_id` | String PK | |
| `course_id` | FK → courses | CASCADE delete |
| `lecturer_id` | FK → lecturers | SET NULL on delete |
| `section_name` | String | nullable |
| `room` | String | nullable |
| `semester` | String | nullable |

#### `class_schedule`
Recurring schedule slots per class.

| Column | Type | Notes |
|---|---|---|
| `schedule_id` | String PK | |
| `class_id` | FK → classes | |
| `day_of_week` | String | e.g. `"Sunday"` |
| `start_time` | Time | |
| `end_time` | Time | |

#### `enrollments`
Many-to-many between `students` and `classes`.

| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK autoincrement | |
| `class_id` | FK → classes | |
| `student_id` | FK → students | |
| `enrolled_at` | DateTime TZ | |

### 3.3 Lecture & Session

#### `lectures`
Represents one live classroom session.

| Column | Type | Notes |
|---|---|---|
| `lecture_id` | String PK | e.g. `"L1"` |
| `class_id` | FK → classes | nullable |
| `lecturer_id` | FK → lecturers | |
| `title` | String | nullable |
| `session_type` | String | default `"lecture"` |
| `start_time` | DateTime TZ | set on "Start Lecture" |
| `end_time` | DateTime TZ | set on "End Lecture" |
| `scheduled_start` | DateTime TZ | for early-exit calculation |
| `scheduled_end` | DateTime TZ | |
| `actual_start_time` | DateTime TZ | |
| `actual_end_time` | DateTime TZ | |
| `total_frames_captured` | Integer | default 0 |
| `expected_frames_count` | Integer | default 0 |
| `slide_url` | String | Google Drive PDF link |

#### `exams`
| Column | Type | Notes |
|---|---|---|
| `exam_id` | String PK | |
| `class_id` | FK → classes | |
| `lecture_id` | FK → lectures | nullable |
| `title` | String | |
| `scheduled_start` | DateTime TZ | |
| `end_time` | DateTime TZ | |
| `auto_submit` | Boolean | default `true` — triggers on 3× Sev-3 incidents |

### 3.4 Analytics Tables (High-Volume)

#### `emotion_log`
The highest-velocity table. One row per student per 5-second vision cycle.

| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `student_id` | FK → students | |
| `lecture_id` | FK → lectures | |
| `timestamp` | DateTime TZ | server default |
| `emotion` | String | `Focused` \| `Engaged` \| `Confused` \| `Anxious` \| `Frustrated` \| `Disengaged` |
| `confidence` | Float | fixed per emotion state (see §5.2) |
| `engagement_score` | Float | equals `confidence` |

#### `attendance_log`
| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `student_id` | FK → students | |
| `lecture_id` | FK → lectures | |
| `timestamp` | DateTime TZ | |
| `status` | String | `Present` \| `Absent` |
| `method` | String | `AI` \| `Manual` \| `QR` |
| `snapshot_url` | String | nullable — person ROI crop at moment of detection |

#### `incidents`
Exam proctoring violations.

| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `student_id` | FK → students | nullable |
| `exam_id` | String | nullable |
| `timestamp` | DateTime TZ | |
| `flag_type` | String | `phone_on_desk` \| `head_rotation` \| `absent` \| `multiple_persons` \| `identity_mismatch` \| `app_background` |
| `severity` | Integer | 1 low \| 2 medium \| 3 high |
| `evidence_path` | String | path/URL to screenshot |

#### `notifications`
| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `student_id` | FK → students | nullable |
| `lecturer_id` | FK → lecturers | |
| `lecture_id_fk` | FK → lectures | nullable |
| `reason` | String | human-readable description |
| `created_at` | DateTime TZ | |
| `read` | Boolean | default `false` |

#### `focus_strikes`
| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `student_id` | FK → students | |
| `lecture_id` | FK → lectures | |
| `timestamp` | DateTime TZ | |
| `strike_type` | String | `app_background` — React Native AppState only |

#### `materials`
| Column | Type | Notes |
|---|---|---|
| `material_id` | String PK | |
| `lecture_id` | FK → lectures | |
| `lecturer_id` | FK → lecturers | |
| `title` | String | |
| `drive_link` | String | Google Drive share URL |
| `uploaded_at` | DateTime TZ | |

### 3.5 Comprehension / Quiz Tables

#### `comprehension_checks`
AI-generated MCQs for live in-lecture quizzes.

| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `lecture_id` | FK → lectures | CASCADE delete |
| `material_id` | FK → materials | SET NULL on delete |
| `question` | String | Gemini-generated question text |
| `options` | String | JSON-encoded list of 3 answer options |
| `correct_option` | Integer | 0-based index of correct option |
| `topic` | String | short label for mapping back to smart notes |

#### `student_answers`
| Column | Type | Notes |
|---|---|---|
| `id` | BigInt PK | |
| `check_id` | FK → comprehension_checks | |
| `student_id` | FK → students | |
| `chosen_option` | Integer | 0-based |
| `is_correct` | Boolean | |
| `timestamp` | DateTime TZ | |

---

## 4. Vision Pipeline

### 4.1 Hardware Setup

One fixed high-resolution IP camera per classroom, mounted at the front, facing the student crowd. Connects via RTSP stream (`CLASSROOM_CAMERA_URL` env var). All processing runs server-side — no student-side cameras.

### 4.2 Sequential Pipeline (vision_pipeline.py)

The pipeline runs continuously reading frames at the camera's native rate (30 fps), but runs the heavy AI inference stack on a staggered schedule to avoid overloading the server.

```
Camera Frame (RTSP, continuous read via cv2.VideoCapture)
          │
          ▼  Every frame:
          │  Encode to JPEG 50% quality → latest_frames[lecture_id]
          │  (shared dict for WebSocket live-stream)
          │
          ▼  Every 5 frames (~3 FPS):
┌────────────────────────────────────────────┐
│  Stage 1 — yolov8n.pt                      │
│  Person Detection on full crowd frame      │
│  → list of [x1, y1, x2, y2] person boxes  │
└──────────┬─────────────────────────────────┘
           │  For each person_roi:
           ▼
┌────────────────────────────────────────────┐
│  Stage 2 — yolov8n-face.pt                 │
│  Face detection within person_roi          │
│  → tight face_roi bounding box             │
└──────────┬─────────────────────────────────┘
           │
           ▼  Every 20 frames (identity is expensive):
┌──────────────────────────────────────────────────────────────┐
│  Task A — Identity                                           │
│  face_recognition.face_encodings(face_roi)                   │
│  → 128-dim float64 dlib vector                               │
│  → face_recognition.compare_faces(known_vectors, enc,        │
│       tolerance=0.6)                                         │
│  → student_id or "unknown"                                   │
│                                                              │
│  On first match per session:                                 │
│    INSERT attendance_log (status=PRESENT, method=FACE)       │
│    Save face_roi snapshot → data/snapshots/{lecture_id}/     │
└──────────┬───────────────────────────────────────────────────┘
           │
           ▼  Every 30 frames (~1 FPS):
┌──────────────────────────────────────────────────────────────┐
│  Task B — Emotion Classification                             │
│  HSEmotionRecognizer.predict_emotions(face_roi, logits=False)│
│  → dict of {emotion: score} over AffectNet categories       │
│  → dominant emotion label + score                            │
│  → map_emotion() → educational state + fixed confidence      │
│  INSERT emotion_log (emotion, confidence, engagement_score)  │
└──────────────────────────────────────────────────────────────┘

Every 50 frames:
  WebSocket broadcast → {type: "vision:heartbeat", frame: N}
```

**Why two YOLO models (person → face)?**
`HSEmotion` was trained on AffectNet (tight face-only crops). Passing a full person body ROI is out-of-domain and degrades emotion accuracy. `yolov8n-face.pt` runs on the already-cropped person ROI to extract a tight face crop. Identity matching via `face_recognition` uses the face ROI directly.

### 4.3 Models (vision_pipeline.py)

| Model | Library | Purpose | Notes |
|---|---|---|---|
| `yolov8n.pt` | `ultralytics` | Person detection in full crowd frame | YOLOv8 nano — fast, low memory |
| `yolov8n-face.pt` | `ultralytics` | Tight face crop from each person ROI | Auto-checked at startup |
| `enet_b0_8_best_afew` | `hsemotion` | Facial expression recognition | AffectNet-trained, ~75–80% accuracy |
| dlib 128-dim | `face_recognition` | Face encoding + identity matching | Euclidean distance, tolerance 0.6 |
| FaceMesh | `mediapipe` | Head pose estimation (exam only) | Pitch/Yaw/Roll for head_rotation flag |

### 4.4 HSEmotion → Educational State Mapping

| HSEmotion Raw Label | Condition | Educational State | Fixed Confidence |
|---|---|---|---|
| `neutral` | always | **Focused** | 1.00 |
| `happy`, `surprise` | always | **Engaged** | 0.85 |
| `fear` | always | **Anxious** | 0.35 |
| `anger`, `disgust` | softmax score < 0.65 | **Confused** | 0.55 |
| `anger`, `disgust` | softmax score ≥ 0.65 | **Frustrated** | 0.25 |
| `sad` | always | **Disengaged** | 0.00 |

### 4.5 Roster Ingestion — InsightFace ArcFace (roster.py)

Face encoding for roster ingestion uses a **different model** than the live pipeline: **InsightFace** (`FaceAnalysis` with `CPUExecutionProvider`), which generates **512-dim float32 ArcFace embeddings**.

Flow:
1. Lecturer uploads `StudentPicsDataset.xlsx` (columns: `student_id`, `name`, `email`, `photo_link`)
2. FastAPI `POST /roster/upload` parses via `pandas.read_excel()`
3. `extract_drive_id(photo_link)` → regex extracts Google Drive `file_id`
4. `requests.get(drive_download_url)` → raw image bytes
5. `InsightFace FaceAnalysis.get(rgb_image)` → detects all faces, picks the largest by bounding box area
6. `best_face.embedding.astype(np.float32).tobytes()` → stored as `BYTEA` in `students.face_encoding`
7. Returns `{students_created: N, encodings_saved: M}`

Single-student endpoint `POST /roster/student` accepts a direct photo file upload and follows the same InsightFace encoding path, with a 9-digit ID format validation guard.

`GET /roster/students/encodings` exposes all 512-dim embeddings as JSON lists (consumed by the local vision node).

---

## 5. Engagement Score Model

### 5.1 Design Principle

Confidence values are **not** taken from model softmax output. They are fixed, predetermined constants per educational state — deterministic, reproducible, and academically defensible. `engagement_score == confidence` always.

### 5.2 Fixed Confidence Table (Locked — Never Change)

| Educational State | Fixed Confidence | Engagement Level | Rationale |
|---|---|---|---|
| Focused | **1.00** | High | Active attentive processing |
| Engaged | **0.85** | High | Positive affect |
| Confused | **0.55** | Moderate | Productive struggle — monitor |
| Anxious | **0.35** | Low | Stress — flag, especially in exams |
| Frustrated | **0.25** | Low | Blocked — intervene |
| Disengaged | **0.00** | Critical | Withdrawn — immediate alert |

### 5.3 Engagement Level Thresholds

| Level | Score Range | Action |
|---|---|---|
| High | ≥ 0.75 | No action needed |
| Moderate | 0.45–0.74 | Monitor |
| Low | 0.25–0.44 | Flag to lecturer |
| Critical | < 0.25 | Intervention alert |

### 5.4 Derived Class Metrics (Computed in R)

```r
# Cognitive load — indicates if lecture pace is too fast
cognitive_load = confusion_rate + frustration_rate
# > 0.50 → lecture pace too fast → trigger Fresh-Brainer

# Class valence — overall emotional health of the class
class_valence = (focused_rate + engaged_rate) -
                (frustration_rate + disengaged_rate + anxiety_rate)
# Range: -1.0 to +1.0
# Positive = healthy | Negative = intervention needed
```

---

## 6. FastAPI Backend

### 6.1 Entry Point (`main.py`)

**Version:** 3.9.0 — Gemini Integration Stable

The app registers all routers under two prefix variants simultaneously (`""` and `"/api"`) for compatibility with both direct calls and proxied paths.

```
app = FastAPI(title="AAST LMS API (Consolidated)")

Routers:
  /auth        — JWT authentication
  /admin       — Admin CRUD and system management
  /courses     — Course and class management
  /emotion     — Emotion log read + live query
  /attendance  — Attendance CRUD (AI, Manual, QR)
  /session     — Lecture lifecycle + WebSocket hub
  /gemini      — AI intervention endpoints
  /notes       — Smart notes + intervention plans
  /exam        — Exam lifecycle + auto-submit logic
  /roster      — Student photo upload + face encoding
  /upload      — Lecture material uploads (Google Drive)
  /notify      — Lecturer notification dispatch
  /vision      — Vision pipeline control (start/stop/status)
```

All routes also registered under `/api/*` prefix for proxy compatibility.

### 6.2 Startup Sequence

On startup (`lifespan` context manager):

1. Captures the event loop for WebSocket `broadcast_sync` (Gemini push notifications)
2. Runs SQL migrations (adds columns/tables that may not exist in older DB instances)
3. Calls `Base.metadata.create_all()` to ensure all tables exist
4. Starts `APScheduler` for background tasks (nightly export, lecture auto-end)

### 6.3 Health Check

`GET /health`, `GET /`, `GET /api/health`, `GET /ping`

```json
{
  "status": "ok",
  "database": "connected",
  "version": "3.9.0",
  "message": "Gemini Integration Stable"
}
```

### 6.4 Authentication

`POST /auth/login` accepts `{student_id/email, password}` → returns JWT.

JWT payload: `{user_id, role, exp}`

Roles: `admin` | `lecturer` | `student`

Password hashing: `bcrypt` via `passlib`. All three user tables (`admins`, `lecturers`, `students`) carry a `password_hash` column and a `needs_password_reset` flag (set to `true` on account creation — forces password change on first login).

### 6.5 Key Endpoints

#### Emotion
- `GET /emotion/live?lecture_id=L1&limit=60` — last N emotion_log rows for a lecture, ordered by timestamp desc. Used by the Shiny live dashboard's `reactiveTimer`.

#### Session / WebSocket
- `POST /session/start` — creates lecture record, starts vision pipeline in background thread, broadcasts `{type: "session:start", slideUrl, lectureId}` to all WS clients
- `POST /session/end` — sets `end_time`, stops vision thread via `threading.Event` stop flag, broadcasts `{type: "session:end"}`
- `WS /session/ws` — per-lecture WebSocket connection pool

#### WebSocket Event Types

| Event | Direction | Payload |
|---|---|---|
| `session:start` | Server → clients | `{slideUrl, lectureId}` |
| `session:end` | Server → clients | `{}` |
| `freshbrainer` | Server → clients | `{question: "..."}` |
| `focus_strike` | Client → server | `{student_id, lecture_id, strike_type}` |
| `exam:autosubmit` | Server → client | `{exam_id}` |

#### Roster
- `POST /roster/upload` — accepts multipart XLSX, runs face encoding pipeline (see §4.5), returns `{students_created, encodings_saved}`

#### Gemini
- `POST /gemini/question` — extracts slide text via `pdfplumber`, calls Gemini Flash, returns one clarifying question
- `GET /notes/{student_id}/{lecture_id}` — returns generated smart notes markdown
- `GET /notes/{student_id}/plan` — returns 3-step AI intervention plan markdown

#### Vision Control
- `POST /vision/start` — starts the vision pipeline for a lecture
- `POST /vision/stop` — gracefully stops it
- `GET /vision/status` — returns current frame count and running state

### 6.6 Database Connection

Uses SQLAlchemy with a PostgreSQL connection string from `DATABASE_URL` env var. WAL mode is enabled for concurrent vision-thread writes alongside API reads.

```python
# database.py pattern
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```

---

## 7. R/Shiny Analytics Portal

### 7.1 Architecture Overview

The Shiny portal is the **Admin and Lecturer interface only**. It has two data access paths:

1. **Direct PostgreSQL** — `RPostgres::Postgres()` + custom `parse_postgres_url()` parser for production stability. Used for reading all historical data tables.
2. **FastAPI REST** — `httr2` HTTP client (`api_call()` helper) for authenticated operations (login, roster upload, starting lectures, triggering Gemini interventions).

**Configuration** (`global.R`):
```r
FASTAPI_BASE <- Sys.getenv("API_URL", "https://classroomx-lkbxf.ondigitalocean.app")
# Ensures /api suffix is always appended
if (!grepl("/api$", FASTAPI_BASE)) FASTAPI_BASE <- paste0(FASTAPI_BASE, "/api")
```

**Emotion color palette:**
```r
emotion_colors <- list(
  "Focused"     = "#1B5E20",  # dark green
  "Engaged"     = "#4CAF50",  # green
  "Confused"    = "#FFC107",  # amber
  "Frustrated"  = "#FF9800",  # orange
  "Anxious"     = "#9C27B0",  # purple
  "Disengaged"  = "#F44336"   # red
)
```

**Branding constants:** `AAST_NAVY = "#002147"`, `AAST_GOLD = "#C9A84C"`

### 7.2 `engagement_score.R` — Core Analytics Module

This module is the computational foundation for all panels. It produces two output data frames from raw emotion log data.

#### `compute_engagement(emotions_df)`

**By-Lecture Output** (per student × per lecture):

| Field | Formula |
|---|---|
| `engagement_score` | `mean(engagement_score)` across all readings |
| `dominant_emotion` | `names(which.max(table(emotion)))` |
| `confusion_rate` | `mean(emotion == "Confused")` |
| `frustration_rate` | `mean(emotion == "Frustrated")` |
| `anxiety_rate` | `mean(emotion == "Anxious")` |
| `disengaged_rate` | `mean(emotion == "Disengaged")` |
| `focused_rate` | `mean(emotion == "Focused")` |
| `engaged_rate` | `mean(emotion == "Engaged")` |
| `cognitive_load` | `confusion_rate + frustration_rate` |
| `class_valence` | `(focused_rate + engaged_rate) - (frustration_rate + disengaged_rate + anxiety_rate)` |
| `engagement_level` | `High` / `Moderate` / `Low` / `Critical` (§5.3 thresholds) |
| `duration_minutes` | `difftime(max(timestamp), min(timestamp))` |
| `n_observations` | count of emotion readings |

**By-Student Output** (aggregate across all lectures):

| Field | Formula |
|---|---|
| `avg_engagement` | `mean(engagement_score)` across lectures |
| `avg_cognitive_load` | `mean(cognitive_load)` across lectures |
| `total_duration` | `sum(duration_minutes)` |
| `trend_slope` | `coef(lm(engagement_score ~ seq_along(...)))[2]` — positive = improving, negative = declining → early intervention flag |
| `lectures_attended` | count of lectures |
| `dominant_emotion` | most frequent emotion overall |

#### `compute_class_metrics(emotions_df, lecture_id)`

Returns a single-row summary for one lecture (class-level aggregation):
- `avg_engagement`, `confusion_rate`, `frustration_rate`, `cognitive_load`, `n_students`, `n_observations`

#### `calculate_student_duration(attendance_df, lecture_id)`

Returns time-in-class per student based on attendance timestamp range.

### 7.3 `clustering.R` — Unsupervised Segmentation

#### `cluster_lecturers(les_df, k=3)`

Groups lecturers into three performance tiers using K-Means on normalized `avg_engagement` and `attendance_rate`.

- Features are z-score scaled (with zero-variance guard)
- `nstart=10` for stability
- Clusters are auto-labeled by centroid engagement rank:
  - Highest centroid → **"High Performers"**
  - Middle → **"Consistent"**
  - Lowest → **"Needs Support"**

#### `cluster_student_behavior(emotions_df, k=3)`

Groups students by emotion profile using K-Means on 6 normalized emotion rate features:
`avg_focused`, `avg_engaged`, `avg_confused`, `avg_frustrated`, `avg_anxious`, `avg_disengaged`

- Zero-variance columns are replaced with zeros before scaling
- Auto-labeled by average engagement score per cluster:
  - Highest → **"The High-Performers"**
  - Middle → **"The Average Group"**
  - Lowest → **"The Distracted Group"**

#### `get_lecturer_pca(clustered_lecturers)`

PCA projection of lecturer clusters to 2D (`PC1`, `PC2`) for scatter plot visualization. Uses `prcomp()` with `scale.=FALSE` (data already scaled).

### 7.4 Admin View — 8 Panels

All panels read from PostgreSQL via `query_table()` and refresh on `reactivePoll` (checks PostgreSQL mtime equivalent every 60s).

| # | Panel | Chart Type | Key Logic |
|---|---|---|---|
| 1 | **Attendance Overview** | `DT::datatable` | Per-course attendance %. Filters: dept + date range. Export: xlsx |
| 2 | **Engagement Trend** | `plotly` line | x=week, y=avg engagement_score, color=department |
| 3 | **Dept Engagement Heatmap** | `ggplot2 geom_tile` | x=week, y=dept, fill=avg engagement |
| 4 | **At-Risk Cohort** | `DT::datatable` | Students with >20% engagement drop over 3 consecutive lectures. "Flag" → `POST /notify/lecturer` |
| 5 | **Lecture Effectiveness Score (LES)** | `DT::datatable` | `LES = 0.5×avg_engagement + 0.3×(1−confusion_rate) + 0.2×attendance_rate`. Top 10% green, bottom 10% red |
| 6 | **Emotion Distribution** | `ggplot2 geom_col(position="fill")` | Stacked bar per dept, normalized. All 6 states |
| 7 | **Lecturer Cluster Map** | `plotly` scatter | `cluster_lecturers()` → PCA scatter, 3 labels |
| 8 | **Time-of-Day Heatmap** | `ggplot2 geom_tile` | x=weekday, y=08:00–20:00 slot, fill=avg engagement |

### 7.5 Lecturer View — 5 Submodules

#### Submodule A — Roster Setup
- `fileInput("roster_xlsx", accept=".xlsx")` — accepts `StudentPicsDataset.xlsx`
- Progress bar during upload (Drive photo downloads are slow)
- `httr2 POST /roster/upload` (multipart)
- Success notification shows `{students_created, encodings_saved}`

#### Submodule B — Material Upload
- `fileInput` + `selectInput(lecture_id)` + title text
- `httr2 POST /upload/material` (multipart) → Google Drive → materials table
- Material list refreshes from PostgreSQL `materials` table

#### Submodule C — Attendance
- **Manual mode:** editable `DT::datatable` → `POST /attendance/manual`
- **AI mode:** button → `POST /attendance/start` → 5s status polling
- **QR fallback:** `GET /attendance/qr/{lecture_id}` → `renderImage`

#### Submodule D — Live Lecture Dashboard (7 Panels)

Polls `GET /emotion/live?lecture_id=` every 10 seconds via `reactiveTimer(10000)`.

**D1 — Engagement Gauge**
- `plotly::plot_ly(type="indicator", mode="gauge+number")`
- Value = `mean(engagement_score)` of last 60 readings
- Zones: red < 0.25 | amber 0.25–0.45 | green > 0.45

**D2 — Real-Time Emotion Timeline**
- `plotly scatter mode="lines"`, x = timestamp (last 30 min), y = % of class per state, 6 lines
- 2-minute time buckets via `floor_date(timestamp, "2 minutes")`

**D3 — Cognitive Load Indicator**
- Value box: `cognitive_load = confusion_rate + frustration_rate`
- green < 0.30 | amber 0.30–0.50 | red > 0.50 → "Overloaded — slow down"

**D4 — Class Valence Meter**
- Horizontal gauge: range −1.0 to +1.0
- If valence < 0 for > 5 consecutive readings → `shinyalert` warning

**D5 — Per-Student Emotion Heatmap**
- `ggplot2::geom_tile()`, x = 5-min segments, y = student_id, fill = dominant emotion

**D6 — Persistent Struggle Alert Table**
- `DT::datatable` — students Confused or Frustrated for ≥ 3 consecutive 5-second readings
- Amber = Confused×3 | Red = Frustrated×3
- Logic uses `cumsum` streak detection grouped by `student_id`

**D7 — Peak Confusion Moment Detector**
- Identifies the 2-minute window with highest `confusion_rate + frustration_rate`
- Displayed as post-session insight: "Most confusing moment: 10:42 AM"

#### Confusion Spike Observer
```r
# Observer runs every 10 seconds alongside live dashboard
confusion_rate = mean(emotion == "Confused") over last 120 rows
if (confusion_rate >= 0.40) → trigger Fresh-Brainer flow (§8.1)
```

#### Submodule E — Student Reports
- Per-student card: engagement trend, cognitive load, dominant emotion, valence history
- AI plan: `GET /notes/{student_id}/plan` → `renderMarkdown()`
- PDF export: `downloadHandler()` → `rmarkdown::render("reports/student_report.Rmd", params=list(student_id=...))`

**`student_report.Rmd` sections:**
1. Executive Summary (avg engagement, dominant emotion, cognitive load)
2. Engagement trend chart across all lectures
3. Emotion distribution pie chart
4. Cognitive load timeline
5. AI intervention plan (3 Gemini-generated steps)
6. Attendance record

---

## 8. AI Features (Gemini)

All AI features use `gemini-2.5-flash` via `google-generativeai`. Model is accessed from `gemini_service.py`.

### 8.1 Fresh-Brainer (Confusion Intervention)

**Trigger:** `confusion_rate ≥ 0.40` over the last 2 minutes (Shiny observer)

**Flow:**
1. Shiny `POST /gemini/question {lecture_id: "L1"}`
2. FastAPI retrieves `slide_url` from lectures table
3. Extracts slide text via `pdfplumber`
4. Gemini prompt: generate ONE clarifying question (≤ 2 sentences) to re-engage students
5. Returns `{question: "..."}`
6. Shiny shows `shinyalert` popup with "Ask it" / "Dismiss" buttons
7. If "Ask it" → `POST /session/broadcast` → WS event `{type: "freshbrainer", question: "..."}`
8. React Native renders question as bottom-sheet overlay on the Focus screen

### 8.2 Smart Notes

**Input:** lecture transcript, `distraction_timestamps` (when student was Disengaged), `wrong_topics` (from failed comprehension checks)

**Output:** Markdown study notes. Content covered during distraction windows is re-explained and prefixed with `✱` marker.

**Delivered to:** React Native `GET /notes/{student_id}/{lecture_id}` after lecture ends

### 8.3 AI Intervention Plan

**Input:** student's temporal emotion history across lectures (e.g. "Week 1: Mostly Confused. Week 2: Disengaged.")

**Output:** Exactly 3 numbered, actionable steps the lecturer can take for this specific student

**Delivered to:** Shiny Submodule E student report + `student_report.Rmd` PDF

### 8.4 Comprehension Checks (Live MCQs)

**Input:** Up to 5000 characters of lecture material text

**Output:** JSON object `{question, options: [3 items], correct_option: 0-based index, topic: "short label"}`

Stored in `comprehension_checks` table. Student answers stored in `student_answers`. Wrong topics feed back into Smart Notes generation.

---

## 9. Student Mobile App

**Technology:** React Native + Expo
**Audience:** Students only — Admin and Lecturer do not use this app

### 9.1 Screens

| Screen | File | Purpose |
|---|---|---|
| Login | `app/(auth)/login.tsx` | JWT auth → stores token in Zustand |
| Home | `app/(student)/home.tsx` | Upcoming lectures, last-lecture engagement summary |
| Focus | `app/(student)/focus.tsx` | AppState monitor, strike sender, WS event handler |
| Notes | `app/(student)/notes.tsx` | Smart notes markdown viewer with ✱ highlights |

### 9.2 Focus Mode (AppState Integration)

```typescript
// When app goes to background during a live lecture:
AppState.addEventListener('change', (next: AppStateStatus) => {
  if (next !== 'active' && focusActive) {
    socket.emit('focus_strike', {
      type:       'focus_strike',
      student_id: studentId,
      lecture_id: activeLectureId,
      strike_type: 'app_background',
      // context: 'exam'  ← add during exam sessions to route to incidents table
    });
    setStrikes(s => s + 1);
  }
});
```

- **No OS-level device locks.** Only React Native AppState API.
- Strike counter shown on `FocusOverlay` component
- Strike written to `focus_strikes` table (or `incidents` if `context: 'exam'`)

### 9.3 WebSocket Events Received

| Event | Action |
|---|---|
| `session:start` | Shows slide URL + activates focus lock |
| `session:end` | Releases focus lock |
| `freshbrainer` | Renders bottom-sheet with Gemini question |
| `exam:autosubmit` | Navigates to "Exam Submitted" screen |

### 9.4 State Management

Zustand store (`store/useStore.ts`): `studentId`, `strikes`, `focusActive`, `activeLectureId`, JWT token

---

## 10. Exam Proctoring

Proctoring is **camera-based only** — no JavaScript browser lockdowns, no device-level restrictions.

### 10.1 Detection Methods

| Violation | Detection Tool | Flag Written | Severity |
|---|---|---|---|
| Phone on desk | YOLOv8 COCO class 67 (cell phone) | `phone_on_desk` | 3 (High) |
| No face detected > 5s | face_recognition | `absent` | 3 (High) |
| Multiple persons in frame | YOLO person count > 1 | `multiple_persons` | 3 (High) |
| Extreme head rotation | MediaPipe FaceMesh | `head_rotation` | 2 (Medium) |
| Identity mismatch | face_recognition vs enrolled encoding | `identity_mismatch` | 3 (High) |
| App goes to background | React Native AppState | `app_background` | 1 (Low) |

### 10.2 Auto-Submit Rule

If **3 × Severity-3 incidents** occur within any 10-minute sliding window:
- `POST /exam/submit` called automatically
- WebSocket broadcast: `{type: "exam:autosubmit", exam_id}`
- Student app navigates to "Exam Submitted" screen

All incidents are saved to the `incidents` table with a screenshot in `data/evidence/`.

---

## 11. Data Flows (End-to-End)

### 11.1 Roster Initialization

```
Lecturer (Shiny) → uploads StudentPicsDataset.xlsx
    → httr2 POST /roster/upload
    → FastAPI: parse XLSX → INSERT students
    → For each student: download Drive photo
    → face_recognition.face_encodings() → BYTEA → students.face_encoding
    → Return {students_created: N, encodings_saved: M}
    → Shiny shows success notification
```

### 11.2 Live Lecture Loop

```
1. Lecturer clicks "Start Lecture" in Shiny
   → POST /session/start {lecture_id, lecturer_id, slide_url}
   → FastAPI: INSERT lectures row, spawn vision thread, broadcast session:start

2. Vision pipeline (every 5 seconds):
   → RTSP frame → YOLO persons → per-person: face_recognition → student_id
   → yolo_face → HSEmotion → map_emotion() → INSERT emotion_log
   → On first detection: INSERT attendance_log

3. Student app (AppState):
   → App background → WS emit focus_strike → INSERT focus_strikes

4. Shiny live dashboard (every 10 seconds):
   → GET /emotion/live?lecture_id= → refresh all 7 D-panels

5. Confusion spike check (every 10 seconds):
   → confusion_rate ≥ 0.40 over last 120 rows → trigger Fresh-Brainer (§8.1)

6. Lecturer clicks "End Lecture"
   → POST /session/end → updates lectures.end_time
   → Broadcasts session:end → stops vision thread

7. Nightly 02:00: APScheduler → export all tables to data/exports/*.csv
```

### 11.3 AI Intervention (Confusion Spike)

```
Shiny observer detects confusion_rate ≥ 0.40
    → POST /gemini/question {lecture_id}
    → FastAPI: pdfplumber extracts slide text
    → Gemini: generates ONE clarifying question
    → Shiny: shinyalert popup "42% confused — Suggested: [question]"
    → Lecturer clicks "Ask it"
    → POST /session/broadcast → WS {type: "freshbrainer", question}
    → React Native: renders bottom-sheet overlay
```

---

## 12. Deployment

### 12.1 FastAPI — DigitalOcean App Platform

- URL: `https://classroomx-lkbxf.ondigitalocean.app`
- Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- Auto-deploy on push to `main` via GitHub integration
- PostgreSQL managed database on DigitalOcean (connection via `DATABASE_URL` env var)

### 12.2 R/Shiny — shinyapps.io

```r
setwd("path/to/shiny-app")
rsconnect::deployApp(appName = "aast-lms")
```

Environment variables on shinyapps.io are set via `config.yml` (gitignored) loaded with the `config` package.

### 12.3 React Native — Expo / EAS Build

Development: `npx expo start` → scan QR code with Expo Go
Production APK: `eas build --platform android --profile preview`

### 12.4 Environment Variables

```bash
# python-api/.env
GEMINI_API_KEY=          # Google AI Studio
JWT_SECRET=              # long random string
DATABASE_URL=            # postgresql://user:pass@host:port/dbname
CLASSROOM_CAMERA_URL=    # rtsp://192.168.x.x/stream
GOOGLE_APPLICATION_CREDENTIALS=./gcloud_key.json

# shiny-app/config.yml  (gitignored)
default:
  fastapi_base: "https://classroomx-lkbxf.ondigitalocean.app"
  database_url: "postgresql://..."

# react-native-app/.env
EXPO_PUBLIC_API_URL=https://classroomx-lkbxf.ondigitalocean.app
EXPO_PUBLIC_WS_URL=wss://classroomx-lkbxf.ondigitalocean.app
```

### 12.5 Key Constraints (Always Apply)

1. One classroom camera — never suggest student webcams
2. Vision: YOLO → face_recognition → HSEmotion, 1 frame/5s — sequential, rate-limited
3. R/Shiny = Admin + Lecturer **only**; React Native = Students **only**
4. Engagement confidence values are fixed (§5.2) — never use model softmax
5. AppState API for focus strikes — no OS-level locks
6. Camera-based exam proctoring only — no JS browser lockdowns
7. AAST branding (`#002147` navy, `#C9A84C` gold) — never overwrite existing CSS chrome