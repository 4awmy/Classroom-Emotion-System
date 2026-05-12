# AAST Classroom Emotion Intelligence System — Full Demo Script

> **Credentials**
> | Role | User ID | Password |
> |---|---|---|
> | Admin | `omar` | `aast2026` |
> | Lecturer | `mohamedfathy` | `aast2026` |
> | Student | `231006131` | `aast2026` |
> | Course | `STAT401` — Advanced Statistics | Class: `STAT401-A` |

---

## What Is This System?

The AAST Classroom Emotion Intelligence System is an AI-powered Learning Management Platform built for Arab Academy for Science, Technology and Maritime Transport. It uses a single fixed classroom camera to automatically identify every enrolled student in the room, analyze their emotional state in real time, and feed that data into a live dashboard for the lecturer — all without any interaction from the students themselves.

The system has three interfaces:

- **Web portal** (R/Shiny) — for Admins and Lecturers
- **Mobile app** (React Native / Expo) — for Students
- **Python FastAPI backend** — the AI engine connecting both

The AI pipeline runs every 5 seconds: YOLOv8 detects every person in the crowd frame, `face_recognition` identifies which enrolled student each person is, and HSEmotion classifies their facial expression into one of six educational states — Focused, Engaged, Confused, Anxious, Frustrated, or Disengaged. Every result is stored live in the database and pushed to the lecturer's dashboard in real time.

---

## Part 1 — Admin: System Setup

> Open the Shiny portal. The login page shows the AAST campus with the system name.

**Login:** `omar` / `aast2026`

You land on the Admin dashboard. This is the system control center.

---

### Overview Tab

The overview shows three live counters at the top — total students, lecturers, and courses registered in the system. Below that is a recent attendance table and a global emotion distribution chart that aggregates emotion data across all lectures ever run.

> "At a glance, the admin can see the health of the entire institution."

---

### User Management — Manage Lecturers

> Go to: **Manage Lecturers**

This is where lecturer accounts are created. The form on the left takes a Lecturer ID, name, AAST email, department, and password. Click Save and the account is live immediately — the lecturer can log in from the same portal.

The table on the right shows the full faculty roster. Click any row to load their details into the form for editing.

> "We've pre-created Mohamed Fathy as our demo lecturer. His ID is `mohamedfathy`."

---

### User Management — Manage Students

> Go to: **Manage Students**

Same pattern — the admin creates student accounts with their 9-digit AAST registration number, name, email, and optionally uploads a face photo. The face photo is processed server-side by the ArcFace model to extract a 512-dimensional face embedding, which is stored in the database and used by the vision pipeline for identification.

> "Student 231006131 is already registered. You can see their record in the table."

---

### Academic Structure — Course Manager

> Go to: **Course Manager**

Courses are the top-level academic units. We've created **STAT401 — Advanced Statistics**.

---

### Academic Structure — Class & Sections

> Go to: **Class & Sections**

A class is a section of a course — it's the unit that the vision pipeline tracks. Each class has a course, a lecturer, and a section name. **STAT401-A** is assigned to Mohamed Fathy.

> "This is the critical link — the class ties the course to the lecturer. When a lecture starts for STAT401-A, the AI knows which enrolled students to look for."

---

### Enrollment

> Go to: **Enrollment**

Only enrolled students are tracked by the camera. The admin enrolls students one by one or bulk-pastes a comma-separated list of IDs.

Student **231006131** is enrolled in **STAT401-A**.

> "If a student is not enrolled, the camera will detect a face but mark it as unknown. Enrollment is the gate."

---

### Analytics (Admin-Side)

> Go to: **Engagement Log**

Three charts here: engagement score over time across all lectures, average engagement per lecture, and emotion variation across sessions. All of this is aggregated across the whole institution.

> Go to: **Emotion Analysis**

An emotion distribution pie chart, an engagement timeline, a table of emotion counts per lecture, and two K-means cluster maps — one clustering lecturers by their effectiveness and engagement variance, and one clustering students by their subject-level performance.

> "The K-means plots show the admin which lecturers are consistently high-performing, which are mid-range, and which need support — without anyone having to write a single report."

> Go to: **Incident Audit**

A full log of every proctoring incident across all exams — phone detected, identity mismatch, absent, head rotation — with severity, student ID, and timestamp. The admin sees everything.

---

**Logout** (top-right, gold "Logout" link)

---

## Part 2 — Lecturer: Live Lecture

**Login:** `mohamedfathy` / `aast2026`

