# TASKS.md — Single Source of Truth for Task Tracking

> **This is the only place tasks are tracked.** Do not duplicate in CLAUDE.md or anywhere else.
> Architecture, constraints, and specs live in `CLAUDE.md`.
> ✅ = complete | ❌ = retired | — = pending

---

## Roles

| Student | Role | Tech Stack |
|---|---|---|
| **S1** | AI & Vision Lead | Python: YOLO, face_recognition, HSEmotion, Gemini |
| **S2** | R/Shiny UI Lead | R: Admin panels, Lecturer dashboard, analytics, PDF reports |
| **S3** | Backend Lead | Python: FastAPI, SQLite, endpoints, deployment, CI/CD |
| **S4** | Mobile Lead | TypeScript: React Native, Expo, WebSocket client |

---

## Phase 1 — Setup (Week 0)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T001 | S1 | Verify Python 3.11 | ✅ |
| T002 | S3 | Create `python-api/.env` from `.env.example` | ✅ |
| T003 | S4 | Create `react-native-app/.env` from `.env.example` | ✅ |
| T004 | S3 | Add openpyxl / requests / qrcode to `requirements.txt` | ✅ |
| T005 | S1 | Install Python dependencies | ✅ |
| T006 | S2 | Install R packages | ✅ |
| T007 | S4 | Install Node dependencies | ✅ |
| T008 | S3 | Create data directories (`exports/`, `plans/`, `evidence/`) | ✅ |

---

## Phase 2 — Foundation (Weeks 1–2)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T009 | S3 *(all review)* | Data Contract schema README — all 4 approve PR | ✅ |
| T010 | S3 | `database.py` with WAL mode | ✅ |
| T011 | S3 | All ORM models in `models.py` | ✅ |
| T012 | S3 | Verify `create_all()` creates all tables | ✅ |
| T013 | S3 | Auth endpoint with JWT (`POST /auth/login`) | ✅ |
| T014 | S3 | Stub `emotion.py` | ✅ |
| T015 | S3 | Stub `attendance.py` | ✅ |
| T016 | S3 | Stub `session.py` + WebSocket | ✅ |
| T017 | S3 | Stub `gemini.py` | ✅ |
| T018 | S3 | Stub `roster.py` | ✅ |
| T019 | S3 | Stub `upload.py` | ✅ |
| T020 | S3 | Stub `exam.py` | ✅ |
| T021 | S3 | `main.py` with all routers registered | ✅ |
| T022 | S3 | Local server verification (`curl /health` returns 200) | ✅ |
| T023 | S3 | Deploy to DigitalOcean | ✅ |
| T024 | S2 | Wire Shiny `global.R` to API URL | ✅ |
| T025 | S1 | Fix synthetic data seeder (9-digit student IDs) | ✅ |

---

## Phase 3 — Vision Pipeline (Weeks 3–5)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T026 | S1 | Vision pipeline full implementation (`vision_pipeline.py`) | ✅ |
| T027 | S1 | Vision pipeline unit test | ✅ |
| T028 | S3 | Real `session.py` (vision thread spawning, stop_event) | ✅ |
| T029 | S1 | Real `roster.py` (XLSX + photo download + face encodings) | ✅ |
| T030 | S3 | Real `emotion.py` endpoints | ✅ |
| T031 | S3 | Real `attendance.py` endpoints | ✅ |
| T032 | S3 | Export service (atomic CSV, APScheduler 02:00) | ✅ |
| T033 | S1 | ~~Whisper service~~ **RETIRED** — audio/captioning removed from scope | ❌ |

---

## Phase 4 — Shiny Portal (Weeks 4–8)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T034 | S2 | Shiny `global.R` setup | ✅ |
| T035 | S2 | `engagement_score.R` module | ✅ |
| T036 | S2 | `clustering.R` module | ✅ |
| T037 | S2 | `attendance.R` helpers | ✅ |
| T038 | S2 | Admin UI (8 tab panels) | ✅ |
| T039 | S2 | Lecturer UI (5 submodules) | ✅ |
| T040 | S2 | Admin server (all 8 panels) | ✅ |
| T041 | S2 | Lecturer: Roster submodule | ✅ |
| T042 | S2 | Lecturer: Materials submodule | ✅ |
| T043 | S2 | Lecturer: Attendance submodule | ✅ |
| T044 | S2 | Lecturer: Live Dashboard D1–D7 + Camera Switch (Issue 347) | ✅ |
| T045 | S2 | Confusion observer + Gemini alert | ✅ |
| T046 | S2 | Lecturer: Student Reports submodule | ✅ |
| T047 | S2 | `student_report.Rmd` PDF template | ✅ |
| T048 | S2 | Deploy Shiny to shinyapps.io | ✅ |

