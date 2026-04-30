# Data Model: AAST LMS & Emotion Analytics

**Date**: 2026-04-30 | **Phase**: 1 — Design

---

## Entity Summary

All 9 SQLite tables are locked as of Week 1. Column names MUST NOT change.

| Entity | Table | Key | Key Field | Notes |
|---|---|---|---|---|
| Student | `students` | `student_id TEXT PK` | 9-digit AAST number | `face_encoding BLOB` = 128-dim float64 numpy array |
| Lecture | `lectures` | `lecture_id TEXT PK` | e.g. `L1` | `slide_url` for Gemini extraction |
| Emotion reading | `emotion_log` | `id INTEGER PK` | FK → students, lectures | `confidence` = fixed switch-case value |
| Attendance record | `attendance_log` | `id INTEGER PK` | FK → students, lectures | `method`: AI \| Manual \| QR |
| Course material | `materials` | `material_id TEXT PK` | e.g. `M01` | `drive_link` to Google Drive |
| Exam incident | `incidents` | `id INTEGER PK` | FK → students | `severity` 1-3; `evidence_path` for screenshot |
| Transcript chunk | `transcripts` | `id INTEGER PK` | FK → lectures | 5s Whisper chunks; `language`: ar \| en \| mixed |
| Notification | `notifications` | `id INTEGER PK` | FK → students, lecturer | `read` 0/1 |
| Focus strike | `focus_strikes` | `id INTEGER PK` | FK → students, lectures | `strike_type`: app_background |

---

## Key Relationships

```
students (1) ──── (N) emotion_log
students (1) ──── (N) attendance_log
students (1) ──── (N) incidents
students (1) ──── (N) notifications
students (1) ──── (N) focus_strikes

lectures (1) ──── (N) emotion_log
lectures (1) ──── (N) attendance_log
lectures (1) ──── (N) materials
lectures (1) ──── (N) transcripts
lectures (1) ──── (N) notifications
lectures (1) ──── (N) focus_strikes
```

---

## Derived Data (computed in R, not stored in SQLite)

| Metric | Formula | Table |
|---|---|---|
| `engagement_score` | stored directly = `confidence` (at write time) | `emotion_log` |
| `confusion_rate` | `mean(emotion == "Confused")` over window | computed in R |
| `frustration_rate` | `mean(emotion == "Frustrated")` over window | computed in R |
| `cognitive_load` | `confusion_rate + frustration_rate` | computed in R |
| `class_valence` | `(focused + engaged) - (frustrated + disengaged + anxious)` | computed in R |
| `LES` | `0.5×avg_engagement + 0.3×(1−confusion_rate) + 0.2×attendance_rate` | computed in R |

---

## CSV Export Schemas (read by R/Shiny — column names locked)

```
exports/emotions.csv:    student_id, lecture_id, timestamp, emotion, confidence, engagement_score
exports/attendance.csv:  student_id, lecture_id, timestamp, status, method
exports/materials.csv:   material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at
exports/incidents.csv:   student_id, exam_id, timestamp, flag_type, severity, evidence_path
exports/transcripts.csv: lecture_id, timestamp, chunk_text, language
exports/notifications.csv: student_id, lecturer_id, lecture_id, reason, created_at, read
```

All CSVs: UTF-8-BOM encoding (`utf-8-sig`) to support Arabic names in Excel.

---

## State Transitions

### Lecture lifecycle
```
IDLE → STARTED (POST /session/start) → RUNNING (vision + whisper active) → ENDED (POST /session/end)
```

### Student focus state
```
INACTIVE → ACTIVE (session:start WS event) → STRIKED (AppState → background) → INACTIVE (session:end)
```

### Exam state
```
IDLE → EXAM_ACTIVE (POST /exam/start) → INCIDENT_FLAGGED (severity 1-3) → AUTO_SUBMITTED (3×sev-3 in 10min)
```
