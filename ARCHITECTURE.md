# ARCHITECTURE.md — Logical Architecture & Data Flow Specification
> **Audience:** Engineering team only (S1–S4). This document defines the precise wiring between every subsystem. Nothing here is advisory — implement it exactly as written.
> **Source of truth:** CLAUDE.md overrides this document in case of conflict.

---

## Table of Contents

1. [System Boundary Map](#1-system-boundary-map)
2. [Core Module Definitions & Communication Rules](#2-core-module-definitions--communication-rules)
3. [Data Contracts — HTTP API](#3-data-contracts--http-api)
4. [Data Contracts — WebSocket Payloads](#4-data-contracts--websocket-payloads)
5. [Data Contracts — SQLite Schemas (Full)](#5-data-contracts--sqlite-schemas-full)
6. [Data Contracts — Nightly CSV Exports](#6-data-contracts--nightly-csv-exports)
7. [Flow A — Roster Ingestion & Cold Start](#7-flow-a--roster-ingestion--cold-start)
8. [Flow B — The 5-Second Live Lecture Heartbeat](#8-flow-b--the-5-second-live-lecture-heartbeat)
9. [Flow C — The Gemini AI Intervention Trigger](#9-flow-c--the-gemini-ai-intervention-trigger)
10. [Flow D — The Nightly Data Handoff](#10-flow-d--the-nightly-data-handoff)
11. [Edge Case Handling & Fail-Safes](#11-edge-case-handling--fail-safes)

---

## 1. System Boundary Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLASSROOM (Physical Layer)                         │
│                                                                             │
│   ┌──────────────────┐          ┌──────────────────┐                       │
│   │  IP Camera (1x)  │  RTSP    │   Microphone     │  PCM audio            │
│   │  Fixed, ceiling  │─────────▶│   (USB/3.5mm)    │──────────────────┐    │
│   └──────────────────┘          └──────────────────┘                  │    │
└───────────────┬─────────────────────────────────────────────────────── │───┘
                │ RTSP stream                                             │
                ▼                                                         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                       FASTAPI BACKEND  (Railway.app)                         │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    vision_pipeline.py (Thread 1)                    │    │
│  │   cv2.VideoCapture → YOLOv8 → face_recognition → HSEmotion         │    │
│  │   Rate: 1 frame / 5 seconds                                         │    │
│  └────────────────────────────┬────────────────────────────────────────┘    │
│                               │ INSERT                                       │
│  ┌─────────────────────────── │ ─────────────────────────────────────────┐  │
│  │                            ▼                                          │  │
│  │                     SQLite Database                                   │  │
│  │          classroom_emotions.db  (python-api/data/)                   │  │
│  │                                                                       │  │
│  │  students | lectures | emotion_log | attendance_log | materials       │  │
│  │  incidents | transcripts | notifications | focus_strikes              │  │
│  └───────────────────────────────────────────────────────────────────── ┘  │
│                               │                                              │
│  ┌─────────────────────────── │ ─────────────────────────────────────────┐  │
│  │           whisper_service.py (Coroutine)    INSERT ─────────────────▶ │  │
│  │   sounddevice → Whisper API → transcripts table                       │  │
│  │   Broadcast → WebSocket → React Native clients                        │  │
│  └───────────────────────────────────────────────────────────────────── ┘  │
│                                                                              │
│  APScheduler (cron 02:00) ──────────────────────────────────────────────── ▶│
│           export_service.py → data/exports/*.csv                            │
└──────────┬───────────────────────────────┬───────────────────────────────── ┘
           │ HTTP (httr2)                  │ WebSocket (socket.io)
           ▼                               ▼
┌─────────────────────┐        ┌─────────────────────────┐
│  R/Shiny Web Portal │        │  React Native Mobile App│
│  (shinyapps.io)     │        │  (Expo — Android only)  │
│                     │        │                         │
│  Admin + Lecturer   │        │  Students ONLY          │
│  Reads: CSV exports │        │  Sends: JSON over WS    │
│  Calls: FastAPI HTTP│        │  Never sends video      │
└─────────────────────┘        └─────────────────────────┘
```

---

## 2. Core Module Definitions & Communication Rules

### 2.1 Module Definitions

| Module | Runtime | Owner | Responsibilities |
|--------|---------|-------|-----------------|
| **FastAPI Backend** | Railway.app (Python 3.11) | S3 | All business logic, DB writes, WebSocket server, AI orchestration |
| **Vision + Audio AI** | Same process as FastAPI (S1 code) | S1 | Camera capture, YOLO, face_recognition, HSEmotion, Whisper |
| **R/Shiny Web Portal** | shinyapps.io | S2 | Admin dashboards, Lecturer panels — reads CSV, calls FastAPI HTTP |
| **React Native App** | Expo / Android APK | S4 | Student interface — WebSocket client, AppState monitor |

---

### 2.2 Strict Communication Rules

These rules are architectural invariants. Violating them breaks the data isolation model.

**R/Shiny Web Portal:**
- ✅ MAY call FastAPI via HTTP (httr2) for live actions (start session, upload roster, trigger alert)
- ✅ MAY read CSV files from `data/exports/` for all analytics dashboards
- ❌ MUST NOT connect to SQLite directly — ever
- ❌ MUST NOT write to any CSV file
- ❌ MUST NOT open a WebSocket connection
- ❌ MUST NOT perform any AI computation

**React Native App:**
- ✅ MAY connect to FastAPI via WebSocket for receiving events (captions, session:start, alerts)
- ✅ MAY call FastAPI via HTTP for auth, notes fetch, upcoming lectures
- ✅ MAY emit WebSocket events (focus strikes)
- ❌ MUST NOT send video or audio to FastAPI — only JSON text payloads
- ❌ MUST NOT access the camera for emotion detection
- ❌ MUST NOT read CSV files
- ❌ MUST NOT connect to SQLite

**Vision + Audio AI (S1 modules):**
- ✅ Runs as threads/coroutines spawned by FastAPI session router
- ✅ Writes directly to SQLite via SQLAlchemy session
- ❌ MUST NOT write to CSV files (APScheduler owns that)
- ❌ MUST NOT call WebSocket endpoints (whisper_service handles its own broadcast via shared `active_connections`)

**FastAPI Backend:**
- ✅ Is the single writer to SQLite
- ✅ Is the WebSocket server
- ✅ Calls external APIs: OpenAI Whisper, Google Gemini, Google Drive
- ❌ MUST NOT read from CSV exports (it only writes them via APScheduler)

---

## 3. Data Contracts — HTTP API

All endpoints are prefixed relative to `FASTAPI_BASE_URL`. JSON in, JSON out unless multipart.

### 3.1 Health

```
GET /health
Response 200: {"status": "ok"}
```

### 3.2 Authentication

```
POST /auth/login
Body:    {"student_id": "S01", "password": "abc123"}
Response 200: {"token": "<JWT>", "role": "student", "student_id": "S01"}
Response 401: {"detail": "Invalid credentials"}

JWT payload: {"student_id": "S01", "role": "student", "exp": <unix_ts>}
```

### 3.3 Session Management

```
POST /session/start
Body:    {"lecture_id": "L1", "lecturer_id": "LECT01", "slide_url": "https://drive.google.com/..."}
Response 200: {"status": "started", "lecture_id": "L1"}
Side-effects:
  - INSERT into lectures table
  - Spawns vision_pipeline thread (background)
  - Spawns whisper_service coroutine (background)
  - Broadcasts WebSocket: session:start

POST /session/end
Body:    {"lecture_id": "L1"}
Response 200: {"status": "ended"}
Side-effects:
  - UPDATE lectures SET end_time = NOW()
  - Stops vision thread and whisper coroutine
  - Broadcasts WebSocket: session:end

POST /session/broadcast
Body:    {"event": "freshbrainer", "question": "Can you explain the difference between X and Y?"}
Response 200: {"status": "broadcast"}

GET /session/upcoming
Headers: Authorization: Bearer <JWT>
Response 200: [{"lecture_id": "L1", "title": "...", "start_time": "...", "slide_url": "..."}]
```

### 3.4 Emotion

```
GET /emotion/live?lecture_id=L1&limit=60
Response 200: [
  {
    "student_id": "S01",
    "lecture_id": "L1",
    "timestamp": "2026-04-28T09:05:00",
    "emotion": "Focused",
    "confidence": 1.0,
    "engagement_score": 1.0
  },
  ...
]

GET /emotion/confusion-rate?lecture_id=L1&window=120
Response 200: {"lecture_id": "L1", "confusion_rate": 0.42, "window_seconds": 120}
```

### 3.5 Roster

```
POST /roster/upload
Content-Type: multipart/form-data
Fields:
  roster_csv: <file>   — CSV with columns: student_id, name, email
  images_zip: <file>   — ZIP where each file is named {student_id}.jpg
Response 200: {"students_created": 30, "encodings_saved": 28}
Response 422: {"detail": "No face detected in image for student_id S05"}
```

### 3.6 Attendance

```
POST /attendance/start
Body:    {"lecture_id": "L1"}
Response 200: {"status": "scanning"}

POST /attendance/manual
Body:    [{"student_id": "S01", "status": "Present"}, {"student_id": "S02", "status": "Absent"}]
Response 200: {"updated": 2}

GET /attendance/qr/{lecture_id}
Response 200: {"qr_image_base64": "<base64 PNG>"}
```

### 3.7 Gemini Endpoints

```
POST /gemini/question
Body:    {"lecture_id": "L1"}
Response 200: {"question": "Can you clarify what Big O notation means for nested loops?"}

GET /notes/{student_id}/{lecture_id}
Response 200: {"markdown": "## Lecture Notes\n\n...✱ You missed this part..."}

GET /notes/{student_id}/plan
Response 200: {"markdown": "1. Schedule office hours...\n2. ..."}
```

### 3.8 Exam

```
POST /exam/start
Body:    {"exam_id": "E01", "lecture_id": "L1"}
Response 200: {"status": "proctoring_active"}

POST /exam/submit
Body:    {"exam_id": "E01", "student_id": "S01", "reason": "auto_3_severity3"}
Response 200: {"status": "submitted"}

GET /exam/incidents/{exam_id}
Response 200: [
  {
    "student_id": "S01",
    "timestamp": "2026-04-28T10:15:33",
    "flag_type": "phone_on_desk",
    "severity": 3,
    "evidence_path": "data/evidence/E01_S01_1714299333.jpg"
  }
]
```

---

## 4. Data Contracts — WebSocket Payloads

WebSocket endpoint: `ws://<FASTAPI_BASE_URL>/session/ws`

All payloads are JSON-encoded strings. The `type` field is the discriminator — the client must switch on it.

### 4.1 Server → Client (FastAPI broadcasts to all connected clients)

**Session Start**
```json
{
  "type": "session:start",
  "lecture_id": "L1",
  "slide_url": "https://drive.google.com/file/d/abc123/view",
  "lecturer_id": "LECT01",
  "timestamp": "2026-04-28T09:00:00Z"
}
```

**Session End**
```json
{
  "type": "session:end",
  "lecture_id": "L1",
  "timestamp": "2026-04-28T11:00:00Z"
}
```

**Live Caption Broadcast**
```json
{
  "type": "caption",
  "text": "وهنا نشرح مفهوم التعقيد الزمني في الخوارزميات",
  "lecture_id": "L1",
  "timestamp": "2026-04-28T09:05:03Z",
  "language": "ar"
}
```
> `language` values: `"ar"` | `"en"` | `"mixed"` — Whisper detects per chunk.

**Fresh-Brainer Intervention Alert**
```json
{
  "type": "freshbrainer",
  "question": "Can you give an example of when O(n²) is acceptable?",
  "lecture_id": "L1",
  "timestamp": "2026-04-28T09:32:00Z"
}
```

**Exam Auto-Submit Signal**
```json
{
  "type": "exam:autosubmit",
  "exam_id": "E01",
  "student_id": "S01",
  "reason": "3 severity-3 incidents in 10 minutes",
  "timestamp": "2026-04-28T10:18:00Z"
}
```

---

### 4.2 Client → Server (React Native sends to FastAPI)

**Focus Strike**
```json
{
  "type": "focus_strike",
  "student_id": "S01",
  "lecture_id": "L1",
  "strike_type": "app_background",
  "timestamp": "2026-04-28T09:12:44Z"
}
```
> `strike_type` is always `"app_background"`. This is the only strike type. No tab-switch, no browser events.

**Exam Background Strike**
```json
{
  "type": "focus_strike",
  "student_id": "S01",
  "lecture_id": "L1",
  "strike_type": "app_background",
  "timestamp": "2026-04-28T10:14:10Z",
  "context": "exam"
}
```
> When `context` is `"exam"`, FastAPI writes to `incidents` table (severity=1) instead of `focus_strikes`.

---

## 5. Data Contracts — SQLite Schemas (Full)

Database file: `python-api/data/classroom_emotions.db`

**Critical rule:** All schemas below are locked after Week 1 sign-off. Column names and types must never change. Add new columns only via Alembic migration with a PR approved by all 4 members.

---

### `students`
```sql
CREATE TABLE students (
    student_id    TEXT PRIMARY KEY,
    -- Format: "S01", "S02", etc. — must match roster CSV
    name          TEXT NOT NULL,
    email         TEXT,
    face_encoding BLOB,
    -- 128-dim float64 numpy array serialized via .tobytes()
    -- Deserialize: np.frombuffer(face_encoding, dtype=np.float64)
    -- NULL until roster images are processed
    enrolled_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### `lectures`
```sql
CREATE TABLE lectures (
    lecture_id   TEXT PRIMARY KEY,
    -- Format: "L1", "L2", etc.
    lecturer_id  TEXT NOT NULL,
    title        TEXT,
    subject      TEXT,
    start_time   DATETIME,
    -- SET on POST /session/start
    end_time     DATETIME,
    -- SET on POST /session/end; NULL while lecture is live
    slide_url    TEXT
    -- Google Drive share link
);
```

### `emotion_log`
```sql
CREATE TABLE emotion_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id       TEXT NOT NULL REFERENCES students(student_id),
    lecture_id       TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp        DATETIME DEFAULT CURRENT_TIMESTAMP,
    emotion          TEXT NOT NULL,
    -- Allowed values ONLY: Focused | Engaged | Confused | Anxious | Frustrated | Disengaged
    -- Any other value is a bug in map_emotion()
    confidence       REAL NOT NULL,
    -- Fixed lookup — NOT from model softmax. See Section 8 of CLAUDE.md:
    -- Focused=1.00 | Engaged=0.85 | Confused=0.55 | Anxious=0.35 | Frustrated=0.25 | Disengaged=0.00
    engagement_score REAL NOT NULL
    -- Always equals confidence. engagement_score IS confidence.
);
```

**Insertion constraint:** One row per student per 5-second frame cycle. The pipeline never batches — it inserts immediately after each frame is processed.

### `attendance_log`
```sql
CREATE TABLE attendance_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    status      TEXT NOT NULL,
    -- Allowed values: "Present" | "Absent"
    -- AI inserts "Present" on first face recognition. Manual overrides insert "Absent" or "Present".
    method      TEXT NOT NULL
    -- Allowed values: "AI" | "Manual" | "QR"
);
```

**Uniqueness rule:** The vision pipeline uses a `seen_today` in-memory set per lecture session. The first time a `student_id` is detected in a lecture, it inserts `Present / AI`. Subsequent detections do not insert duplicate rows.

### `materials`
```sql
CREATE TABLE materials (
    material_id  TEXT PRIMARY KEY,
    -- Format: "M01", "M02", etc.
    lecture_id   TEXT NOT NULL REFERENCES lectures(lecture_id),
    lecturer_id  TEXT NOT NULL,
    title        TEXT NOT NULL,
    drive_link   TEXT,
    -- Google Drive share URL returned after upload
    uploaded_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### `incidents`
```sql
CREATE TABLE incidents (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id     TEXT REFERENCES students(student_id),
    exam_id        TEXT,
    timestamp      DATETIME DEFAULT CURRENT_TIMESTAMP,
    flag_type      TEXT NOT NULL,
    -- Allowed values:
    --   "phone_on_desk"      (YOLO class 67 detected)
    --   "head_rotation"      (MediaPipe FaceMesh extreme angle)
    --   "absent"             (no face detected > 5s during exam)
    --   "multiple_persons"   (YOLO person count > 1)
    --   "identity_mismatch"  (face_recognition distance > 0.5)
    --   "app_background"     (React Native AppState, context=exam)
    severity       INTEGER NOT NULL,
    -- 1 = low | 2 = medium | 3 = high
    -- phone_on_desk=3 | head_rotation=2 | absent=3
    -- multiple_persons=3 | identity_mismatch=3 | app_background=1
    evidence_path  TEXT
    -- Relative path: "data/evidence/{exam_id}_{student_id}_{unix_ts}.jpg"
    -- NULL for app_background (no frame captured)
);
```

**Auto-submit logic** (implemented in `proctor_service.py`):
```
Every 60 seconds during exam:
  severity3_count = COUNT(*) FROM incidents
    WHERE exam_id = current_exam
    AND severity = 3
    AND timestamp >= NOW() - 10 minutes

  IF severity3_count >= 3:
    POST /exam/submit with reason="auto_3_severity3"
    Broadcast WebSocket: exam:autosubmit
```

### `transcripts`
```sql
CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    chunk_text  TEXT NOT NULL,
    -- Raw Whisper output for a 5-second audio chunk
    -- May be Arabic, English, or a mix of both
    language    TEXT
    -- Whisper-detected language: "ar" | "en" | "mixed"
    -- "mixed" when Whisper detects Arabic words within English sentences or vice versa
);
```

### `notifications`
```sql
CREATE TABLE notifications (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecturer_id TEXT NOT NULL,
    lecture_id  TEXT REFERENCES lectures(lecture_id),
    reason      TEXT NOT NULL,
    -- Human-readable: "Engagement dropped >20% over 3 lectures"
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    read        INTEGER DEFAULT 0
    -- 0 = unread | 1 = read
);
```

### `focus_strikes`
```sql
CREATE TABLE focus_strikes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id  TEXT NOT NULL REFERENCES students(student_id),
    lecture_id  TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    strike_type TEXT NOT NULL
    -- Always "app_background" — the only possible value
    -- Inserted when React Native AppState changes to non-active
    -- during an active focus session (context != "exam")
);
```

---

## 6. Data Contracts — Nightly CSV Exports

Written by `export_service.py` at 02:00 via APScheduler. Path: `python-api/data/exports/`

Column names are locked — R/Shiny code reads these by name. Never rename.

```
emotions.csv:
    student_id (TEXT), lecture_id (TEXT), timestamp (DATETIME),
    emotion (TEXT), confidence (REAL), engagement_score (REAL)

attendance.csv:
    student_id (TEXT), lecture_id (TEXT), timestamp (DATETIME),
    status (TEXT), method (TEXT)

materials.csv:
    material_id (TEXT), lecture_id (TEXT), lecturer_id (TEXT),
    title (TEXT), drive_link (TEXT), uploaded_at (DATETIME)

incidents.csv:
    student_id (TEXT), exam_id (TEXT), timestamp (DATETIME),
    flag_type (TEXT), severity (INTEGER), evidence_path (TEXT)

transcripts.csv:
    lecture_id (TEXT), timestamp (DATETIME),
    chunk_text (TEXT), language (TEXT)

notifications.csv:
    student_id (TEXT), lecturer_id (TEXT), lecture_id (TEXT),
    reason (TEXT), created_at (DATETIME), read (INTEGER)
```

**R/Shiny reads these with `reactivePoll`** — it checks file modification time every 60 seconds. When mtime changes (i.e., after 02:00 export), it reloads the CSV and all dashboards update automatically without a page refresh.

---

## 7. Flow A — Roster Ingestion & Cold Start

**Purpose:** Before any live lecture can run, the system must know who is in the class. This flow populates `students.face_encoding` so the vision pipeline can perform identity matching.

**Actors:** Lecturer (Shiny UI), FastAPI `/roster/upload`, SQLite

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────┐
│  Shiny Lecturer │         │  FastAPI          │         │   SQLite    │
│  Submodule A    │         │  routers/roster.py│         │  students   │
└────────┬────────┘         └────────┬─────────┘         └──────┬──────┘
         │                          │                            │
 1. Lecturer selects                │                            │
    roster.csv + images.zip         │                            │
         │                          │                            │
 2. Shiny httr2:                    │                            │
    POST /roster/upload             │                            │
    multipart/form-data ──────────▶ │                            │
                                    │                            │
                          3. Parse roster.csv                    │
                             DictReader → rows                   │
                             For each row:                       │
                             IF student_id not in DB:            │
                               INSERT students(                  │
                                 student_id, name, email)  ────▶ │
                             COMMIT                              │
                                    │                            │
                          4. Unzip images.zip                    │
                             For each file in ZIP:               │
                               filename = "S01.jpg"              │
                               student_id = "S01"                │
                               Load image bytes                  │
                               face_recognition                  │
                               .face_encodings(image)            │
                                    │                            │
                          5. Encoding found?                     │
                             YES:                                │
                               enc.astype(np.float64).tobytes()  │
                               UPDATE students SET               │
                               face_encoding = <BLOB>      ────▶ │
                             NO:                                 │
                               Log warning, skip student         │
                               (face_encoding remains NULL)      │
                                    │                            │
                          6. Return response:                    │
                             {students_created: N,              │
                              encodings_saved: M}                │
                                    │                            │
         │◀───────────────────────── │                            │
 7. Shiny shows:                    │                            │
    "28 of 30 students encoded"     │                            │
    (2 students had no face found)  │                            │
```

**After this flow:** `load_student_encodings(db)` in `vision_pipeline.py` queries all rows where `face_encoding IS NOT NULL`. The pipeline now has a dictionary `{student_id → 128-dim numpy array}` for identity matching.

**Failure mode:** If `images.zip` contains a group photo or a blank image, `face_recognition.face_encodings()` returns an empty list. The row is skipped silently and logged. The lecturer must re-upload corrected images for those students via the same endpoint.

---

## 8. Flow B — The 5-Second Live Lecture Heartbeat

**Purpose:** The core live loop. Two concurrent processes run during every lecture — one handles vision, one handles audio. They are independent and do not share state except the SQLite session.

**Actors:** Lecturer (Shiny), FastAPI session router, Vision Thread (S1), Whisper Coroutine (S1), React Native clients

### 8.1 Session Initiation

```
Shiny: httr2 POST /session/start {lecture_id, lecturer_id, slide_url}
  │
  ▼
FastAPI session.py:
  a. INSERT INTO lectures (lecture_id, lecturer_id, title, start_time, slide_url)
  b. Broadcast WS to all clients: {type: "session:start", lecture_id, slide_url}
  c. threading.Thread(target=run_pipeline, args=(lecture_id, CAMERA_URL)).start()
  d. asyncio.create_task(stream_captions(lecture_id))
```

---

### 8.2 Thread 1 — Vision Pipeline (runs every 5 seconds)

```
Every 5 seconds:

┌─────────────────────────────────────────────────────────────────────┐
│  STEP 1: Capture Frame                                              │
│  cap = cv2.VideoCapture(CLASSROOM_CAMERA_URL)                       │
│  ret, frame = cap.read()                                            │
│  if not ret → break (camera disconnected)                           │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────┐
│  STEP 2: YOLOv8 Person Detection                                    │
│  results = yolo_model(frame, classes=[0], verbose=False)            │
│  boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)            │
│  Output: list of [x1, y1, x2, y2] bounding boxes                   │
│  Each box = one detected person in the crowd frame                  │
└─────────────────────────┬───────────────────────────────────────────┘
                          │  For each bounding box:
┌─────────────────────────▼───────────────────────────────────────────┐
│  STEP 3: Face Crop + Identity Match                                 │
│  roi = frame[y1:y2, x1:x2]                                         │
│  if roi.size == 0 → skip                                            │
│  rgb_roi = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)                     │
│  encs = face_recognition.face_encodings(rgb_roi)                   │
│  if not encs → skip (no face in this bounding box)                 │
│                                                                     │
│  distances = face_recognition.face_distance(known_encs, encs[0])   │
│  best_idx = argmin(distances)                                       │
│  if distances[best_idx] > 0.5 → student_id = "unknown" → skip      │
│  else → student_id = known_ids[best_idx]                            │
└─────────────────────────┬───────────────────────────────────────────┘
                          │  Student identified:
┌─────────────────────────▼───────────────────────────────────────────┐
│  STEP 4: HSEmotion Classification                                   │
│  raw_label, scores = hs_recognizer.predict_emotions(roi,            │
│                                                     logits=False)   │
│  raw_score = float(max(scores))                                     │
│                                                                     │
│  Emotion mapping (map_emotion):                                     │
│  "neutral"           → Focused                                      │
│  "happy" | "surprise"→ Engaged                                      │
│  "fear"              → Anxious                                      │
│  "anger" | "disgust" → Frustrated (if raw_score ≥ 0.65)            │
│                      → Confused   (if raw_score < 0.65)            │
│  "sad"               → Disengaged                                   │
│  _                   → Focused    (fallback)                        │
│                                                                     │
│  Fixed confidence lookup (get_confidence):                          │
│  Focused=1.00 | Engaged=0.85 | Confused=0.55                        │
│  Anxious=0.35 | Frustrated=0.25 | Disengaged=0.00                  │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────┐
│  STEP 5: SQLite Write                                               │
│  db.add(EmotionLog(                                                 │
│      student_id=student_id, lecture_id=lecture_id,                 │
│      timestamp=datetime.utcnow(), emotion=emotion,                  │
│      confidence=confidence, engagement_score=confidence))           │
│                                                                     │
│  if student_id not in seen_today:                                   │
│      seen_today.add(student_id)                                     │
│      db.add(AttendanceLog(student_id, lecture_id,                   │
│                           status="Present", method="AI"))           │
│  db.commit()                                                        │
└─────────────────────────────────────────────────────────────────────┘
                          │
                    time.sleep(5)
                    → repeat from STEP 1
```

---

### 8.3 Coroutine — Whisper Audio Pipeline (runs every 5 seconds, independently)

```
Every 5 seconds:

STEP 1: Capture 5s audio chunk
  audio = sd.rec(5 * 16000, samplerate=16000, channels=1, dtype="int16")
  sd.wait()
  → numpy array shape (80000, 1)

STEP 2: Encode to WAV bytes (in-memory, no disk write)
  buf = io.BytesIO()
  wave.open(buf) → write PCM frames
  buf.seek(0)
  buf.name = "audio.wav"   # required by OpenAI SDK

STEP 3: Whisper API call
  response = openai_client.audio.transcriptions.create(
      model="whisper-1",
      file=buf,
      # No language parameter — Whisper auto-detects ar-EG / en-US per chunk
  )
  text = response.text.strip()
  if not text → skip (silence or below threshold)

STEP 4: Write to transcripts table
  db.add(Transcript(lecture_id=lecture_id, chunk_text=text, language="mixed"))
  db.commit()

STEP 5: Broadcast to all WebSocket clients
  payload = {
      "type": "caption",
      "text": text,
      "lecture_id": lecture_id,
      "timestamp": datetime.utcnow().isoformat() + "Z",
      "language": "mixed"
  }
  for ws in active_connections:
      await ws.send_json(payload)

→ React Native CaptionBar displays text for 4 seconds, then fades
→ await asyncio.sleep(0)  # yield to event loop, repeat
```

---

### 8.4 React Native Side — AppState Focus Strike

```
AppState.addEventListener('change', (nextState) => {
    if (nextState !== 'active' && focusActive) {
        // App went to background (home button, notification, call)
        socket.emit({
            type: "focus_strike",
            student_id: studentId,
            lecture_id: activeLectureId,
            strike_type: "app_background",
            timestamp: new Date().toISOString()
        })
        setStrikes(s => s + 1)
    }
})

FastAPI receives → INSERT INTO focus_strikes (student_id, lecture_id, strike_type)
```

---

### 8.5 R/Shiny Live Dashboard (reads from FastAPI, not SQLite)

```
reactiveTimer(10000)  →  every 10 seconds:
  httr2 GET /emotion/live?lecture_id=L1&limit=60
  → Returns last 60 emotion_log rows as JSON
  → Shiny recomputes D1–D7 panels

Confusion observer:
  httr2 GET /emotion/confusion-rate?lecture_id=L1&window=120
  confusion_rate = response$confusion_rate
  if confusion_rate >= 0.40 → trigger State 3 (see Flow C)
```

---

## 9. Flow C — The Gemini AI Intervention Trigger

**Purpose:** When the class confusion rate crosses 40% over the last 2 minutes, the system auto-generates a clarifying question from the current lecture slide content and presents it to the Lecturer.

**Actors:** R/Shiny observer, FastAPI `/gemini/question`, Gemini 1.5 Flash API, Lecturer, React Native clients

```
┌──────────────────┐     ┌──────────────────┐     ┌────────────────┐     ┌──────────────────┐
│  Shiny Observer  │     │  FastAPI          │     │  Gemini API    │     │  React Native    │
│  (10s interval)  │     │  gemini.py        │     │  1.5 Flash     │     │  Students        │
└────────┬─────────┘     └────────┬─────────┘     └───────┬────────┘     └────────┬─────────┘
         │                        │                        │                        │
 1. reactiveTimer fires           │                        │                        │
    GET /emotion/confusion-rate   │                        │                        │
    ?lecture_id=L1&window=120 ──▶ │                        │                        │
                                  │                        │                        │
                       2. Query emotion_log:               │                        │
                          SELECT emotion FROM emotion_log  │                        │
                          WHERE lecture_id='L1'            │                        │
                          AND timestamp >= NOW()-120s      │                        │
                          confusion_rate =                 │                        │
                          COUNT(emotion='Confused')/COUNT(*)                        │
                          Return: {"confusion_rate": 0.42} │                        │
         │◀────────────────────── │                        │                        │
 3. confusion_rate >= 0.40                                 │                        │
    Shiny fires once (debounced,                           │                        │
    not every poll):                                       │                        │
    POST /gemini/question                                  │                        │
    {"lecture_id": "L1"} ───────▶ │                        │                        │
                                  │                        │                        │
                       4. Fetch slide_url from lectures    │                        │
                          SELECT slide_url FROM lectures   │                        │
                          WHERE lecture_id='L1'            │                        │
                          → "https://drive.google.com/..." │                        │
                                  │                        │                        │
                       5. Extract slide text               │                        │
                          pdfplumber.open(slide_url)       │                        │
                          → page text string               │                        │
                                  │                        │                        │
                       6. Call Gemini:                     │                        │
                          generate_fresh_brainer(slide_text)──▶                    │
                          Prompt:                          │  "Based on this        │
                          "Generate ONE clarifying         │   content..."          │
                           question (≤2 sentences)..." ──▶ │                        │
                                                           │ Generate question      │
                          ◀──────────────────────────────── │                        │
                       7. Return to Shiny:                 │                        │
                          {"question": "Can you explain    │                        │
                            why we use Big O...?"}         │                        │
         │◀────────────────────── │                        │                        │
 8. shinyalert popup:             │                        │                        │
    "⚠ 42% confusion rate"        │                        │                        │
    "Suggested: Can you explain   │                        │                        │
     why we use Big O...?"        │                        │                        │
    [Ask It] [Dismiss]            │                        │                        │
         │                        │                        │                        │
 9. Lecturer clicks "Ask It":     │                        │                        │
    POST /session/broadcast       │                        │                        │
    {"event": "freshbrainer",     │                        │                        │
     "question": "Can you..."} ──▶│                        │                        │
                                  │                        │                        │
                       10. Broadcast WS to all clients:    │                        │
                           {"type":"freshbrainer",         │                        │
                            "question":"Can you..."} ─────────────────────────────▶│
                                  │                        │              11. Bottom-sheet overlay
                                  │                        │                  appears on student
                                  │                        │                  device with question
```

**Debounce rule:** The confusion observer sets a reactive flag `alert_sent <- reactiveVal(FALSE)`. Once an alert fires, the flag is set to TRUE and no further alerts are triggered for that lecture unless the lecturer dismisses and manually resets it (via a "Reset Alert" button). This prevents spam.

---

## 10. Flow D — The Nightly Data Handoff

**Purpose:** Transfer all live lecture data from SQLite into static CSV files so R/Shiny analytics dashboards can read it safely without touching the live database.

**Actor:** APScheduler (runs inside FastAPI process), `export_service.py`

```
02:00:00 UTC — APScheduler fires export_all()

┌──────────────────────────────────────────────────────────────────────┐
│  export_service.py                                                   │
│                                                                      │
│  db = SessionLocal()                                                 │
│                                                                      │
│  queries = {                                                         │
│      "emotions":                                                     │
│        SELECT student_id, lecture_id, timestamp,                    │
│               emotion, confidence, engagement_score                  │
│        FROM emotion_log                                              │
│                                                                      │
│      "attendance":                                                   │
│        SELECT student_id, lecture_id, timestamp,                    │
│               status, method                                         │
│        FROM attendance_log                                           │
│                                                                      │
│      "materials":                                                    │
│        SELECT material_id, lecture_id, lecturer_id,                 │
│               title, drive_link, uploaded_at                        │
│        FROM materials                                                │
│                                                                      │
│      "incidents":                                                    │
│        SELECT student_id, exam_id, timestamp,                       │
│               flag_type, severity, evidence_path                    │
│        FROM incidents                                                │
│                                                                      │
│      "transcripts":                                                  │
│        SELECT lecture_id, timestamp, chunk_text, language           │
│        FROM transcripts                                              │
│                                                                      │
│      "notifications":                                                │
│        SELECT student_id, lecturer_id, lecture_id,                  │
│               reason, created_at, read                              │
│        FROM notifications                                            │
│  }                                                                   │
│                                                                      │
│  For each (name, query):                                             │
│      df = pd.read_sql(query, db.bind)                                │
│      df.to_csv(f"data/exports/{name}.csv", index=False)             │
│      # Atomic write — overwrites the entire file                     │
│                                                                      │
│  db.close()                                                          │
└──────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
               data/exports/ mtime updated
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│  R/Shiny reactivePoll (checks mtime every 60s)                       │
│                                                                      │
│  pollCSV <- reactivePoll(                                            │
│    intervalMillis = 60000,                                           │
│    checkFunc = function() {                                          │
│      file.info("data/exports/emotions.csv")$mtime                   │
│    },                                                                │
│    valueFunc = function() {                                          │
│      read.csv("data/exports/emotions.csv")                          │
│    }                                                                 │
│  )                                                                   │
│  → All dashboards re-render with today's data                        │
└──────────────────────────────────────────────────────────────────────┘
```

**Why full overwrite (not append):** The export always dumps the entire table so the CSV is always a complete, consistent snapshot. Appending is error-prone if the process crashes mid-write.

**SQLite is NOT cleared:** The live database is never truncated. Historical data accumulates in SQLite throughout the semester. Only the CSV snapshot is refreshed.

---

## 11. Edge Case Handling & Fail-Safes

### 11.1 Occlusion / Lost Face Tracking

**Problem:** A student sits behind a tall classmate, lowers their head, or moves out of the camera FOV. YOLO may still detect a bounding box (the body), but `face_recognition.face_encodings()` returns an empty list.

**Behaviour:**
```
if not encs:
    continue  # skip this bounding box entirely
```

**What is NOT written to the database:** No row is inserted for that student in that 5-second cycle. There is no `NULL` emotion row, no `Absent` attendance row. The gap is simply absent from `emotion_log`.

**Why this is correct:**
- Inserting a NULL emotion would contaminate the `mean(engagement_score)` calculation in R.
- Inserting `Absent` would be misleading — the student is present but occluded.
- R's `compute_engagement()` uses `mean()` which naturally ignores missing cycles. Fewer observations is correct — it does not bias the score.

**Attendance:** A student is only marked `Absent` via manual override by the Lecturer. AI never writes `Absent`. If the vision pipeline never detects a student during the entire lecture, they simply have no `attendance_log` row for that session. The Attendance submodule shows them as undetected, and the Lecturer can manually set their status.

---

### 11.2 Camera RTSP Stream Drop

**Problem:** The classroom IP camera loses connection mid-lecture (power outage, network issue).

**Detection:**
```python
ret, frame = cap.read()
if not ret:
    break  # exits the while loop
```

**Recovery:**
```python
def run_pipeline(lecture_id: str, camera_url: str):
    retry_count = 0
    while retry_count < 5:
        cap = cv2.VideoCapture(camera_url)
        if not cap.isOpened():
            retry_count += 1
            time.sleep(10)
            continue

        while True:
            ret, frame = cap.read()
            if not ret:
                break  # inner loop exits, outer loop retries
            ...process frame...

        cap.release()
        retry_count += 1
        time.sleep(10)

    # After 5 retries, log error and exit thread
    print(f"[VISION] Camera unreachable after 5 retries for lecture {lecture_id}")
```

**What the Lecturer sees:** No emotion data appears in the live dashboard after the drop. The dashboard shows the last known state (stale data from the last 60-row fetch). No error notification is currently surfaced to the Lecturer — S3 should add a health endpoint or log streaming for Phase 4.

---

### 11.3 React Native Network Drop (Wi-Fi Loss)

**Problem:** AAST campus Wi-Fi is unstable. A student's app loses connection while in focus mode. If they switch apps while offline, the strike cannot be sent.

**Behaviour — Strike Caching:**
```typescript
// In services/api.ts
const pendingStrikes: Strike[] = []

function emitStrike(payload: Strike) {
    if (socket.connected) {
        socket.emit('focus_strike', payload)
    } else {
        // Cache locally in memory
        pendingStrikes.push(payload)
    }
}

socket.on('connect', () => {
    // Drain the pending queue on reconnect
    while (pendingStrikes.length > 0) {
        socket.emit('focus_strike', pendingStrikes.shift())
    }
})
```

**Limitation:** Pending strikes are stored in-memory only (not AsyncStorage). If the app is killed while offline, the pending strikes are lost. This is an acceptable trade-off for v1 — the AppState mechanism is a deterrent, not a forensic record.

**Strike counter UI:** The in-app counter (`setStrikes(s => s + 1)`) increments locally even when offline, so the student sees the correct count regardless of connectivity.

---

### 11.4 Whisper API Failure

**Problem:** OpenAI API returns an error (rate limit, timeout, network issue).

**Behaviour:**
```python
try:
    response = openai_client.audio.transcriptions.create(
        model="whisper-1",
        file=wav_buf,
    )
    text = response.text.strip()
    if not text:
        continue
    ...
except Exception as e:
    print(f"[WHISPER] Error: {e}")
    continue  # silently skip this 5-second chunk
```

**What students see:** The CaptionBar shows nothing for that 5-second window. The next successful chunk will display normally. No error is pushed to the client.

**What is NOT written:** No empty row is inserted into `transcripts`. Only successful, non-empty transcriptions are saved.

---

### 11.5 APScheduler Export Failure

**Problem:** The nightly 02:00 export job crashes mid-run (disk full, DB locked).

**Behaviour:** The partially written CSV is left in an inconsistent state. R/Shiny will read the incomplete file on the next mtime check.

**Mitigation:** Write to a temp file, then atomically rename:
```python
import os, tempfile

for name, query in queries.items():
    df = pd.read_sql(query, db.bind)
    tmp = f"{EXPORT_DIR}/{name}.tmp.csv"
    final = f"{EXPORT_DIR}/{name}.csv"
    df.to_csv(tmp, index=False)
    os.replace(tmp, final)  # atomic on POSIX; best-effort on Windows
```

`os.replace()` is atomic on Linux (Railway.app runs Linux) — the CSV is either fully written or not replaced at all.

---

### 11.6 HSEmotion Model Exception

**Problem:** HSEmotion `predict_emotions()` throws on a malformed or very small ROI (edge-case face crops from YOLO).

**Behaviour:**
```python
try:
    raw_label, scores = hs_recognizer.predict_emotions(roi, logits=False)
    raw_score = float(max(scores))
    emotion = map_emotion(raw_label, raw_score)
    confidence = get_confidence(emotion)
except Exception:
    continue  # skip this student in this frame cycle
```

No row is written. The exception is silently swallowed per-student per-frame. This is intentional — one bad crop must not crash the entire lecture pipeline.

---

*End of ARCHITECTURE.md*