---

## Phase 5 — Mobile App (Weeks 5–8)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T049 | S4 | Zustand store (`useStore.ts`) + Persistence | ✅ |
| T050 | S4 | API client + WebSocket (`api.ts`) | ✅ |
| T051 | S4 | Login screen (`login.tsx`) | ✅ |
| T052 | S4 | Home screen (`home.tsx`) | ✅ |
| T053 | S4 | Focus mode (`focus.tsx`) | ✅ |
| T054 | S4 | ~~CaptionBar component~~ **RETIRED** — audio/captioning removed from scope | ❌ |
| T055 | S4 | FocusOverlay component | ✅ |
| T056 | S4 | Smart Notes viewer (`notes.tsx`) | ✅ |
| T057 | S4 | NotesViewer component | ✅ |
| T058 | S3 | WS focus strike handler (backend) | ✅ |
| T059 | S3 | Notification endpoint (`POST /notify/lecturer`) | ✅ |

---

## Phase 6 — AI Interventions (Weeks 9–10)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T060 | S1 | Gemini service (`gemini_service.py` — 3 functions) | ✅ |
| T061 | S1 | Real `gemini.py` fresh-brainer question endpoint | ✅ |
| T062 | S1 | Smart notes endpoint (emotion-history based, no transcript) | ✅ |
| T063 | S3 | Intervention plan endpoint (`GET /notes/{sid}/plan`) | ✅ |
| T064 | S1 | Nightly plan generation job (APScheduler → `data/plans/`) | ✅ |

---

## Phase 7 — Exam Proctoring (Weeks 11–13)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T065 | S1 | Proctor service (`proctor_service.py` — all detections) | — |
| T066 | S1 | Proctor loop + auto-submit (3×Sev3 in 10 min) | — |
| T067 | S3 | Real `exam.py` endpoints | — |
| T068 | S4 | Exam screen (`exam.tsx`) | — |
| T069 | S2 | Exam incidents Shiny panel | ✅ |

---

## Phase 8 — Polish (Weeks 14–16)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T070 | S3 | Real upload/material endpoint | — |
| T071 | S3 | GitHub Actions CI/CD (`deploy.yml`) | — |
| T072 | ALL | End-to-end integration test | — |
| T073 | S3 | Final README (clone-to-run guide) | — |
| T074 | S2 | Final Shiny deploy to shinyapps.io | ✅ |

---

## Phase 9 — UI/UX Redesign (AAST Moodle Style)

| Task | Assignee | Description | Status |
|---|---|---|---|
| T075 | S3 | Schema migration: add `snapshot_path TEXT` to `attendance_log` | ✅ |
| T076 | S1 | Vision pipeline: save face snapshot JPEG on first student detection | ✅ |
| T077 | S3 | `GET /attendance/snapshot/{lecture_id}/{student_id}` endpoint | ✅ |
| T078 | S3 | `POST /roster/student` — Admin manually add single student with photo | ✅ |
| T079 | S3 | `GET /roster/students` — list all students for Admin UI | ✅ |
| T080 | S3 | Export service: include `snapshot_path` in `attendance.csv` | ✅ |
| T081 | S3 | Add `confidence_rate` alias to `GET /emotion/live` response (display only) | ✅ |
| T082 | S2 | Shiny: Attendance card grid UI with live snapshots (Submodule C) | ✅ |
| T083 | S2 | Shiny: Update `lecturer_ui.R` Submodule C to use `uiOutput` for card grid | ✅ |
| T084 | S2 | Shiny: Attendance card CSS in `custom.css` (Navy/Gold, no overwrite) | ✅ |
| T085 | S2 | Shiny: Admin Student Management tab UI (Panel 9) | ✅ |
| T086 | S2 | Shiny: Admin Student Management server logic | ✅ |
| T087 | S2 | Shiny: rename "Confidence" → "Confidence Rate" in all UI labels (display only) | ✅ |
| T088 | S4 | React Native: create AAST theme constants (`constants/theme.ts`) | ✅ |
| T089 | S4 | React Native: install and load Roboto font via `expo-font` | ✅ |
| T090 | S4 | React Native: redesign `login.tsx` (Moodle style — Navy header, white card) | ✅ |
| T091 | S4 | React Native: redesign `home.tsx` (card-based dashboard, Gold accent bars) | ✅ |
| T092 | S4 | React Native: lecture timer in `focus.tsx` (HH:MM:SS, Gold) | ✅ |
| T093 | S4 | React Native: redesign `focus.tsx` layout (full Navy, timer, captions) | ✅ |
| T094 | S4 | React Native: redesign `notes.tsx` (Gold highlights, Navy headings) | ✅ |
| T095 | S3 | Confirm `session:start` WS payload includes `start_time` field | ✅ |

