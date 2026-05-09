# Implementation Plan — Schema v2 Migration & Full Feature Build
> Based on: `data-schema/README.md` (v2, Supabase PostgreSQL)
> Current state: ~60% complete on v1 SQLite schema

---

## Context

The project currently runs on SQLite with a custom JWT auth system and a CSV export layer for R/Shiny. The new data schema (v2) migrates to **Supabase PostgreSQL** with built-in Auth, adds missing user/academic structure tables, removes the CSV export layer entirely, and introduces automated lecture scheduling. This plan covers the full gap between what exists today and the target architecture.

---

## Phase 1 — Supabase Setup & Schema Migration

### 1.1 Supabase Project Setup
- Create Supabase project at supabase.com
- Run full schema SQL from `data-schema/README.md §5` in Supabase SQL editor
  - All 15 tables: admins, lecturers, students, courses, classes, class_schedule, enrollments, lectures, exams, materials, emotion_log, attendance_log, incidents, notifications, focus_strikes
- Enable RLS on all tables
- Run all RLS policies from `data-schema/README.md §6`
- Install custom JWT claims hook (`public.custom_jwt_claims` function from §7)

### 1.2 FastAPI — Switch to PostgreSQL
**File:** `python-api/database.py`
- Change connection string: `sqlite:///` → `postgresql://postgres:[PW]@db.[REF].supabase.co:5432/postgres`
- Remove WAL mode pragma (PostgreSQL handles concurrency natively)
- Add `psycopg2-binary` to `requirements.txt`

**File:** `python-api/models.py` — **FULL REWRITE**
- Add missing models: `Admin`, `Lecturer`, `Course`, `Class`, `ClassSchedule`, `Enrollment`, `Exam`
- Update `Student`: add `auth_user_id` (UUID), `department`, `year`, `photo_url`; `face_encoding` stays as `LargeBinary` (maps to `BYTEA`)
- Update `Lecture`: add `class_id` FK → `Class`, `session_type`, `scheduled_start`, `auto_generated`
- Update `Incident`: change `exam_id` from plain TEXT to FK → `Exam`
- Remove `Transcript` model (audio pipeline retired)

### 1.3 Replace Custom Auth with Supabase Auth
**File:** `python-api/routers/auth.py` — **REPLACE**
- Remove custom JWT generation + hardcoded password check
- New: verify Supabase JWT using `python-jose` + Supabase JWT secret
- Extract `role`, `lecturer_id` / `student_id` / `admin_id` from JWT claims
- `get_current_user()` dependency used in all protected routes

**File:** `python-api/.env`
```
SUPABASE_URL=https://[ref].supabase.co
SUPABASE_SERVICE_KEY=[service_role_key]
SUPABASE_JWT_SECRET=[jwt_secret]
DATABASE_URL=postgresql://postgres:[pw]@db.[ref].supabase.co:5432/postgres
```

---

## Phase 2 — New Backend Routers & Services

### 2.1 Admin Roster Router (NEW)
**File:** `python-api/routers/admin.py` — **NEW FILE**

Endpoints:
- `POST /admin/lecturers` — create lecturer (manual form)
- `GET  /admin/lecturers` — list all lecturers
- `PUT  /admin/lecturers/{lecturer_id}` — edit lecturer
- `DELETE /admin/lecturers/{lecturer_id}` — deactivate
- `POST /admin/lecturers/bulk` — XLSX/CSV upload → parse → insert lecturers
- `POST /admin/students` — create student manually
- `GET  /admin/students` — list all students
- `PUT  /admin/students/{student_id}` — edit
- `DELETE /admin/students/{student_id}` — deactivate
- `POST /admin/students/bulk` — XLSX/CSV → parse → insert students (with face encoding from photo_url)

### 2.2 Course & Class Router (NEW)
**File:** `python-api/routers/courses.py` — **NEW FILE**

Endpoints:
- `POST /courses` — create course
- `GET  /courses` — list all
- `POST /courses/{course_id}/classes` — create class, assign lecturer
- `GET  /courses/{course_id}/classes` — list classes
- `PUT  /classes/{class_id}` — edit class
- `POST /classes/{class_id}/schedule` — add schedule slot
- `POST /classes/{class_id}/enroll` — enroll students (XLSX or list of student_ids)
- `DELETE /classes/{class_id}/enroll/{student_id}` — remove student
- `GET  /classes/{class_id}/students` — list enrolled students (lecturer read-only view)

### 2.3 Exam Router (REWRITE)
**File:** `python-api/routers/exam.py` — **REWRITE**

