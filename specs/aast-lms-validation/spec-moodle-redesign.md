# Specification: AAST/Moodle Branding Redesign & Feature Additions

**Version**: 1.0.0
**Date**: 2026-05-06
**Status**: Draft
**Author**: Spec Kit Workflow

---

## Constitution Check

Before implementation begins, all features below must conform to the 16 principles in `.specify/memory/constitution.md`.

| Principle | Impact |
|---|---|
| III. Interface Split | React Native changes = Student only. Shiny changes = Admin/Lecturer only. |
| VII. Locked Confidence Values | Req. 7 redefines "Confidence Rate" — this is a DISPLAY-LAYER change only. Backend confidence values stay locked. |
| IX. Camera-Based Proctoring | Live snapshots are captured server-side in vision_pipeline.py. |
| IV. Data Isolation | Snapshots saved as files; path stored in SQLite. R/Shiny reads paths from CSV exports. |
| XII. Schema Lock | Adding `snapshot_path` column requires a migration — schema not locked yet for this column. |

---

## 1. Objective

Redesign the AAST Classroom Emotion System's key interfaces to match AAST/Moodle visual branding standards, and introduce 6 functional improvements: Moodle-style mobile UI, lecture timer, attendance dashboard redesign, live attendance snapshots, admin student management, and a clarified confidence rate definition.

---

## 2. User Stories

### 2.1 Student — Moodle-Style Mobile UI
> As a student, I want the mobile app to look and feel like the AAST Moodle app so I recognize it as an official AAST tool and trust it.

**Acceptance Criteria:**
- Home screen uses card-based layout with AAST Navy (`#002147`) header and Gold (`#C9A84C`) accent elements
- Cards display: course name, lecturer name, lecture time, next upcoming lecture
- Typography matches Moodle: Roboto font, clean white backgrounds, subtle shadows
- Navigation tab bar uses Navy background with Gold active indicator
- Bottom navigation: Home, Focus, Notes, Profile tabs
- Login screen matches AAST Moodle login page (logo, field styling)

### 2.2 Student — Lecture Timer
> As a student in focus mode, I want to see how long the current lecture has been running so I can manage my attention and energy.

**Acceptance Criteria:**
- Timer is visible in focus mode screen (`app/(student)/focus.tsx`)
- Timer starts from `session:start` WebSocket event (uses `start_time` from lecture data)
- Format: `HH:MM:SS` — ticks every second using `setInterval`
- Timer stops and freezes when `session:end` event received
- Timer survives brief network drops (uses local `Date.now()` math, not server polling)
- Displayed prominently — not hidden behind other UI elements
- Color: Gold (`#C9A84C`) text on Navy background

### 2.3 Lecturer/Admin — Attendance Dashboard (AAST Style)
> As a lecturer, I want to see attendance as a grid of student cards, each with a photo, ID, name, toggle, and note field — matching the AAST visual style.

**Acceptance Criteria:**
- R/Shiny attendance view renders a responsive CSS grid of student cards
- Each card contains:
  - Student photo (enrollment photo, or live snapshot if available — see 2.4)
  - Student ID (9-digit format)
  - Student name (Arabic + English if available)
  - Toggle switch: Present/Absent (maps to existing `status` column in `attendance_log`)
  - Reason text input (maps to a new `reason` column, or saved separately)
  - Save button per card (or bulk save)
- Card color: Present = green left border, Absent = red left border
- Cards render from the `attendance.csv` export
- Manual toggle action calls existing `POST /attendance/manual` endpoint
- Mobile-responsive (adapts to window width)

### 2.4 Lecturer/Admin — Live Attendance Snapshots
> As a lecturer, I want to see a live photo of each student taken at detection time, not just their enrollment photo, to verify the AI correctly identified them.

**Acceptance Criteria:**
- When vision pipeline detects a student and marks "Present", it captures a face ROI crop and saves it as `data/snapshots/{lecture_id}/{student_id}.jpg`
- FastAPI exposes `GET /attendance/snapshot/{lecture_id}/{student_id}` → returns image file
- Attendance card in Shiny shows the live snapshot image if the file exists, otherwise falls back to enrollment photo
- Snapshot is overwritten each time the student is re-detected (always shows latest)
- Image quality: 80% JPEG, minimum 100×100px (skip if ROI is too small)

### 2.5 Admin — Student Management (Manual Add)
> As an admin, I want to manually add new students to the system through the web portal without needing to upload a full XLSX roster.

**Acceptance Criteria:**
- New "Student Management" tab in Admin UI (`admin_ui.R`)
- Form fields:
  - Student ID (9-digit, validated)
  - Full Name (required)
  - Email (optional)
  - Enrollment Photo (file upload — JPEG/PNG, max 5MB)
- Submit button calls `POST /roster/student` (new endpoint)
- FastAPI endpoint:
  - Validates student_id is 9 digits
  - Checks for duplicate student_id → 409 Conflict if exists
  - Saves photo temporarily, runs `face_recognition.face_encodings()`
  - INSERT into `students` table with face_encoding BLOB
  - Returns `{student_id, name, encoding_saved: bool}`