The lecturer lands on **My Classes** — a table showing all classes assigned to them. STAT401 / STAT401-A is listed with two action buttons: one for Attendance History and one for Live Dashboard.

---

### My Classes

> "The lecturer's home screen shows their assigned courses at a glance. Two actions per row — jump directly to the live dashboard or view historical reports."

---

### Live Dashboard — Starting a Lecture

> Go to: **Live Dashboard** (click the play button on STAT401-A, or go to the sidebar tab)

At the top of the Live Dashboard is a selector bar: choose the course, the class section, and the academic week. Below that is a two-column layout.

**Left column:**
- **Live AI Video Stream** — a camera preview with a canvas overlay. When auto-capture is running, the overlay draws bounding boxes around detected faces. Green boxes = enrolled students identified. Orange = face detected but not enrolled. Each box shows the student's name and current emotion label.
- **Live Attendance Grid** — photo cards for each enrolled student. Green border = present (detected by camera). Red border = absent.

**Right column:**
- **Class Engagement gauge** — a real-time dial showing the average engagement score from 0 to 1.
- **Live Sentiment Ticker** — a live scroll of the most recent emotion detections.
- **AI Interventions panel** — the confusion alert and the Fresh Brainer button.

> Now click **Start Lecture**. The button is in the session actions area below the video stream.

This does three things simultaneously:
1. Creates a lecture record in the database with status `live`
2. Spawns a background thread running the vision pipeline — camera opens, YOLO starts
3. Broadcasts a WebSocket event `session:start` to all connected mobile clients

> "The lecture is now live. Every 5 seconds, the system processes a frame — detecting, identifying, classifying. No one in the room knows this is happening beyond the camera being present."

The gauges and ticker begin updating. The attendance grid fills in as students are identified.

---

### The Vision Pipeline — What's Happening Behind the Scenes

Every 5 seconds:

1. **YOLO person detection** — draws bounding boxes around every person in the crowd frame
2. **face_recognition** — crops each person ROI, extracts a 128-dimensional face encoding, compares it against every enrolled student's stored encoding. Match within distance 0.5 → student identified
3. **YOLOv8 face detection** — runs on the identified person's ROI to get a tight face crop
4. **HSEmotion classification** — runs the face crop through the `enet_b0_8_best_afew` model trained on 450,000 labelled face images. Returns one of 8 raw emotions
5. **Emotion mapping** — maps the raw emotion to an educational state:
   - `neutral` → Focused (confidence 1.00)
   - `happy` / `surprise` → Engaged (0.85)
   - `fear` → Anxious (0.35)
   - `anger` / `disgust` at low intensity → Confused (0.55)
   - `anger` / `disgust` at high intensity → Frustrated (0.25)
   - `sad` → Disengaged (0.00)
6. **Database write** — one row to `emotion_log` and one to `attendance_log` (first detection only)
7. **WebSocket broadcast** — updated emotion data pushed to the dashboard

The confidence values are fixed by design — they are not taken from the model's softmax output. This makes the engagement score academically reproducible and defensible.

---

### The 7 Live Dashboard Panels

**D1 — Engagement Gauge**
A dial from 0 to 1. The value is the mean engagement score of the last 60 emotion readings across all students. Red below 0.25 (critical), amber 0.25–0.45, green above 0.45.

**D2 — Emotion Timeline**
A line chart with 6 lines — one per emotion state. X-axis is time bucketed into 2-minute windows, Y-axis is percentage of the class in that state. This shows the lecturer exactly when the class started to lose focus or get confused during the session.

**D3 — Cognitive Load Indicator**
A value box: `cognitive load = confusion rate + frustration rate`. Green below 0.30, amber 0.30–0.50, red above 0.50 with the label "Overloaded — slow down". When this is red, the AI intervention fires automatically.

**D4 — Class Valence Meter**
A horizontal gauge from -1 to +1. `valence = (focused + engaged) - (frustrated + disengaged + anxious)`. Positive valence = class is doing well. Negative for 5 consecutive readings triggers a warning alert.

**D5 — Per-Student Emotion Heatmap**
A grid — each row is a student, each column is a 5-minute time segment. Cells are colored by dominant emotion: dark green = Focused, green = Engaged, amber = Confused, orange = Frustrated, purple = Anxious, red = Disengaged. The lecturer can see at a glance which individual students are struggling and when it started.

**D6 — Persistent Struggle Alert Table**
A table of students who have been Confused or Frustrated for 3 or more consecutive 5-second readings. Amber for Confused×3, red for Frustrated×3. The lecturer can see duration and consecutive count.

