# AAST Classroom Emotion Intelligence System — Full Demo Script

> **Credentials**
> | Role | User ID | Password |
> |---|---|---|
> | Admin | `omar` | `aast2026` |
> | Lecturer | `mohamedfathy` | `aast2026` |
> | Student | `231006131` | `aast2026` |
>
> **Best class for live demo with real data:** `CLASS_2029` — [EBA3201] Advanced Statistics (lecturer: `omar`)
> **Best lecture for showing analytics:** `LEC_2029_1` — 194 emotion readings, 24 students, all 6 emotion states captured

---

## What Is This System?

The AAST Classroom Emotion Intelligence System is an AI-powered Learning Management Platform built for Arab Academy for Science, Technology and Maritime Transport. A single fixed classroom camera automatically identifies every enrolled student, analyzes their emotional state in real time, and streams results into a live dashboard — with zero interaction required from students.

**Three interfaces:**
- **Web portal** (R/Shiny) — Admin and Lecturer
- **Mobile app** (React Native / Expo) — Student only
- **Python FastAPI backend** — AI engine, REST API, WebSocket server

**What's live in production right now:**
- **121 students** enrolled across 6 real AAST courses — 115 with face encodings stored
- **5 completed lecture sessions** with real emotion data captured from a live camera:
  - LEC_2029_1 — Advanced Statistics: **194 emotions**, 24 students
  - LEC_10227_1 — System Modeling & Simulation: 186 emotions, 23 students
  - LEC_10230_1 — Computing Algorithms: 173 emotions, 21 students
  - LEC_10232_1 — Computer Graphics: 176 emotions, 21 students
  - LEC_1523_1 — Numerical Methods: 164 emotions, 21 students
- **100 enrollments** across those courses

---

## Part 1 — Admin: System Setup

> Open the Shiny portal. The login page shows the AAST campus photo.

**Login:** `omar` / `aast2026`

---

### Overview Tab

Three live counters at the top — total students, lecturers, and courses in the system. Below: a recent attendance table and a global emotion distribution chart aggregated across all sessions ever run.

> "At a glance, the admin sees the health of the entire institution — real numbers from real sessions."

---

### User Management — Manage Admins

> Go to: **Manage Admins**

Admin accounts are created here. The `omar` account you're logged in with was created through this panel. Admins can add, edit, or delete other admin users.

---

### User Management — Manage Lecturers

> Go to: **Manage Lecturers**

Lecturer accounts live here. Each has an ID, name, AAST email, and department. The table on the right shows all faculty. Click any row to edit.

> "Mohamed Fathy is registered here as a lecturer. His ID is `mohamedfathy`, assigned to the Advanced Statistics class."

---

### User Management — Manage Students

> Go to: **Manage Students**

Students are registered with their 9-digit AAST registration number. When a face photo is uploaded here, the system runs **InsightFace ArcFace** on it server-side — generating a 512-dimensional face embedding stored as binary in the database. This is what the camera uses to identify students in real time.

> "115 of our 121 students already have face embeddings stored. The other 6 have no photo uploaded yet."

---

### Academic Structure — Course Manager

> Go to: **Course Manager**

Six real AAST courses are loaded: Numerical Methods, System Modeling & Simulation, Computing Algorithms, Computer Graphics, Professional Training in AI, and Advanced Statistics. These were imported directly from the university's course catalog.

---

### Academic Structure — Class & Sections

> Go to: **Class & Sections**

Each class is a section of a course with an assigned lecturer. `CLASS_2029` is the Advanced Statistics section assigned to `omar`. This is the class with the richest live data.

> "The class is the key unit — it links a course to a lecturer to a set of enrolled students. The vision pipeline always runs against a class."

---

### Enrollment

> Go to: **Enrollment**

Only enrolled students are tracked by the camera. There are 100 enrollments across the 6 classes. Students can be enrolled one by one or bulk-pasted as comma-separated IDs.

> "If a student is not enrolled, the camera detects their face but marks them as unknown. Enrollment is the gate."

---

### Analytics

> Go to: **Engagement Log**

Three charts: engagement score over time, average engagement per lecture, emotion variation across sessions — aggregated across the entire institution.

> Go to: **Emotion Analysis**

Emotion distribution pie, engagement timeline, per-lecture emotion counts, and two K-means cluster scatter plots — one clustering lecturers by effectiveness, one clustering students by subject-level engagement.

> Go to: **Incident Audit**

Full log of all proctoring incidents across all exams — phone detected, identity mismatch, absent, head rotation — with severity, student, and timestamp.

---

**Logout**

---

## Part 2 — Lecturer: Live Lecture