- Success notification in Shiny: "Student {name} added successfully"
- Error notification: duplicate ID, bad photo, no face detected

### 2.6 Confidence Rate — Clarified Definition
> As a developer/administrator reading AI logs, I want "Confidence Rate" to mean the model's certainty for a specific prediction — not a fixed engagement score.

**Acceptance Criteria:**
- All UI labels, tooltips, and documentation rename "Confidence" → "Confidence Rate" where it refers to model certainty
- **Backend behavior is unchanged**: `emotion_log.confidence` column retains the LOCKED fixed values (Focused=1.00, Engaged=0.85, etc.) as defined in Principle VII
- Display layer clarification only:
  - Shiny panels: add tooltip or label clarifying "Confidence Rate = model certainty for this emotion detection"
  - React Native: replace any raw "confidence" label with "Confidence Rate"
  - API docs (`/docs`): update field descriptions for `confidence` and `engagement_score`
- The fixed confidence values serve as a proxy for engagement level — this framing is preserved in all documentation

---

## 3. Data Model Changes

### 3.1 New `snapshot_path` Column in `attendance_log`
```sql
ALTER TABLE attendance_log ADD COLUMN snapshot_path TEXT;
-- Stores: "data/snapshots/{lecture_id}/{student_id}.jpg" or NULL
```
> Requires migration script. Column is nullable — existing rows are unaffected.

### 3.2 New Snapshot Directory
```
python-api/data/snapshots/
    {lecture_id}/
        {student_id}.jpg    ← latest face ROI capture per lecture per student
```
> Directory is gitignored. Created at startup if missing.

### 3.3 New `POST /roster/student` Endpoint
Input: `multipart/form-data` with fields `student_id`, `name`, `email` (optional), `photo` (file)
Output: `{student_id, name, encoding_saved: bool}`

---

## 4. API Contract Additions

### 4.1 `POST /roster/student`
```
POST /roster/student
Content-Type: multipart/form-data

Fields:
  student_id: str  (9-digit, required)
  name: str        (required)
  email: str       (optional)
  photo: file      (JPEG/PNG, max 5MB, required)

Responses:
  201: {student_id, name, encoding_saved: true}
  409: {detail: "Student {student_id} already exists"}
  422: {detail: "No face detected in uploaded photo"}
  413: {detail: "Photo too large (max 5MB)"}
```

### 4.2 `GET /attendance/snapshot/{lecture_id}/{student_id}`
```
GET /attendance/snapshot/{lecture_id}/{student_id}

Responses:
  200: image/jpeg (the snapshot file)
  404: {detail: "No snapshot available"}
```

### 4.3 Updated `GET /emotion/live` response
Add `confidence_rate` as an alias for `confidence` in the response JSON for clarity:
```json
{
  "student_id": "231006367",
  "emotion": "Confused",
  "confidence": 0.55,
  "confidence_rate": 0.55,
  "engagement_score": 0.55
}
```

---

## 5. WebSocket Contract Additions

None required. `session:start` event already carries `start_time` and `lectureId` — the mobile timer will use `start_time` from this payload.

The `session:start` payload should be confirmed to include:
```json
{
  "type": "session:start",
  "lectureId": "L1",
  "slideUrl": "https://...",
  "start_time": "2026-05-06T09:00:00Z"
}
```

---

## 6. Out of Scope

- Changing confidence value constants (Principle VII — locked)
- Student-facing attendance view in React Native (Principle III — students don't see admin data)
- Lecturer-facing features in React Native (Principle III)
- Replacing SQLite with another database
- Adding student login photos taken at exam time (handled separately by proctor_service.py)

---

## 7. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Face ROI too small for valid snapshot | Medium | Skip snapshot if ROI < 100×100px |
| Snapshot file access from Shiny violates data isolation | High | Shiny reads snapshot URL from CSV export → fetches via `GET /attendance/snapshot/` API call (not direct file access) |
| 9-digit student ID validation missed in new endpoint | Low | Add regex validator in FastAPI route |
| Moodle font (Roboto) not loaded in Expo | Low | Add `expo-google-fonts/roboto` package |
| Schema migration breaks existing queries | Low | Use `ADD COLUMN` (non-destructive); keep column nullable |

---

## 8. Implementation Sequence

1. **Schema migration** (S3) — add `snapshot_path` to `attendance_log`
2. **Vision pipeline snapshot capture** (S1) — save face ROI on first detection
3. **Snapshot API endpoint** (S3) — `GET /attendance/snapshot/`
4. **Student add endpoint** (S3) — `POST /roster/student`
5. **Attendance card UI** (S2) — Shiny grid with toggle, reason, photo
6. **Admin student management tab** (S2) — new tab + form
7. **React Native Moodle redesign** (S4) — colors, cards, navigation
8. **Lecture timer** (S4) — `focus.tsx` timer using `session:start.start_time`
9. **Confidence Rate labeling** (S2 + S4) — display-layer rename only