---

## Workload Summary

| Student | Role | Tasks | Retired | Est. Hours |
|---|---|---|---|---|
| **S1** | AI & Vision Lead | 17 | 1 (T033) | ~85h |
| **S2** | R/Shiny UI Lead | 18 | 0 | ~90h |
| **S3** | Backend Lead | 24 | 0 | ~72h |
| **S4** | Mobile Lead | 12 | 1 (T054) | ~60h |
| **Shared** | Integration | 3 | 0 | ~6h each |

---

## Parallel Execution Timeline

```
Week 1-2:  S3 builds foundation (T009-T023) — BLOCKS S1, S2, S4
           S1 prepares environment (T001, T005, T025)
           S2 installs R packages (T006)
           S4 installs Node deps (T007)

Week 3-5:  S1 builds vision pipeline (T026-T029)
           S2 starts Shiny portal (T034-T040) — parallel with S1
           S3 builds real endpoints (T028, T030-T032) — supports S1
           S4 starts mobile app (T049-T053) — parallel with S1/S2

Week 5-8:  S2 finishes all Shiny tasks (T041-T048)
           S4 finishes mobile screens (T055-T057)
           S3 finishes support endpoints (T058-T059)

Week 9-10: S1 builds Gemini AI (T060-T062, T064)
           S3 builds plan endpoint (T063)

Week 11-13: S1 builds exam proctoring (T065-T066)
            S3 builds exam endpoints (T067)
            S4 builds exam screen (T068)
            S2 builds exam Shiny panel (T069)

Week 14-16: S3 polishes (T070-T071, T073)
            S2 final deploy (T074)
            ALL integration test (T072)
```

---

## Deployment Issues & Decisions

### Database: Supabase PostgreSQL → SQLite (Local) + Decision for Production

**Problem encountered:**
Direct psycopg2 connections to Supabase PostgreSQL fail on Windows in all configurations:
- Port 443: `server closed the connection unexpectedly`
- Port 5432: timeout
- Port 6543: timeout
- Root cause: DNS for `db.<project-ref>.supabase.co` does not resolve on Windows locally.
- Supabase REST API (PostgREST) works fine — only direct DB connections fail from Windows.

**Current state:** Switched to SQLite locally for development/testing.
- `DATABASE_URL=sqlite:///./data/classroom_v2.db` in `python-api/.env`
- `database.py` detects `sqlite://` prefix and applies `check_same_thread=False`
- All 17 tables created and verified with `create_all()`

**Options considered for production:**

| Option | Cost | Notes |
|---|---|---|
| **Self-hosted PostgreSQL on DO Droplet** | ~$6/mo | PostgreSQL + FastAPI on same machine → localhost connection, no DNS issues. Full control. |
| **Railway PostgreSQL** | Free tier / ~$5/mo | Managed addon on same platform as FastAPI. Easiest integration. |
| **Supabase (REST only)** | Free | Works via PostgREST but requires rewriting all DB calls to HTTP — too invasive. |
| **SQLite in production** | Free | Works but not suitable for concurrent multi-user production load. |

**Decided architecture for production:**
- **DigitalOcean Droplet** ($6/mo) hosts both FastAPI + PostgreSQL (same machine, localhost connection)
- **Supabase Auth kept** for JWT authentication (REST API works, free tier sufficient)
- Switch is transparent — just change `DATABASE_URL` env var from `sqlite://` to `postgresql://`
- No code changes needed (SQLAlchemy handles both dialects)

**Action required (S3):**
1. Provision DO Droplet (Ubuntu 22.04, 1GB RAM minimum)
2. Install PostgreSQL: `apt install postgresql`
3. Create DB and user, set `DATABASE_URL=postgresql://user:pass@localhost/aast_lms`
4. Run `python -c "from database import engine; import models; models.Base.metadata.create_all(bind=engine)"`
5. Update `python-api/.env` on server (never commit real credentials)