**Login:** `mohamedfathy` / `aast2026` *(or `omar` to see the real historical data)*

> If demoing with real historical data, log in as `omar` — all 5 completed sessions belong to their classes.

---

### My Classes

The home screen shows all classes assigned to this lecturer. Each row has two action buttons: jump to Reports (attendance history) or jump to Live Dashboard.

---

### Live Dashboard — Starting a Lecture

> Go to: **Live Dashboard** → select course → select class → click Start Lecture

The selector bar at the top lets the lecturer pick course, class section, and academic week. Then two columns:

**Left column:**
- **Live AI Video Stream** — camera preview with a canvas overlay. Bounding boxes drawn over every detected face. Green box = enrolled student identified by name. Orange = face detected but not enrolled. Each box shows student name + current emotion label.
- **Live Attendance Grid** — photo cards per enrolled student. Green border = present (identified by camera). Red border = absent.

**Right column:**
- **Class Engagement gauge** — real-time dial, 0 to 1
- **Live Sentiment Ticker** — scrolling feed of the latest emotion detections
- **AI Interventions panel** — confusion alert + Fresh Brainer trigger

> Click **Start Lecture**. This creates the lecture record in the DB, starts the vision pipeline thread, and broadcasts `session:start` via WebSocket to all connected student phones.

---

### The Vision Pipeline — What Actually Happens

The pipeline is running on the local machine where the camera is connected. Here is the exact sequence:

**Every frame (~30fps):**
- Camera frame captured via OpenCV
- Frame encoded as JPEG and pushed to the shared stream state (for the live video feed in the dashboard)

**Every 5 frames:**
- **YOLOv8n person detection** — bounding boxes around every person in the frame

**For each detected person:**
- **YOLOv8n-face** — runs on the person crop to get a tight face bounding box

**Every 20 frames (face recognition pass):**
- **InsightFace ArcFace ONNX** (`buffalo_sc`) — extracts a 512-dimensional embedding from the face crop
- **Cosine similarity** compared against all 115 stored student embeddings
- If best similarity ≥ 0.60 → student identified
- First identification in the session → `AttendanceLog` row written (method: FACE), snapshot saved to `data/snapshots/{lecture_id}/{student_id}.jpg`

**Every 30 frames (emotion pass) — identified students only:**
- **HSEmotion `enet_b0_8_best_afew`** — trained on AffectNet (450K+ annotated face images)
- Returns a dictionary of softmax probabilities for 8 raw emotion classes
- The class with the highest probability is taken as the label
- That probability score is stored directly as both `confidence` and `engagement_score`
- One `EmotionLog` row written per identified student per 30-frame cycle

> "The confidence value is the model's actual softmax score — so a student reading as 0.97 Focused is a very strong signal. A student at 0.45 Confused is borderline. The score is honest."

**Raw HSEmotion → educational state mapping used in the UI:**

| HSEmotion label | Educational state shown |
|---|---|
| neutral | Focused |
| happy, surprise | Engaged |
| fear | Anxious |
| anger, disgust (low score) | Confused |
| anger, disgust (high score) | Frustrated |
| sad | Disengaged |

**Real data from LEC_2029_1 (Advanced Statistics, 24 students):**
- Focused: 82 readings (42%)
- Engaged: 61 readings (31%)
- Disengaged: 17 readings (9%)
- Frustrated: 16 readings (8%)
- Confused: 10 readings (5%)
- Anxious: 8 readings (4%)

---

### The 7 Live Dashboard Panels

**D1 — Engagement Gauge**
Dial 0 to 1. Value = mean confidence score of the last 60 emotion readings. Red < 0.25 (critical), amber 0.25–0.45, green > 0.45.

**D2 — Emotion Timeline**
Line chart with 6 lines, one per emotional state. X = time in 2-minute buckets, Y = % of class in that state. Shows the lecturer exactly when confusion started.

**D3 — Cognitive Load Indicator**
`cognitive_load = confusion_rate + frustration_rate`. Green < 0.30, amber 0.30–0.50, red > 0.50 → "Overloaded — slow down".

**D4 — Class Valence Meter**
Horizontal gauge -1 to +1. `valence = (focused + engaged) - (frustrated + disengaged + anxious)`. Negative for 5 consecutive readings → warning.

**D5 — Per-Student Emotion Heatmap**
Grid, row = student, column = 5-min segment, fill = dominant emotion. Dark green = Focused, green = Engaged, amber = Confused, orange = Frustrated, purple = Anxious, red = Disengaged.

**D6 — Persistent Struggle Alert Table**
Students Confused or Frustrated for ≥ 3 consecutive readings. Columns: Student, Emotion, Duration, Consecutive Count.