**D7 — Peak Confusion Detector**
A value box showing the 2-minute window during the lecture with the highest combined confusion + frustration rate. Shown after the session ends as a post-session insight — "Most confusing moment: 10:42 AM".

---

### AI Intervention — Fresh Brainer

If the confusion rate reaches 40% or higher for 2 consecutive minutes, the system automatically triggers a Gemini AI call.

> Click **Ask AI (from materials)** to trigger it manually, or wait for the auto-trigger.

The system:
1. Retrieves the current lecture's uploaded slides from the database
2. Extracts the text from the PDF using pdfplumber
3. Sends it to Gemini 1.5 Flash with the prompt: *"Generate ONE clarifying question under 2 sentences to help confused students refocus"*
4. Returns the question to the Shiny dashboard as a popup alert

The popup shows:
- The confusion rate: "Class confused — 42%"
- The suggested question: *"Can you explain the difference between a Type I and Type II error with a real-world example?"*
- Two buttons: **Ask it** | **Dismiss**

If the lecturer clicks "Ask it", the question is broadcast via WebSocket to every connected student phone. Students see it as an overlay in their Focus Mode screen.

> "This closes the loop between AI detection and human response without the lecturer having to think about it."

---

### QR Attendance

Below the engagement gauge is a QR panel. The lecturer can generate a QR code for the current lecture. Students who are not in the camera's field of view can scan it with the mobile app to mark themselves present manually as a fallback.

---

### Ending the Lecture

> Click **End Lecture**.

This sets the lecture status to `ended`, stops the vision pipeline thread, clears the frame buffer, and broadcasts `session:end` to all connected phones. The student app releases Focus Mode automatically.

---

## Part 3 — Student: Mobile App

> Open Expo Go on the phone and scan the dev server QR, or open the installed APK.

**Login:** `231006131` / `aast2026`

---

### Home Screen

The home screen shows:
- A greeting: "Welcome, Omar Metwall"
- A card for the upcoming or active lecture: STAT401-A — Advanced Statistics, status `live`
- A summary of the student's last session engagement score

> "The student sees their lecture is live. One tap to enter Focus Mode."

---

### Focus Mode

Focus Mode is the student's active lecture screen. When they tap in:

1. The app connects to the WebSocket server
2. If a `session:start` event is already live, Focus Mode activates immediately
3. An `AppState` listener fires whenever the student leaves the app — home button, task switcher, incoming call

> **Press the home button on the phone.**

The app detects the background state change and immediately sends a WebSocket event to the backend:
```
{ type: "focus_strike", student_id: "231006131", lecture_id: "...", strike_type: "app_background" }
```

The backend logs it to the `focus_strikes` table. The strike counter on the Focus Mode screen increments.

> "Three strikes and the lecturer gets an alert. This is purely AppState monitoring — no OS-level locks, no device management. The system trusts students to stay in the app."

---

### Fresh Brainer Overlay

When the lecturer clicks "Ask it" after an AI intervention, the question appears on every connected student's phone as a bottom-sheet overlay — no interaction required. The student reads it, thinks, and refocuses.

---

## Part 4 — Exam Proctoring

> Back on the Shiny portal, logged in as mohamedfathy. Go to: **Exam Proctoring**

---

### Setup

Three inputs at the top:
- Course: STAT401
- Class: STAT401-A
- Exam Title: `Midterm Exam`

> Click **Start Exam**.

This does two things:
1. Creates an exam record in the database and broadcasts `exam:start` to all connected phones
2. Starts a vision pipeline session in `exam` context — same pipeline as a lecture, but now running the proctoring logic

The student app receives `exam:start` and navigates to the exam screen automatically.

---

### What the Camera Watches For

The proctoring pipeline runs the same YOLO + face_recognition stack as a lecture, but adds two extra detection layers:

| What | How | Flag | Severity |
|---|---|---|---|
| Phone on desk | YOLOv8 detects COCO class 67 (cell phone) in frame | `phone_on_desk` | 3 |
| Student absent | No face detected in their region for > 5 seconds | `absent` | 3 |
| Multiple people | YOLO detects more than 1 person in the student's zone | `multiple_persons` | 3 |
| Head rotation | MediaPipe FaceMesh measures yaw/pitch angle | `head_rotation` | 2 |
| Identity mismatch | Detected face encoding doesn't match enrolled student | `identity_mismatch` | 3 |
| App goes background | React Native AppState event | `app_background` | 1 |

All incidents are saved to the `incidents` table with a screenshot in `data/evidence/`.

---

