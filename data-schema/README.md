# Data Contracts — SQLite & CSV Schemas (v1)
> **Status:** LOCKED — Sign-off required by all 4 members.
> **Role:** S3 (Backend Lead) - Owner

This document defines the precise wiring between the FastAPI live database and the R/Shiny analytics layer.

---

## 1. SQLite Live Database (Runtime)
**File:** `python-api/data/classroom_emotions.db`

### `students`
| Column | Type | Description |
|---|---|---|
| `student_id` | TEXT (PK) | "S01", "S02", etc. |
| `name` | TEXT | Student full name |
| `email` | TEXT | AAST email |
| `face_encoding` | BLOB | 128-dim float64 numpy array bytes |
| `enrolled_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP |

### `lectures`
| Column | Type | Description |
|---|---|---|
| `lecture_id` | TEXT (PK) | "L1", "L2", etc. |
| `lecturer_id` | TEXT | ID of the lecturer |
| `title` | TEXT | Lecture title |
| `subject` | TEXT | Course subject |
| `start_time` | DATETIME | Actual start time |
| `end_time` | DATETIME | Actual end time (NULL if live) |
| `slide_url` | TEXT | Google Drive link |

### `emotion_log`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `student_id` | TEXT | FK students.student_id |
| `lecture_id` | TEXT | FK lectures.lecture_id |
| `timestamp` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `emotion` | TEXT | Focused/Engaged/Confused/Anxious/Frustrated/Disengaged |
| `confidence` | REAL | Fixed score (1.0 to 0.0) |
| `engagement_score` | REAL | Equals confidence |

### `attendance_log`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `student_id` | TEXT | FK students.student_id |
| `lecture_id` | TEXT | FK lectures.lecture_id |
| `timestamp` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `status` | TEXT | Present | Absent |
| `method` | TEXT | AI | Manual | QR |

### `materials`
| Column | Type | Description |
|---|---|---|
| `material_id` | TEXT (PK) | "M01", "M02", etc. |
| `lecture_id` | TEXT | FK lectures.lecture_id |
| `lecturer_id` | TEXT | ID of the uploader |
| `title` | TEXT | Material title |
| `drive_link` | TEXT | Google Drive URL |
| `uploaded_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP |

### `incidents`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `student_id` | TEXT | FK students.student_id |
| `exam_id` | TEXT | Unique exam identifier |
| `timestamp` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `flag_type` | TEXT | phone_on_desk/head_rotation/absent/multiple_persons/identity_mismatch/app_background |
| `severity` | INTEGER | 1 (Low) | 2 (Med) | 3 (High) |
| `evidence_path` | TEXT | Path to JPEG file in evidence folder |

### `transcripts`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `lecture_id` | TEXT | FK lectures.lecture_id |
| `timestamp` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `chunk_text` | TEXT | Raw Whisper output (5s chunk) |
| `language` | TEXT | ar | en | mixed |

### `notifications`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `student_id` | TEXT | FK students.student_id |
| `lecturer_id` | TEXT | Target lecturer |
| `lecture_id` | TEXT | Source lecture |
| `reason` | TEXT | Human readable reason |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `read` | INTEGER | 0 = unread | 1 = read |

### `focus_strikes`
| Column | Type | Description |
|---|---|---|
| `id` | INTEGER (PK) | AUTOINCREMENT |
| `student_id` | TEXT | FK students.student_id |
| `lecture_id` | TEXT | FK lectures.lecture_id |
| `timestamp` | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| `strike_type` | TEXT | app_background |

---

## 2. Nightly CSV Export Contract
**Path:** `python-api/data/exports/`
**Owner:** S3 (via APScheduler)
**Consumer:** S2 (R/Shiny via `reactivePoll`)

R/Shiny reads these files by column name. **DO NOT RENAME.**

- `emotions.csv`: `student_id, lecture_id, timestamp, emotion, confidence, engagement_score`
- `attendance.csv`: `student_id, lecture_id, timestamp, status, method`
- `materials.csv`: `material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at`
- `incidents.csv`: `student_id, exam_id, timestamp, flag_type, severity, evidence_path`
- `transcripts.csv`: `lecture_id, timestamp, chunk_text, language`
- `notifications.csv`: `student_id, lecturer_id, lecture_id, reason, created_at, read`

---

## 3. JWT Payload Structure
Authentication header: `Authorization: Bearer <JWT>`

```json
{
  "student_id": "S01",
  "role": "student",
  "exp": 1714299333
}
```
*Note: Lecturer JWTs use `lecturer_id` and `role: "lecturer"`.*