**D7 — Peak Confusion Moment Detector**
Value box: "Most confusing moment: 10:42 AM" — the 2-minute window with the highest `confusion + frustration` rate. Shown after the session ends.

---

### AI Intervention — Fresh Brainer

When confusion rate ≥ 40% for 2 consecutive minutes, Gemini 1.5 Flash is triggered automatically.

> Or click **Ask AI (from materials)** to trigger manually.

The system:
1. Fetches the lecture's uploaded PDF slides from the database
2. Extracts slide text with pdfplumber
3. Calls Gemini 1.5 Flash: *"Generate ONE clarifying question under 2 sentences to help confused students refocus"*
4. Returns the question as a popup in the Shiny UI

Popup shows the confusion rate, the question, and two buttons: **Ask it** / **Dismiss**.

Clicking **Ask it** broadcasts the question via WebSocket → every connected student phone gets it as an overlay immediately.

---

### QR Attendance

A QR code is available below the gauge panel. Students who are not in the camera frame can scan it with the mobile app to mark themselves present as a manual fallback.

---

### Ending the Lecture

> Click **End Lecture**

Sets lecture status to `ended`, stops the pipeline thread, clears the frame buffer, broadcasts `session:end` to all phones. Student Focus Mode releases automatically.

---

## Part 3 — Student: Mobile App

> Open Expo Go and scan the dev QR, or open the installed APK.

**Login:** `231006131` / `aast2026`

---

### Home Screen

Shows a greeting, an active/upcoming lecture card for the student's enrolled class, and their last session engagement summary.

---

### Focus Mode

The active lecture screen. On entry:
- Connects to the WebSocket server
- If `session:start` is already live, Focus Mode activates immediately
- `AppState` listener starts — fires on any app backgrounding

> **Press the home button on the phone.**

The `AppState` API fires instantly. The app sends:
```json
{ "type": "focus_strike", "student_id": "231006131",
  "lecture_id": "...", "strike_type": "app_background" }
```
The backend writes it to `focus_strikes`. The strike counter on screen increments.

> "Three strikes alerts the lecturer. No OS locks — just the AppState listener. The system trusts the student to stay."

---

### Fresh Brainer Overlay

When the lecturer sends the AI question, it appears on every connected student's phone as a bottom-sheet overlay — no action needed from the student. Read it, refocus.

---

## Part 4 — Exam Proctoring

> Shiny portal, logged in as lecturer. Go to: **Exam Proctoring**

---

### Setup

Select course → class → enter exam title (e.g. `Midterm Exam`) → click **Start Exam**.