Currently 3 stubs. Replace with:
- `POST /exam` — create exam (class_id, title, scheduled_start)
- `GET  /exam?class_id=` — list exams for a class
- `POST /exam/{exam_id}/start` — start exam → create lecture record with `session_type='exam'`
- `POST /exam/{exam_id}/end` — end exam
- `GET  /exam/{exam_id}/incidents` — list all incidents for exam
- `POST /exam/{exam_id}/submit/{student_id}` — manual or auto-submit
- Auto-submit trigger: inside `proctor_service` — if 3× sev-3 in 10 min window → call submit

### 2.4 Lecture Auto-Scheduler (NEW)
**File:** `python-api/services/lecture_scheduler.py` — **NEW FILE**

- APScheduler job every 1 minute: `auto_start_lectures()`
  - Query `class_schedule` for current `day_of_week` + time window
  - If no lecture exists for this class today → INSERT lecture + call `start_pipeline(lecture_id)`
- APScheduler job every 1 minute: `auto_end_lectures()`
  - Check `class_schedule.end_time` vs NOW
  - If past end → UPDATE `lectures.end_time` + call `stop_pipeline(lecture_id)`
- Register in `main.py` (import triggers scheduler start, same pattern as export_service)

### 2.5 Remove / Retire
**File:** `python-api/services/export_service.py` — **DELETE**
- R/Shiny queries Supabase PostgreSQL directly — CSV export no longer needed

**File:** `python-api/routers/roster.py` — **MERGE INTO admin.py**
- Roster upload logic moves to `POST /admin/students/bulk`
- Face encoding logic reused in new endpoint

---

## Phase 3 — Shiny App: Admin Portal Expansion

### 3.1 Remove CSV layer, add direct DB connection
**File:** `shiny-app/global.R`
- Add `library(RPostgres)` + `library(DBI)`
- Replace all `read.csv()` calls with `dbGetQuery(con, sql)`
- Connection: `dbConnect(RPostgres::Postgres(), host=..., password=Sys.getenv("SUPABASE_DB_PASSWORD"))`
- Keep `FASTAPI_BASE` for write endpoints (session start/end, vision pipeline triggers)

### 3.2 Admin UI — Add Roster & Course Management tabs
**File:** `shiny-app/ui/admin_ui.R`

New tabs alongside existing 8 analytics panels:
- **Roster — Lecturers:** DT table + Add form (name, dept, title, email, phone) + XLSX import
- **Roster — Students:** DT table + Add form + XLSX import
- **Courses:** DT table + new course form
- **Classes:** Nested under course — DT + new class form (section, room, lecturer dropdown, schedule)
- **Enrollments:** Per class — search student by ID/name + Add; or XLSX upload

**File:** `shiny-app/server/admin_server.R`
- Lecturer CRUD: `httr2 GET/POST/PUT /admin/lecturers`
- Student CRUD: `httr2 GET/POST/PUT /admin/students`
- Bulk imports: `fileInput` → `httr2 POST /admin/lecturers/bulk` or `/admin/students/bulk`
- Course/class: `httr2 POST /courses`, `POST /courses/{id}/classes`
- Enrollment: `httr2 POST /classes/{id}/enroll`

### 3.3 Lecturer UI — Add Personal Info, Schedule, Classes, Exam tabs
**File:** `shiny-app/ui/lecturer_ui.R`

Add 3 new tabs at start + 1 at end. Full tab order:
- **A — Personal Info:** Readonly profile card (photo, name, title, dept, email, phone) + Change Password button
- **B — Schedule:** Weekly timetable grid (Mon–Sun × time slots) from `class_schedule JOIN classes`
- **C — My Classes:** Cards per class (course title, section, room, student count) + `[View Students]` + `[Start Lecture]` (manual override)
- **D — Materials:** Upload slides/files (existing)
- **E — Attendance:** AI / Manual / QR (existing)
- **F — Live Dashboard:** 7 emotion panels (existing, renamed from D)
- **G — Reports:** Per-student analytics + PDF (existing, renamed from E)
- **H — Exam:** 3 sub-tabs:
  - *Setup:* create exam form + scheduled exams list with `[Start]`
  - *Live Proctor:* incident feed (auto-refresh 5s) + at-risk table + auto-submit alerts
  - *Results:* past exams dropdown + incident breakdown chart + per-student table + XLSX export