### Head Rotation Flag

> Look sharply to one side while facing the camera.

MediaPipe FaceMesh places 468 3D landmarks on the face. The pipeline computes the rotation angle from these landmarks. An extreme yaw (looking sideways) or pitch (looking down) triggers a `head_rotation` incident at Severity 2.

Watch the **Live Incident Log** table update in real time:

```
Timestamp        Student         Flag Type       Severity
10:45:03         Omar Metwall    head_rotation   2
```

The four value boxes at the top update: Total Incidents, High (Sev 3), Medium (Sev 2), Low (Sev 1).

---

### Auto-Submit Rule

If any student accumulates **3 or more Severity-3 incidents within any rolling 10-minute window**, the system automatically calls `POST /exam/submit` with reason `auto-submit: 3+ high-severity incidents`. A WebSocket event `exam:autosubmit` is pushed to the student's phone, which navigates them to a "Submitted" screen — no lecturer action required.

---

### Ending the Exam

> Click **End Exam**.

The exam record is closed, the vision pipeline stops, and all incident data is preserved for the admin's Incident Audit log.

---

## Part 5 — Reports & Analytics

> Go to: **Reports & Analytics** (lecturer sidebar)

Select STAT401 → STAT401-A → a completed session.

Four charts load:

1. **Emotion Frequency** — pie chart of how much time the class spent in each emotional state during that session
2. **Engagement Timeline** — line chart of average engagement score across the session, minute by minute
3. **Attendance Summary** — table of every enrolled student, their attendance status, and method (AI camera, QR scan, or manual)
4. **Student Performance Clusters** — K-means scatter plot clustering students by engagement score and cognitive load for that session. Clusters emerge naturally: high-performers, struggling students, and mid-range

Below that is the **Cross-Session Analytics** section for the class as a whole:

- **Engagement Trend Across Sessions** — how the class's average engagement has changed week by week
- **Emotion Variation Across Sessions** — stacked bar chart, each bar is one lecture, each segment is an emotion state proportion
- **Per-Student Summary** — a table with every student's average engagement, dominant emotion, and cognitive load across all sessions

---

## Part 6 — Materials

> Go to: **LMS Materials** (lecturer sidebar)

The lecturer selects a course, class, and academic week, then uploads a PDF of their slides. The file is stored and linked to the lecture record. When an AI intervention fires during a lecture, this is the PDF the system reads to generate the clarifying question.

---

## System Architecture Summary

```
Classroom Camera (RTSP)
        |
        v
Vision Pipeline (python-api/services/vision_pipeline.py)
  - YOLOv8n         — person bounding boxes
  - face_recognition — student identity (128-dim embeddings)
  - YOLOv8n-face    — tight face crop
  - HSEmotion        — emotion classification
  - Fixed confidence — Focused=1.00, Engaged=0.85, Confused=0.55,
                       Anxious=0.35, Frustrated=0.25, Disengaged=0.00
        |
        v
PostgreSQL Database (DigitalOcean Managed DB)
  - emotion_log, attendance_log, focus_strikes, incidents
        |
      /   \
     v     v
Shiny Portal          React Native App
(Admin + Lecturer)    (Student)
  - Live dashboard      - Focus Mode
  - Exam proctoring     - Fresh Brainer overlay
  - Reports             - QR attendance
  - K-means clusters    - Session notifications

Both connected via:
  - REST API  (FastAPI on DigitalOcean App Platform)
  - WebSocket (/session/ws — real-time broadcasts)
```

**Tech stack:**
- Backend: Python 3.11, FastAPI, SQLAlchemy, PostgreSQL
- Web portal: R 4.3, Shiny, shinydashboard, plotly, DT
- Mobile: React Native + Expo, Zustand, WebSocket
- AI models: YOLOv8n (Ultralytics), face_recognition (dlib), HSEmotion ONNX, Gemini 1.5 Flash (Google AI)
- Hosting: DigitalOcean App Platform (API + DB), shinyapps.io (Shiny), Expo Go (mobile)

---

## Credentials Reference

| Role | User ID | Password | Notes |
|---|---|---|---|
| Admin | `omar` | `aast2026` | Full system access |
| Admin (system) | `admin` | `aast2026` | Built-in root account |
| Lecturer | `mohamedfathy` | `aast2026` | Assigned to STAT401-A |
| Student | `231006131` | `aast2026` | Enrolled in STAT401-A |

**Course:** STAT401 — Advanced Statistics
**Class/Section:** STAT401-A — Section A (lecturer: mohamedfathy, student: 231006131)