This creates an exam record, broadcasts `exam:start` to all connected phones (students' apps navigate to the exam screen automatically), and starts the vision pipeline in `exam` context — same pipeline as a lecture but with the ProctorService layer active.

---

### What the Camera Watches For

The same YOLO + ArcFace + HSEmotion pipeline runs, plus:

| Detection | Method | Flag | Severity |
|---|---|---|---|
| Phone on desk | YOLOv8 COCO class 67 (cell phone) in person ROI | `phone_on_desk` | 3 |
| Student absent | No face for the student for > 5s | `absent` | 3 |
| Multiple people in frame | YOLO person count > 1 | `multiple_persons` | 3 |
| Head rotation | MediaPipe FaceMesh — yaw/pitch from 468 facial landmarks | `head_rotation` | 2 |
| Identity mismatch | ArcFace cosine similarity < 0.60 for enrolled student | `identity_mismatch` | 3 |
| App goes to background | React Native AppState | `app_background` | 1 |

All incidents saved to `incidents` table with screenshot in `data/evidence/`.

---

### Head Rotation Flag

> Look sharply sideways while in view of the camera.

MediaPipe FaceMesh puts 468 3D landmarks on the face. The pipeline computes the yaw and pitch angles. An extreme rotation triggers `head_rotation` at Severity 2 — appears in the Live Incident Log within the next 30-frame cycle (~1 second).

---

### Auto-Submit Rule

**3 × Severity-3 incidents in any rolling 10-minute window** → system calls `POST /exam/submit` automatically with reason `auto-submit: 3+ high-severity incidents`. WebSocket broadcasts `exam:autosubmit` to the student's phone — they see a "Submitted" screen. No lecturer action needed.

---

### End Exam

> Click **End Exam**

Closes the exam record, stops the pipeline. All incidents remain for the admin's Incident Audit.

---

## Part 5 — Reports & Analytics

> Lecturer sidebar → **Reports & Analytics**

Select course → class → a completed session.

**Per-session charts:**
1. **Emotion Frequency** — pie chart of emotion distribution for that session
2. **Engagement Timeline** — average engagement score minute by minute across the session
3. **Attendance Summary** — every enrolled student, attendance status, method (FACE / QR / Manual)
4. **Student Performance Clusters** — K-means scatter of students by engagement score vs cognitive load

**Cross-session charts (whole class history):**
5. **Engagement Trend Across Sessions** — class average engagement week by week
6. **Emotion Variation Across Sessions** — stacked bar, each bar = one lecture, segments = emotion proportions
7. **Per-Student Summary** — table with each student's average engagement, dominant emotion, cognitive load across all sessions

> "For Advanced Statistics (`CLASS_2029`), we have 5 sessions of real data. The cross-session trend shows how the class evolved over those weeks."

---

## Part 6 — Materials

> Lecturer sidebar → **LMS Materials**

Select course, class, and week → upload a PDF. The file is stored and linked to the lecture record. When an AI intervention triggers, this is the PDF Gemini reads to generate the question.

---

## System Architecture Summary

```
Classroom Camera (USB / RTSP)
        |
        v
Vision Pipeline  (python-api/services/vision_pipeline.py)
  Every frame   → OpenCV capture → JPEG stream state
  Every 5 frames  → YOLOv8n person detection
  Every 20 frames → InsightFace ArcFace ONNX (512-dim)
                    Cosine similarity >= 0.60 → student identified
                    AttendanceLog written on first detection
  Every 30 frames → HSEmotion enet_b0_8_best_afew
                    Softmax score → EmotionLog written
  Exam context    → ProctorService: phone / absent / rotation / mismatch
        |
        v
PostgreSQL Database (DigitalOcean Managed)
  emotion_log, attendance_log, focus_strikes, incidents, lectures
        |
      /   \
     v     v
Shiny Portal              React Native App
(Admin + Lecturer)        (Student)
  - Live dashboard          - Focus Mode + AppState strikes
  - Exam proctoring         - Fresh Brainer overlay
  - Reports + K-means       - QR attendance
  - User/course/enrollment  - Session notifications

Both connected via:
  REST  → FastAPI on DigitalOcean App Platform
  WS    → /session/ws (session:start/end, freshbrainer, exam:start/autosubmit)
```

**Tech stack:**

| Layer | Technology |
|---|---|
| Backend API | Python 3.11, FastAPI, SQLAlchemy, PostgreSQL |
| Face detection | InsightFace `buffalo_sc` — RetinaFace + ArcFace ONNX (512-dim, CPU) |
| Person / phone detection | YOLOv8n (Ultralytics) |
| Emotion classification | HSEmotion `enet_b0_8_best_afew` (AffectNet, 450K images) |
| Head posture | MediaPipe FaceMesh (468 landmarks) |
| AI intervention | Gemini 1.5 Flash (Google AI Studio) |
| Web portal | R 4.3, Shiny, shinydashboard, plotly, DT |
| Mobile app | React Native + Expo, Zustand, WebSocket |
| Hosting | DigitalOcean App Platform + Managed PostgreSQL |

---

## Production Data Reference

| Lecture ID | Course | Emotions | Students | Status |
|---|---|---|---|---|
| LEC_2029_1 | [EBA3201] Advanced Statistics | 194 | 24 | ended |
| LEC_10227_1 | [CCS3003] System Modeling & Simulation | 186 | 23 | ended |
| LEC_10230_1 | [CCS3403] Computing Algorithms | 173 | 21 | ended |
| LEC_10232_1 | [CCS3501] Computer Graphics | 176 | 21 | ended |
| LEC_1523_1 | [CCS3002] Numerical Methods | 164 | 21 | ended |

**Emotion breakdown — LEC_2029_1 (Advanced Statistics):**
- Focused: 82 (42%) — students actively processing
- Engaged: 61 (31%) — positive affect
- Disengaged: 17 (9%) — withdrawn
- Frustrated: 16 (8%) — blocked
- Confused: 10 (5%) — struggling
- Anxious: 8 (4%) — stressed

**Face encodings:** 115 / 121 students have 512-dim ArcFace embeddings stored

---

## Credentials Reference

| Role | User ID | Password | Assigned to |
|---|---|---|---|
| Admin | `omar` | `aast2026` | All 6 real courses |
| Admin (system) | `admin` | `aast2026` | Root account |
| Lecturer | `mohamedfathy` | `aast2026` | STAT401-A (demo class) |
| Student | `231006131` | `aast2026` | Enrolled in STAT401-A |

> To demo with **real historical data**, use **`omar`** as the lecturer — their classes (`CLASS_2029`, `CLASS_10227`, etc.) contain the 5 completed sessions.
> To demo **live lecture start + exam from scratch**, use **`mohamedfathy`** → `STAT401-A`.
