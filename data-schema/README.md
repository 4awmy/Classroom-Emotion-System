# Data Contracts — PostgreSQL Schema (v2)
> **Status:** UPDATED — Requires sign-off by all 4 members before implementation.
> **Role:** S3 (Backend Lead) - Owner
> **Database:** Supabase (PostgreSQL) — replaces SQLite
> **Auth:** Supabase Auth — replaces custom JWT router

This document defines the full database schema, role definitions, RLS policies, and auth contracts.

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [User & Auth Tables](#2-user--auth-tables)
3. [Academic Structure Tables](#3-academic-structure-tables)
4. [Live Analytics Tables](#4-live-analytics-tables)
5. [Supabase SQL — Full Schema](#5-supabase-sql--full-schema)
6. [Row Level Security Policies](#6-row-level-security-policies)
7. [JWT Payload Structure](#7-jwt-payload-structure)
8. [Role Capabilities](#8-role-capabilities)
9. [Key Relationships](#9-key-relationships)

---

## 1. Architecture Overview

```
Before (v1):
  FastAPI → SQLite → APScheduler (02:00) → CSV exports → R/Shiny

After (v2):
  FastAPI → Supabase PostgreSQL ← R/Shiny (direct SQL via RPostgres)
  Supabase Auth → JWT → FastAPI (verify) + React Native (client SDK)
  Vision pipeline: FastAPI writes emotion/attendance to PostgreSQL
  No CSV export layer — R/Shiny queries live DB with read-only credentials
```

**Why Supabase over Firebase:**
- PostgreSQL = relational schema with JOINs and GROUP BY (required for analytics)
- Firebase Firestore is NoSQL — cannot do aggregation queries for emotion analytics
- Supabase Auth handles all 3 roles (admin / lecturer / student) with custom JWT claims
- RLS enforces data isolation at DB level — students cannot see other students' data

---

## 2. User & Auth Tables

### `admins`
> Full system access. Manages all rosters, courses, classes, and assignments.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `admin_id` | TEXT | PK | e.g. `ADM001` |
| `auth_user_id` | UUID | FK → `auth.users` UNIQUE | Supabase Auth user ID |
| `name` | TEXT | NOT NULL | Full name |
| `email` | TEXT | UNIQUE NOT NULL | AAST email |
| `phone` | TEXT | | Contact number |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `lecturers`
> Assigned to classes by admin. Manages live sessions, materials, attendance, exams for their own classes only.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `lecturer_id` | TEXT | PK | e.g. `LEC001` |
| `auth_user_id` | UUID | FK → `auth.users` UNIQUE | Supabase Auth user ID |
| `name` | TEXT | NOT NULL | Full name |
| `email` | TEXT | UNIQUE NOT NULL | AAST email |
| `department` | TEXT | | e.g. `CS`, `EE`, `ME` |
| `title` | TEXT | | Dr. / Prof. / Eng. |
| `phone` | TEXT | | |
| `photo_url` | TEXT | | Profile photo (Drive/Storage link) |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `students`
> Enrolled in classes by admin (via XLSX or manually). Uses mobile app only.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `student_id` | TEXT | PK | 9-digit AAST number e.g. `231006367` |
| `auth_user_id` | UUID | FK → `auth.users` UNIQUE | Supabase Auth user ID |
| `name` | TEXT | NOT NULL | Full name (Arabic supported) |
| `email` | TEXT | | AAST email |
| `department` | TEXT | | |
| `year` | INTEGER | | Academic year 1–5 |
| `face_encoding` | BYTEA | | 128-dim float64 numpy array bytes (vision pipeline) |
| `photo_url` | TEXT | | Drive link from admin roster upload |
| `enrolled_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

## 3. Academic Structure Tables

### `courses`
> A subject/module. e.g. "Data Structures CS301". One course can have multiple classes (sections).

| Column | Type | Constraints | Description |
|---|---|---|---|
| `course_id` | TEXT | PK | e.g. `CS301` |
| `title` | TEXT | NOT NULL | e.g. `Data Structures` |
| `department` | TEXT | | e.g. `CS` |
| `credit_hours` | INTEGER | | |
| `semester` | TEXT | | e.g. `Spring 2026` |
| `year` | INTEGER | | e.g. `2026` |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `classes`
> A section of a course. The core unit — one lecturer, one group of students, one schedule.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `class_id` | TEXT | PK | e.g. `CS301-A` |
| `course_id` | TEXT | FK → `courses` NOT NULL | Which course |
| `lecturer_id` | TEXT | FK → `lecturers` | Assigned lecturer (set by admin) |
| `section_name` | TEXT | | `A`, `B`, `Group 1` |
| `room` | TEXT | | e.g. `Hall 3-B` |
| `semester` | TEXT | | `Spring 2026` |
| `year` | INTEGER | | `2026` |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `class_schedule`
> Weekly recurring time slots for a class.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `schedule_id` | TEXT | PK | e.g. `SCH001` |
| `class_id` | TEXT | FK → `classes` NOT NULL | |
| `day_of_week` | TEXT | NOT NULL | `Monday` \| `Tuesday` \| ... \| `Sunday` |
| `start_time` | TIME | NOT NULL | e.g. `09:00` |
| `end_time` | TIME | NOT NULL | e.g. `10:30` |

---

### `enrollments`
> Which students are assigned to which class. Managed by admin only.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `class_id` | TEXT | FK → `classes` NOT NULL | |
| `student_id` | TEXT | FK → `students` NOT NULL | |
| `enrolled_at` | TIMESTAMPTZ | DEFAULT NOW() | |
| | | UNIQUE(`class_id`, `student_id`) | No duplicate enrollments |

---

### `lectures`
> An actual live session of a class. One class has many lecture sessions per semester.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `lecture_id` | TEXT | PK | e.g. `L1`, `L2` |
| `class_id` | TEXT | FK → `classes` NOT NULL | Which class this session belongs to |
| `lecturer_id` | TEXT | FK → `lecturers` NOT NULL | Who ran the session |
| `title` | TEXT | | Topic title e.g. `Binary Trees` |
| `session_type` | TEXT | DEFAULT `lecture` | `lecture` \| `exam` |
| `start_time` | TIMESTAMPTZ | | Actual start time (for punctuality calc) |
| `end_time` | TIMESTAMPTZ | | NULL if session is live |
| `scheduled_start` | TIMESTAMPTZ | | Planned start from class_schedule |
| `slide_url` | TEXT | | Google Drive link |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `exams`
> Exam sessions linked to a class. Created by admin or lecturer, started by lecturer.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `exam_id` | TEXT | PK | e.g. `EXAM001` |
| `class_id` | TEXT | FK → `classes` NOT NULL | |
| `lecture_id` | TEXT | FK → `lectures` | Set when lecturer clicks Start |
| `title` | TEXT | NOT NULL | e.g. `Midterm 1` |
| `scheduled_start` | TIMESTAMPTZ | | Planned exam start |
| `end_time` | TIMESTAMPTZ | | NULL until exam ends |
| `auto_submit` | BOOLEAN | DEFAULT TRUE | Auto-submit student on 3× Sev-3 in 10min |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

### `materials`
> Lecture materials uploaded by lecturer for their classes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `material_id` | TEXT | PK | e.g. `M01` |
| `lecture_id` | TEXT | FK → `lectures` NOT NULL | |
| `lecturer_id` | TEXT | FK → `lecturers` NOT NULL | Uploader |
| `title` | TEXT | NOT NULL | |
| `drive_link` | TEXT | | Google Drive URL |
| `uploaded_at` | TIMESTAMPTZ | DEFAULT NOW() | |

---

## 4. Live Analytics Tables

### `emotion_log`
> Written every 5 seconds per identified student by the vision pipeline.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `student_id` | TEXT | FK → `students` NOT NULL | |
| `lecture_id` | TEXT | FK → `lectures` NOT NULL | |
| `timestamp` | TIMESTAMPTZ | DEFAULT NOW() | |
| `emotion` | TEXT | NOT NULL | `Focused` \| `Engaged` \| `Confused` \| `Anxious` \| `Frustrated` \| `Disengaged` |
| `confidence` | REAL | NOT NULL | Fixed per emotion state (see locked values below) |
| `engagement_score` | REAL | NOT NULL | Equals confidence — computed at write time |

**Locked confidence values (never use model softmax):**
| Emotion | Confidence | Engagement Level |
|---|---|---|
| Focused | `1.00` | High |
| Engaged | `0.85` | High |
| Confused | `0.55` | Moderate |
| Anxious | `0.35` | Low |
| Frustrated | `0.25` | Low |
| Disengaged | `0.00` | Critical |

---

### `attendance_log`
> One record per student per session. Method indicates how attendance was recorded.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `student_id` | TEXT | FK → `students` NOT NULL | |
| `lecture_id` | TEXT | FK → `lectures` NOT NULL | |
| `timestamp` | TIMESTAMPTZ | DEFAULT NOW() | |
| `status` | TEXT | NOT NULL | `Present` \| `Absent` |
| `method` | TEXT | NOT NULL | `AI` \| `Manual` \| `QR` |

---

### `incidents`
> Exam proctoring flags. Written by vision pipeline (YOLO + MediaPipe) and React Native AppState.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `student_id` | TEXT | FK → `students` | |
| `exam_id` | TEXT | FK → `exams` NOT NULL | |
| `timestamp` | TIMESTAMPTZ | DEFAULT NOW() | |
| `flag_type` | TEXT | NOT NULL | `phone_on_desk` \| `head_rotation` \| `absent` \| `multiple_persons` \| `identity_mismatch` \| `app_background` |
| `severity` | INTEGER | NOT NULL | `1` Low \| `2` Medium \| `3` High |
| `evidence_path` | TEXT | | Path to screenshot in `data/evidence/` |

---

### `notifications`
> Alerts sent to lecturers (e.g. confusion spike, at-risk student).

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `student_id` | TEXT | FK → `students` | |
| `lecturer_id` | TEXT | FK → `lecturers` NOT NULL | Target recipient |
| `lecture_id` | TEXT | FK → `lectures` | Source session |
| `reason` | TEXT | NOT NULL | Human-readable reason |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |
| `read` | BOOLEAN | DEFAULT FALSE | |

---

### `focus_strikes`
> Mobile app focus mode — fires when student leaves the app during a lecture.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `student_id` | TEXT | FK → `students` NOT NULL | |
| `lecture_id` | TEXT | FK → `lectures` NOT NULL | |
| `timestamp` | TIMESTAMPTZ | DEFAULT NOW() | |
| `strike_type` | TEXT | NOT NULL | `app_background` |

---

## 5. Supabase SQL — Full Schema

Run this in the Supabase SQL editor to create all tables:

```sql
-- ─────────────────────────────────────────
-- USER TABLES
-- ─────────────────────────────────────────

CREATE TABLE admins (
    admin_id       TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT UNIQUE NOT NULL,
    phone          TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lecturers (
    lecturer_id    TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT UNIQUE NOT NULL,
    department     TEXT,
    title          TEXT,
    phone          TEXT,
    photo_url      TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE students (
    student_id     TEXT PRIMARY KEY,
    auth_user_id   UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    name           TEXT NOT NULL,
    email          TEXT,
    department     TEXT,
    year           INTEGER,
    face_encoding  BYTEA,
    photo_url      TEXT,
    enrolled_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- ACADEMIC STRUCTURE
-- ─────────────────────────────────────────

CREATE TABLE courses (
    course_id      TEXT PRIMARY KEY,
    title          TEXT NOT NULL,
    department     TEXT,
    credit_hours   INTEGER,
    semester       TEXT,
    year           INTEGER,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE classes (
    class_id       TEXT PRIMARY KEY,
    course_id      TEXT NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    lecturer_id    TEXT REFERENCES lecturers(lecturer_id) ON DELETE SET NULL,
    section_name   TEXT,
    room           TEXT,
    semester       TEXT,
    year           INTEGER,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE class_schedule (
    schedule_id    TEXT PRIMARY KEY,
    class_id       TEXT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    day_of_week    TEXT NOT NULL,
    start_time     TIME NOT NULL,
    end_time       TIME NOT NULL
);

CREATE TABLE enrollments (
    id             BIGSERIAL PRIMARY KEY,
    class_id       TEXT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    student_id     TEXT NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    enrolled_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(class_id, student_id)
);

CREATE TABLE lectures (
    lecture_id        TEXT PRIMARY KEY,
    class_id          TEXT NOT NULL REFERENCES classes(class_id),
    lecturer_id       TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    title             TEXT,
    session_type      TEXT DEFAULT 'lecture',
    start_time        TIMESTAMPTZ,
    end_time          TIMESTAMPTZ,
    scheduled_start   TIMESTAMPTZ,
    slide_url         TEXT,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exams (
    exam_id           TEXT PRIMARY KEY,
    class_id          TEXT NOT NULL REFERENCES classes(class_id),
    lecture_id        TEXT REFERENCES lectures(lecture_id),
    title             TEXT NOT NULL,
    scheduled_start   TIMESTAMPTZ,
    end_time          TIMESTAMPTZ,
    auto_submit       BOOLEAN DEFAULT TRUE,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE materials (
    material_id    TEXT PRIMARY KEY,
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    lecturer_id    TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    title          TEXT NOT NULL,
    drive_link     TEXT,
    uploaded_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- LIVE ANALYTICS
-- ─────────────────────────────────────────

CREATE TABLE emotion_log (
    id               BIGSERIAL PRIMARY KEY,
    student_id       TEXT NOT NULL REFERENCES students(student_id),
    lecture_id       TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp        TIMESTAMPTZ DEFAULT NOW(),
    emotion          TEXT NOT NULL,
    confidence       REAL NOT NULL,
    engagement_score REAL NOT NULL
);

CREATE TABLE attendance_log (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT NOT NULL REFERENCES students(student_id),
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    status         TEXT NOT NULL,
    method         TEXT NOT NULL
);

CREATE TABLE incidents (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT REFERENCES students(student_id),
    exam_id        TEXT NOT NULL REFERENCES exams(exam_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    flag_type      TEXT NOT NULL,
    severity       INTEGER NOT NULL,
    evidence_path  TEXT
);

CREATE TABLE notifications (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT REFERENCES students(student_id),
    lecturer_id    TEXT NOT NULL REFERENCES lecturers(lecturer_id),
    lecture_id     TEXT REFERENCES lectures(lecture_id),
    reason         TEXT NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    read           BOOLEAN DEFAULT FALSE
);

CREATE TABLE focus_strikes (
    id             BIGSERIAL PRIMARY KEY,
    student_id     TEXT NOT NULL REFERENCES students(student_id),
    lecture_id     TEXT NOT NULL REFERENCES lectures(lecture_id),
    timestamp      TIMESTAMPTZ DEFAULT NOW(),
    strike_type    TEXT NOT NULL
);
```

---

## 6. Row Level Security Policies

Enable RLS on all tables then apply these policies:

```sql
-- Enable RLS on every table
ALTER TABLE admins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE students         ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_schedule   ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures         ENABLE ROW LEVEL SECURITY;
ALTER TABLE exams            ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials        ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_log      ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_log   ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_strikes    ENABLE ROW LEVEL SECURITY;

-- ─── ADMIN: full access to everything ───
CREATE POLICY "admin_all" ON admins
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_lecturers" ON lecturers
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_students" ON students
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_courses" ON courses
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_classes" ON classes
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_schedule" ON class_schedule
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_manage_enrollments" ON enrollments
    FOR ALL USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_analytics" ON emotion_log
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_attendance" ON attendance_log
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "admin_view_all_incidents" ON incidents
    FOR SELECT USING ((auth.jwt() ->> 'role') = 'admin');

-- ─── LECTURER: read own profile, read own classes only ───
CREATE POLICY "lecturer_read_own_profile" ON lecturers
    FOR SELECT USING (
        auth_user_id = auth.uid()
    );

CREATE POLICY "lecturer_update_own_profile" ON lecturers
    FOR UPDATE USING (
        auth_user_id = auth.uid()
    );

CREATE POLICY "lecturer_view_own_classes" ON classes
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_view_own_schedule" ON class_schedule
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_enrollments" ON enrollments
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_manage_lectures" ON lectures
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_manage_exams" ON exams
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND class_id IN (
            SELECT class_id FROM classes
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_manage_materials" ON materials
    FOR ALL USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

CREATE POLICY "lecturer_view_own_emotions" ON emotion_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecture_id IN (
            SELECT lecture_id FROM lectures
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_own_attendance" ON attendance_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecture_id IN (
            SELECT lecture_id FROM lectures
            WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
        )
    );

CREATE POLICY "lecturer_view_own_incidents" ON incidents
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND exam_id IN (
            SELECT exam_id FROM exams
            WHERE class_id IN (
                SELECT class_id FROM classes
                WHERE lecturer_id = (auth.jwt() ->> 'lecturer_id')
            )
        )
    );

CREATE POLICY "lecturer_view_own_notifications" ON notifications
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'lecturer'
        AND lecturer_id = (auth.jwt() ->> 'lecturer_id')
    );

-- ─── STUDENT: own data only ───
CREATE POLICY "student_read_own_profile" ON students
    FOR SELECT USING (auth_user_id = auth.uid());

CREATE POLICY "student_view_own_emotions" ON emotion_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_attendance" ON attendance_log
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_enrollments" ON enrollments
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_schedule" ON class_schedule
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND class_id IN (
            SELECT class_id FROM enrollments
            WHERE student_id = (auth.jwt() ->> 'student_id')
        )
    );

CREATE POLICY "student_insert_focus_strikes" ON focus_strikes
    FOR INSERT WITH CHECK (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );

CREATE POLICY "student_view_own_notifications" ON notifications
    FOR SELECT USING (
        (auth.jwt() ->> 'role') = 'student'
        AND student_id = (auth.jwt() ->> 'student_id')
    );
```

---

## 7. JWT Payload Structure

Supabase Auth issues the JWT. Custom claims are set via a Postgres function hook.

```json
// Admin
{
  "sub": "uuid-from-auth.users",
  "role": "admin",
  "admin_id": "ADM001",
  "email": "admin@aast.edu",
  "exp": 1714299333
}

// Lecturer
{
  "sub": "uuid-from-auth.users",
  "role": "lecturer",
  "lecturer_id": "LEC001",
  "email": "dr.ahmed@aast.edu",
  "exp": 1714299333
}

// Student
{
  "sub": "uuid-from-auth.users",
  "role": "student",
  "student_id": "231006367",
  "email": "student@student.aast.edu",
  "exp": 1714299333
}
```

**Custom claims hook (run in Supabase SQL editor):**
```sql
CREATE OR REPLACE FUNCTION public.custom_jwt_claims(event jsonb)
RETURNS jsonb AS $$
DECLARE
  claims jsonb := event -> 'claims';
  user_role text;
BEGIN
  user_role := (event -> 'claims' ->> 'role');

  IF user_role = 'admin' THEN
    claims := jsonb_set(claims, '{admin_id}',
      to_jsonb((SELECT admin_id FROM admins WHERE auth_user_id = (event ->> 'user_id')::uuid)));

  ELSIF user_role = 'lecturer' THEN
    claims := jsonb_set(claims, '{lecturer_id}',
      to_jsonb((SELECT lecturer_id FROM lecturers WHERE auth_user_id = (event ->> 'user_id')::uuid)));

  ELSIF user_role = 'student' THEN
    claims := jsonb_set(claims, '{student_id}',
      to_jsonb((SELECT student_id FROM students WHERE auth_user_id = (event ->> 'user_id')::uuid)));
  END IF;

  RETURN jsonb_set(event, '{claims}', claims);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 8. Role Capabilities

### Admin
| Area | Can Do |
|---|---|
| Lecturers roster | Add manually, bulk XLSX/CSV, edit, deactivate |
| Students roster | Add manually, bulk XLSX/CSV, edit, deactivate |
| Courses | Create, edit, delete |
| Classes | Create, assign lecturer, set room + schedule |
| Enrollments | Assign students to classes (XLSX or manual search) |
| Analytics | All 8 cross-department panels |
| Lecturer analytics | Punctuality, LES ranking, confusion ranking |
| Exams | Create exam sessions for any class |

### Lecturer
| Area | Can Do |
|---|---|
| Personal info | View own profile, change password |
| Schedule | View own weekly timetable (read-only) |
| My Classes | View assigned classes + student list (read-only) |
| Materials | Upload/delete files for own lectures |
| Attendance | View AI attendance, manual override, QR |
| Live Dashboard | Start/end session, view 7 live panels |
| Reports | Per-student analytics, PDF export, AI plan |
| Exams | Create exam, start proctoring, view incidents + results |

### Student (mobile only)
| Area | Can Do |
|---|---|
| Profile | View own (read-only) |
| Home | View upcoming lectures from enrolled classes |
| Focus Mode | AppState strike sender, receive fresh-brainer overlays |
| Smart Notes | View Gemini-generated notes after session |

---

## 9. Key Relationships

```
admins
  └── manages all tables below

lecturers ──────────────────────────────────────────┐
  └── assigned to classes (by admin)                │
                                                    │ admin analytics:
courses                                             │ punctuality, LES,
  └── classes (sections)                            │ confusion ranking
        ├── class_schedule (weekly slots)           │
        ├── lecturer_id ──────────────────────────-─┘
        ├── enrollments
        │     └── students
        └── lectures (live sessions)
              ├── emotion_log       (vision pipeline, 1/5s)
              ├── attendance_log    (AI | Manual | QR)
              ├── materials         (lecturer uploads)
              ├── focus_strikes     (mobile AppState)
              ├── notifications     (confusion alerts)
              └── exams
                    └── incidents   (proctoring flags)
```

---

## Changelog

| Version | Date | Changes |
|---|---|---|
| v1 | Week 1 | SQLite schema, CSV export layer, custom JWT |
| v2 | 2026-05-09 | Migrated to Supabase PostgreSQL; added admins, lecturers, courses, classes, class_schedule, enrollments, exams tables; removed CSV export layer; replaced custom JWT with Supabase Auth; added RLS policies; roster management moved to admin only; lecturer portal gains personal info, schedule, classes, exam tabs |