**File:** `shiny-app/server/lecturer_server.R`
- Personal info: `dbGetQuery` for lecturer row by `lecturer_id` from JWT
- Schedule: `dbGetQuery` joining `class_schedule → classes → courses`
- My Classes: `dbGetQuery` for classes + student count via enrollments
- Exam setup: `httr2 POST /exam`, `GET /exam?class_id=`
- Exam live: `reactiveTimer(5000)` → `httr2 GET /exam/{id}/incidents`
- Exam results: `dbGetQuery` for incidents per exam + `downloadHandler` XLSX export

### 3.4 Remove Roster tab from Lecturer portal
**File:** `shiny-app/ui/lecturer_ui.R` + `shiny-app/server/lecturer_server.R`
- Remove Submodule A (Roster Setup) entirely — admin-only now
- Remove all `POST /roster/upload` calls from lecturer server

---

## Phase 4 — React Native: Supabase Auth + Schedule

### 4.1 Replace custom auth with Supabase JS client
**File:** `react-native-app/services/api.ts`
- Add `@supabase/supabase-js`
- `supabase.auth.signInWithPassword({ email, password })` → JWT
- Store JWT in Zustand + AsyncStorage
- All API calls attach `Authorization: Bearer <token>`

### 4.2 Home screen — pull schedule from Supabase
**File:** `react-native-app/app/(student)/home.tsx`
- Query `class_schedule JOIN classes JOIN courses JOIN enrollments WHERE student_id = me`
- Show upcoming lectures for today/tomorrow
- Active lecture → `[Join Focus Mode]` button

---

## Phase 5 — Bug Fixes

| Bug | File | Fix |
|---|---|---|
| Vision pipeline runs at 2s not 5s | `services/vision_pipeline.py:139` | Change `inference_interval = 2.0` → `5.0` |
| Export runs too frequently | `services/export_service.py` | Delete file (replaced by Supabase direct queries) |
| `exam_id` in incidents is plain string | `models.py` | Add FK → `exams.exam_id` |
| Hardcoded `admin/admin` login in Shiny | `shiny-app/app.R` | Replace with Supabase Auth API call |

---

## Critical Files Summary

| File | Action |
|---|---|
| `python-api/models.py` | Full rewrite — add 7 missing models |
| `python-api/database.py` | Switch to PostgreSQL |
| `python-api/routers/auth.py` | Replace with Supabase JWT verification |
| `python-api/routers/admin.py` | **NEW** — lecturer + student CRUD + bulk import |
| `python-api/routers/courses.py` | **NEW** — course + class + enrollment CRUD |
| `python-api/routers/exam.py` | Rewrite — full exam lifecycle |
| `python-api/services/lecture_scheduler.py` | **NEW** — auto start/end lectures |
| `python-api/services/export_service.py` | **DELETE** |
| `python-api/main.py` | Register new routers |
| `python-api/requirements.txt` | Add psycopg2-binary, supabase |
| `shiny-app/global.R` | Add RPostgres, remove CSV loading |
| `shiny-app/ui/admin_ui.R` | Add Roster + Courses + Classes tabs |
| `shiny-app/server/admin_server.R` | Wire new admin tabs |
| `shiny-app/ui/lecturer_ui.R` | Add A/B/C/H tabs, remove Roster tab |
| `shiny-app/server/lecturer_server.R` | Wire new tabs, remove roster logic |
| `react-native-app/services/api.ts` | Replace auth with Supabase JS client |
| `react-native-app/app/(student)/home.tsx` | Wire schedule from Supabase |
| `data-schema/README.md` | Already updated (v2 complete) |

---

## Execution Order

```
Phase 1 — Supabase + DB migration
    └── Phase 2 — Backend routers & services
            └── Phase 3 — Shiny admin + lecturer UI  ─┐
            └── Phase 4 — React Native auth + schedule ┤ parallel
            └── Phase 5 — Bug fixes                   ─┘
```

---

## Verification Checklist

- [ ] Supabase: all 15 tables exist in Table Editor
- [ ] RLS: each role cannot see other roles' data
- [ ] FastAPI: `GET /health` → 200; login returns valid Supabase JWT
- [ ] Admin: add lecturer via form → appears in `lecturers` table
- [ ] Admin: upload student XLSX → students appear with face encodings
- [ ] Auto-scheduler: set class_schedule slot 2 min ahead → lecture auto-created + pipeline starts
- [ ] Shiny admin: analytics panels load from PostgreSQL (not CSV)
- [ ] Shiny lecturer: Schedule tab shows weekly grid; Exam tab creates + starts exam
- [ ] Exam flow: 3× Sev-3 incidents → auto-submit fires
- [ ] React Native: Supabase login → home shows enrolled class schedule
