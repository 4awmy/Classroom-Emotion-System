# HTTP API Contracts — AAST LMS

**Date**: 2026-04-30 | Source: ARCHITECTURE.md Section 3 + CLAUDE.md Section 13

All endpoints: `Content-Type: application/json` unless noted. Auth: `Authorization: Bearer {jwt}`.

---

## Authentication

### POST /auth/login
```json
// Request
{ "student_id": "231006367", "password": "..." }

// Response 200
{ "token": "eyJ..." }

// Response 401
{ "detail": "Invalid credentials" }
```

---

## Emotion

### GET /emotion/live?lecture_id={id}&limit={n}
Returns last `n` (default 60) emotion rows for a lecture.
```json
// Response 200
[
  { "student_id": "231006367", "emotion": "Focused", "confidence": 1.0,
    "engagement_score": 1.0, "timestamp": "2026-04-30T10:05:00" },
  ...
]
```

### GET /emotion/confusion-rate?lecture_id={id}&window={seconds}
Returns confusion rate over the last `window` seconds (default 120).
```json
// Response 200
{ "lecture_id": "L1", "window_seconds": 120, "confusion_rate": 0.42 }
```

---

## Session

### POST /session/start
```json
// Request
{ "lecture_id": "L1", "lecturer_id": "LECT01", "slide_url": "https://drive.google.com/..." }

// Response 200
{ "status": "started", "lecture_id": "L1" }
```

### POST /session/end
```json
// Request
{ "lecture_id": "L1" }

// Response 200
{ "status": "ended" }
```

### POST /session/broadcast
```json
// Request
{ "type": "freshbrainer", "question": "Can you explain the difference between X and Y?" }

// Response 200
{ "delivered_to": 27 }
```

### GET /session/upcoming
```json
// Response 200
[
  { "lecture_id": "L1", "title": "Data Structures", "start_time": "2026-05-01T09:00:00",
    "subject": "CS201", "slide_url": "..." },
  ...
]
```

---

## Roster

### POST /roster/upload
Multipart form with single XLSX field.

```
Content-Type: multipart/form-data
Field: roster_xlsx (file, .xlsx)
```

```json
// Response 200
{ "students_created": 127, "encodings_saved": 120 }

// Response 413
{ "detail": "File too large (max 10 MB)" }
```

---

## Attendance

### POST /attendance/start
```json
{ "lecture_id": "L1" }
// Response: { "status": "ai_scanning" }
```

### POST /attendance/manual
```json
{ "lecture_id": "L1", "records": [{"student_id": "231006367", "status": "Present"}] }
// Response: { "updated": 127 }
```

### GET /attendance/qr/{lecture_id}
Returns QR code PNG as base64 string.
```json
{ "qr_base64": "iVBORw..." }
```

---

## Gemini / AI

### POST /gemini/question
```json
// Request
{ "lecture_id": "L1" }

// Response 200
{ "question": "What is the key difference between recursion and iteration?" }
```

### GET /notes/{student_id}/{lecture_id}
```json
// Response 200 (plain text Markdown)
"## Lecture Notes\n\n### Key Concepts\n...\n\n✱ **You missed this part:** ..."
```

### GET /notes/{student_id}/plan
```json
// Response 200 (plain text Markdown)
"## Intervention Plan\n\n1. Review lecture recordings for weeks 3–4...\n2. ..."
```

---

## Exam

### POST /exam/start
```json
{ "exam_id": "E1", "student_id": "231006367" }
// Response: { "status": "active" }
```

### POST /exam/submit
```json
{ "exam_id": "E1", "student_id": "231006367", "reason": "auto_submit" }
// Response: { "status": "submitted" }
```

### GET /exam/incidents/{exam_id}
```json
[
  { "student_id": "231006367", "flag_type": "phone_on_desk", "severity": 3,
    "timestamp": "2026-04-30T10:05:00", "evidence_path": "data/evidence/..." },
  ...
]
```

---

## Notifications

### POST /notify/lecturer
```json
{ "student_id": "231006367", "lecturer_id": "LECT01",
  "lecture_id": "L1", "reason": "Confused for 5 consecutive readings" }
// Response: { "notification_id": 42 }
```

---

## Health

### GET /health
```json
{ "status": "ok" }
```
