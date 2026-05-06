---
description: "Task list for AAST LMS & Emotion Analytics full system implementation"
---

# Tasks: AAST LMS & Emotion Analytics

**Input**: Design documents from `specs/aast-lms-validation/`
**Prerequisites**: plan.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅ | spec.md → CLAUDE.md (single source of truth)

**Tests**: Not requested — no test tasks generated. Manual verification per "Done when" criteria.

**Organization**: 6 user stories in priority order. Each story is independently deployable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: [US1]–[US6] maps to user stories below

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repo scaffolding, env configuration, and dependency installation.

- [ ] T001 Verify Python 3.11 installed: `python --version` must show 3.11.x (required by face_recognition/dlib)
- [x] T002 [P] Create `python-api/.env` from `python-api/.env.example` and fill all env vars (GEMINI_API_KEY, OPENAI_API_KEY, JWT_SECRET, DATABASE_URL, CLASSROOM_CAMERA_URL, GOOGLE_APPLICATION_CREDENTIALS)
- [x] T003 [P] Create `react-native-app/.env` from `react-native-app/.env.example` and set EXPO_PUBLIC_API_URL + EXPO_PUBLIC_WS_URL
- [x] T004 Add `openpyxl`, `requests`, `qrcode` to `python-api/requirements.txt` (missing per checklist C3/C9)
- [ ] T005 [P] Install Python dependencies: `cd python-api && pip install -r requirements.txt`
- [x] T006 [P] Install R packages: run `install.packages(c("shiny","shinydashboard","shinyalert","shinyjs","DT","plotly","ggplot2","dplyr","lubridate","httr2","openxlsx","rmarkdown","rsconnect","config"))` in R console
- [x] T007 [P] Install Node dependencies: `cd react-native-app && npm install`
- [x] T008 Create required data directories: `mkdir -p python-api/data/exports python-api/data/plans python-api/data/evidence`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: SQLite schema, ORM, FastAPI skeleton, mock endpoints, and JWT auth. **ALL user stories block on this phase.**

**⚠️ CRITICAL**: No user story work can begin until T009–T024 are complete.

- [x] T009 Create/verify `data-schema/README.md` with all 9 SQLite table schemas from CLAUDE.md §6.2 + 6 CSV export schemas from §6.3 + JWT payload `{student_id, role, exp}` — get 4-member PR approval before proceeding
- [x] T010 Implement `python-api/database.py`: SQLAlchemy engine with `sqlite:///./data/classroom_emotions.db`, `check_same_thread=False`, WAL mode `PRAGMA journal_mode=WAL` on startup, `SessionLocal` factory, `get_db()` dependency
- [x] T011 Implement `python-api/models.py`: all 9 SQLAlchemy ORM models (`Student`, `Lecture`, `EmotionLog`, `AttendanceLog`, `Material`, `Incident`, `Transcript`, `Notification`, `FocusStrike`) with correct column types, FK relationships, and defaults from CLAUDE.md §6.2
- [x] T012 Verify schema: `python -c "from database import engine; import models; models.Base.metadata.create_all(bind=engine)"` — must succeed with all 9 tables created in `python-api/data/classroom_emotions.db`
- [x] T013 Implement `python-api/routers/auth.py`: `POST /auth/login` endpoint that validates `{student_id, password}`, returns signed JWT using `python-jose` with `JWT_SECRET` env var, payload `{student_id, role, exp: +24h}`; return 401 for invalid credentials
- [x] T014 [P] Implement stub `python-api/routers/emotion.py`: `GET /emotion/live` returns mock array with 9-digit student IDs (e.g., `231006367`); `GET /emotion/confusion-rate` returns mock `{"confusion_rate": 0.12}`
- [x] T015 [P] Implement stub `python-api/routers/attendance.py`: `POST /attendance/start`, `POST /attendance/manual`, `GET /attendance/qr/{lecture_id}` — all return hardcoded 200 responses
- [x] T016 [P] Implement stub `python-api/routers/session.py`: `POST /session/start` returns `{"status": "started"}`; `POST /session/end` returns `{"status": "ended"}`; `GET /session/upcoming` returns mock lecture array; `POST /session/broadcast` returns `{"delivered_to": 0}`; `GET /session/ws` WebSocket endpoint (echo for now)
- [x] T017 [P] Implement stub `python-api/routers/gemini.py`: `POST /gemini/question` returns `{"question": "What is the difference between X and Y?"}`
- [x] T018 [P] Implement stub `python-api/routers/roster.py`: `POST /roster/upload` returns `{"students_created": 127, "encodings_saved": 127}`
- [x] T019 [P] Implement stub `python-api/routers/upload.py`: `POST /upload/material` returns `{"material_id": "M01", "drive_link": "https://drive.google.com/..."}`
- [x] T020 [P] Implement stub `python-api/routers/exam.py`: `POST /exam/start`, `POST /exam/submit`, `GET /exam/incidents/{exam_id}` — all return hardcoded 200 responses
- [x] T021 Implement `python-api/main.py`: import all 8 routers (auth, emotion, attendance, session, gemini, exam, roster, upload), add CORS middleware `allow_origins=["*"]`, add `GET /health` returning `{"status": "ok"}`, call `models.Base.metadata.create_all(bind=engine)` + WAL PRAGMA, start APScheduler from `export_service`
- [x] T022 Run `uvicorn main:app --reload --port 8000` in `python-api/` and verify `curl http://localhost:8000/health` returns 200
- [ ] T023 Deploy to Railway (or DigitalOcean droplet): set all env vars, run `railway up` or Docker deploy, verify `curl {BASE_URL}/health` returns 200 — share URL with S2 and S4
- [x] T024 Update `shiny-app/global.R`: set `FASTAPI_BASE <- "{deployed_base_url}"` — verify `httr2 GET /health` returns `list(status="ok")` from R console
- [ ] T025 Fix `notebooks/generate_synthetic_data.py`: replace all `S01`/`S02`-style IDs with 9-digit format (e.g., `231006367`–`231006493` for 127 students); run script and verify `emotion_log` has 1000+ rows

**Checkpoint**: Foundation ready — mock endpoints live on Railway, R and RN can start building against them.

---

## Phase 3: User Story 1 — Live Lecture Vision Pipeline (Priority: P1) 🎯 MVP Core

**Goal**: A lecturer can start a lecture session; the classroom camera detects and identifies students, classifies their emotion every 5 seconds, and writes emotion + attendance to SQLite.

**Independent Test**: Run `POST /session/start`, wait 15 seconds, query `SELECT COUNT(*) FROM emotion_log` and `attendance_log` — both should have rows. Verify `emotion` column contains only valid states.

### Implementation

- [ ] T026 [US1] Implement `python-api/services/vision_pipeline.py`: import `cv2`, `threading`, `face_recognition`, `HSEmotionRecognizer`, `YOLO`; implement `map_emotion()`, `get_confidence()` with exact values from CLAUDE.md §8.2; implement `load_student_encodings()`, `identify_face(tolerance=0.5)`; implement `run_pipeline(lecture_id, camera_url, stop_event)` with RTSP reconnection (5 retries, 10s backoff) per CLAUDE.md §7.4 — uses `stop_event.is_set()` as loop guard
- [ ] T027 [US1] Test vision pipeline offline: `python -c "from services.vision_pipeline import map_emotion, get_confidence; assert get_confidence('Focused') == 1.0"` — all 6 confidence values must match
- [x] T028 [US1] Implement real `python-api/routers/session.py`: replace stubs with real logic — `POST /session/start` inserts `Lecture` row, creates `threading.Event`, spawns `threading.Thread(target=run_pipeline, args=(lecture_id, CLASSROOM_CAMERA_URL, stop_event))`, spawns `asyncio.create_task(stream_captions(lecture_id))`; `POST /session/end` sets stop_event, updates `lectures.end_time`; implement WS endpoint `/session/ws` with connection manager (broadcast, add/remove clients)
- [x] T029 [US1] Implement `python-api/routers/roster.py` (real): parse XLSX with `openpyxl`; insert `Student` rows; for each row with `photo_link`, extract Drive `file_id`, download via `requests.get("https://drive.google.com/uc?export=download&id={file_id}", timeout=15)`, check `Content-Type` is `image/*`, run `face_recognition.face_encodings()`, store BLOB — add 10 MB size guard (raise 413)
- [x] T030 [US1] Implement real `python-api/routers/emotion.py`: `GET /emotion/live?lecture_id=&limit=60` queries last N `EmotionLog` rows; `GET /emotion/confusion-rate?lecture_id=&window=120` computes `mean(emotion == "Confused")` over last `window` seconds
- [ ] T031 [US1] Implement real `python-api/routers/attendance.py`: `POST /attendance/start {lecture_id}` marks AI mode active; `POST /attendance/manual` bulk-upserts `AttendanceLog` rows with `method="Manual"`; `GET /attendance/qr/{lecture_id}` generates QR code PNG as base64 using `qrcode` library
- [x] T032 [US1] Implement `python-api/services/export_service.py`: APScheduler at 02:00, `export_all()` function runs 6 SQL queries, writes to temp `.tmp.csv` files, atomically renames with `os.replace`, encoding `utf-8-sig`; test manually: `python -c "from services.export_service import export_all; export_all()"` and verify `data/exports/*.csv` exist with Arabic name support
- [ ] T033 [US1] Implement `python-api/services/whisper_service.py`: `capture_chunk()` via `sounddevice.rec()`, `audio_to_wav_bytes()`, `stream_captions(lecture_id)` async loop — on each chunk: transcribe via `openai_client.audio.transcriptions.create(model="whisper-1")`, insert `Transcript` row, broadcast `{"type": "caption", "text": ..., "lecture_id": ..., "timestamp": ..., "language": "mixed"}` to all WebSocket connections

**Checkpoint**: Full live lecture loop working. Camera → emotion_log writes every 5s, Whisper captions broadcast over WS, attendance auto-detected.

---

## Phase 4: User Story 2 — Admin + Lecturer Web Portal (Priority: P1) 🎯 MVP Core

**Goal**: Admin can view 8 analytics panels from CSV exports. Lecturer can upload roster, manage materials, take attendance, view live dashboard (D1–D7), run confusion alerts, and export student reports.

**Independent Test**: Launch `shiny::runApp()`, navigate to all 8 admin panels and all 5 lecturer submodules — all tabs render without errors using synthetic CSV data.

### Implementation

- [x] T034 [US2] Implement `shiny-app/global.R`: load all packages (`shiny`, `shinydashboard`, `shinyalert`, `shinyjs`, `DT`, `plotly`, `ggplot2`, `dplyr`, `lubridate`, `httr2`, `config`), set `FASTAPI_BASE` from config, define shared CSV load helpers with `reactivePoll` checking file mtime every 60s
- [x] T035 [US2] Implement `shiny-app/modules/engagement_score.R`: `compute_engagement()` function exactly as specified in CLAUDE.md §8.5 — `by_lecture` group_by, `cognitive_load`, `class_valence`, `engagement_level` case_when; `by_student` group_by with `trend_slope` via `lm()`; verify with `compute_engagement(read.csv("../python-api/data/exports/emotions.csv"))`
- [x] T036 [US2] Implement `shiny-app/modules/clustering.R`: `cluster_lecturers(df, k=3)` K-means on `avg_LES` + `attendance_variance`; `cluster_students(df, k=3)` K-means on `avg_engagement` + `avg_cognitive_load`; label clusters "High/Consistent/Needs Support"
- [x] T037 [US2] Implement `shiny-app/modules/attendance.R`: helpers for computing attendance rate per lecture, per student, filtering by date range
- [x] T038 [P] [US2] Implement `shiny-app/ui/admin_ui.R`: 8 tab panels (Attendance, Engagement Trend, Dept Heatmap, At-Risk, LES, Emotion Distribution, Cluster Map, Time-of-Day Heatmap) injected into pre-existing AAST HTML template slots via `htmlTemplate()` — DO NOT rebuild AAST chrome
- [x] T039 [P] [US2] Implement `shiny-app/ui/lecturer_ui.R`: 5 submodule tabs (Roster Setup, Material Upload, Attendance, Live Dashboard, Student Reports) injected into AAST template slots
- [x] T040 [US2] Implement `shiny-app/server/admin_server.R`: all 8 panel server logic — Panel 1: DT attendance + xlsx download; Panel 2: plotly engagement trend line; Panel 3: ggplot2 dept heatmap; Panel 4: at-risk DT (>20% drop over 3 lectures) + `POST /notify/lecturer` button; Panel 5: LES table with conditional formatting (top 10% green, bottom 10% red); Panel 6: stacked bar 6 emotions; Panel 7: K-means cluster scatter; Panel 8: time-of-day heatmap
- [x] T041 [US2] Implement `shiny-app/server/lecturer_server.R` Submodule A (Roster): `fileInput("roster_xlsx", accept=".xlsx")` + progress bar + `httr2 POST /roster/upload` (multipart) + success notification showing `encodings_saved`
- [x] T042 [US2] Implement `shiny-app/server/lecturer_server.R` Submodule B (Materials): `fileInput` + `selectInput(lecture_id)` + title input + `httr2 POST /upload/material` + refreshing materials list from `materials.csv`
- [x] T043 [US2] Implement `shiny-app/server/lecturer_server.R` Submodule C (Attendance): manual DT editable table + `httr2 POST /attendance/manual`; AI mode button + `httr2 POST /attendance/start` + 5s polling; QR fallback `httr2 GET /attendance/qr/{id}` + `renderImage()`
- [x] T044 [US2] Implement `shiny-app/server/lecturer_server.R` Submodule D (Live Dashboard): `reactiveTimer(10000)` polling `GET /emotion/live?lecture_id=` — D1 engagement gauge; D2 emotion timeline plotly; D3 cognitive load value box; D4 class valence gauge; D5 per-student heatmap; D6 persistent struggle DT (≥3 consecutive Confused/Frustrated); D7 peak confusion moment detector
- [x] T045 [US2] Implement confusion observer in Submodule D: `observe()` on live data — compute `confusion_rate` (call `GET /emotion/confusion-rate?lecture_id=&window=120`); if ≥ 0.40: `httr2 POST /gemini/question {lecture_id}` → `shinyalert()` popup with question + "Ask it"/"Dismiss" buttons; "Ask it" → `httr2 POST /session/broadcast {type: "freshbrainer", question: "..."}`
- [x] T046 [US2] Implement `shiny-app/server/lecturer_server.R` Submodule E (Reports): `selectInput(student_id)` + engagement trend chart + cognitive load trend + AI plan from `GET /notes/{student_id}/plan` + PDF `downloadHandler()` calling `rmarkdown::render("reports/student_report.Rmd", params=list(student_id=...))`
- [x] T047 [US2] Implement `shiny-app/reports/student_report.Rmd`: AAST header/footer (navy/gold branding), 6 sections (Executive Summary, engagement trend, emotion distribution pie, cognitive load timeline, AI intervention plan, attendance record); verify PDF renders without errors
- [ ] T048 [US2] Deploy Shiny to shinyapps.io or self-host on DigitalOcean: set `FASTAPI_BASE` to deployed Railway/DO URL in `shiny-app/config.yml`; run `rsconnect::deployApp(appName="aast-lms")`; verify all panels load

**Checkpoint**: Full admin + lecturer portal functional with real CSV data.

---

## Phase 5: User Story 3 — Student Mobile App (Priority: P2)

**Goal**: Student can log in, receive live captions during lectures, use focus mode with strike tracking (offline cache), view smart notes after lecture.

**Independent Test**: Log in on Expo Go → navigate to focus screen → press home button → verify strike appears in SQLite `focus_strikes` table; receive `{type: "caption"}` WS event → CaptionBar displays text for 4s; navigate to notes → rendered markdown with ✱ highlights.

### Implementation

- [ ] T049 [US3] Implement `react-native-app/store/useStore.ts`: Zustand store with `studentId`, `token`, `strikes`, `caption`, `focusActive`, `activeLectureId` state + setters
- [ ] T050 [US3] Implement `react-native-app/services/api.ts`: Axios-based HTTP client with JWT auth header injection (`Authorization: Bearer {token}`); socket.io-client WebSocket connection to `EXPO_PUBLIC_WS_URL/session/ws`; reconnection logic with offline strike queue using `AsyncStorage` — drain queue on reconnect in FIFO order
- [ ] T051 [P] [US3] Implement `react-native-app/app/(auth)/login.tsx`: student_id + password form → `POST /auth/login` → store JWT in Zustand → navigate to home; show error on 401
- [ ] T052 [P] [US3] Implement `react-native-app/app/(student)/home.tsx`: `GET /session/upcoming` → render lecture cards with title, subject, start_time; engagement summary from last lecture; navigation to focus mode and notes
- [ ] T053 [US3] Implement `react-native-app/app/(student)/focus.tsx`: WS connection; `{type: "session:start"}` → set `focusActive=true`, show slide URL; `{type: "session:end"}` → set `focusActive=false`; `{type: "freshbrainer"}` → render bottom-sheet overlay; `AppState.addEventListener` → on background + focusActive: emit `{type: "focus_strike", student_id, lecture_id, strike_type: "app_background"}` (queue if WS offline); `setStrikes(s => s+1)`
- [ ] T054 [US3] Implement `react-native-app/components/CaptionBar.tsx`: `{type: "caption"}` WS event → display text overlay; RTL-aware (`writingDirection: "rtl"` for Arabic); auto-clear after 4 seconds using `setTimeout`
- [ ] T055 [US3] Implement `react-native-app/components/FocusOverlay.tsx`: strike counter display; warn at 3 strikes with highlighted text; show current strike count from Zustand store
- [x] T056 [US3] Implement `react-native-app/app/(student)/notes.tsx`: `GET /notes/{studentId}/{lectureId}` after `session:end`; `react-native-markdown-display` renderer; `✱` sections get `{backgroundColor: '#FFF3CD', fontWeight: 'bold'}` highlight style via `StyleSheet`; `Share.share()` export button
- [x] T057 [US3] Implement `react-native-app/components/NotesViewer.tsx`: extracted markdown viewer component with ✱ highlight rule; used by notes.tsx
- [x] T058 [US3] Implement real `python-api/routers/session.py` strike handler: WS message `{type: "focus_strike"}` → if `context == "exam"` insert `Incident(severity=1, flag_type="app_background")`; else insert `FocusStrike` row
- [x] T059 [US3] Implement `POST /notify/lecturer` in `python-api/routers/attendance.py` (or new `notifications.py`): insert `Notification` row; broadcast `{type: "notification", ...}` over WS so Shiny refreshes without reload

**Checkpoint**: Student app fully functional — login, focus mode, captions, notes, strikes logged.

---

## Phase 6: User Story 4 — AI Interventions (Priority: P3)

**Goal**: Gemini AI generates smart notes per student (post-lecture), fresh-brainer questions during confusion spikes, and 3-step intervention plans.

**Independent Test**: Run `python -c "from services.gemini_service import generate_fresh_brainer; print(generate_fresh_brainer('Big O notation'))"` → prints a ≤2 sentence question; call `GET /notes/231006367/L1` → returns markdown with ✱ markers; call `GET /notes/231006367/plan` → returns 3-item markdown list.

### Implementation

- [ ] T060 [P] [US4] Implement `python-api/services/gemini_service.py`: configure `genai` with `GEMINI_API_KEY`, model `gemini-1.5-flash`; implement `generate_smart_notes(transcript, distraction_timestamps)` → markdown with ✱ re-explanations; `generate_fresh_brainer(slide_text)` → ≤2 sentences; `generate_intervention_plan(emotion_history)` → numbered 3-item markdown list
- [x] T061 [US4] Implement real `python-api/routers/gemini.py`: `POST /gemini/question {lecture_id}` → fetch `slide_url` from `lectures` table → `pdfplumber.open()` → extract text → `generate_fresh_brainer(slide_text)` → return `{"question": ...}` (handle empty PDF gracefully — return generic question if no text)
- [x] T062 [US4] Add `GET /notes/{student_id}/{lecture_id}` to `python-api/routers/gemini.py`: fetch all `Transcript` rows for lecture, fetch `FocusStrike` timestamps for student during lecture → call `generate_smart_notes(combined_transcript, distraction_timestamps)` → return markdown string
- [x] T063 [US4] Add `GET /notes/{student_id}/plan` to `python-api/routers/gemini.py`: read latest `data/plans/{student_id}.md` if exists → return contents; if missing → return 404 with `{"detail": "Plan not yet generated"}`
- [ ] T064 [US4] Add nightly plan generation to `python-api/services/export_service.py` APScheduler (run after `export_all()`): for each student in `students` table, fetch emotion history from `emotion_log`, call `generate_intervention_plan()`, write to `data/plans/{student_id}.md` (overwrite); add retention: keep only the latest file (no rotation needed for MVP)

**Checkpoint**: AI features live. Confusion alerts fire fresh-brainer questions. Smart notes generated post-lecture with ✱ distraction markers.

---

## Phase 7: User Story 5 — Exam Proctoring (Priority: P4)

**Goal**: During an exam, camera detects phones on desks, head rotations, absent students, multiple persons, and identity mismatches. Auto-submit triggers after 3 sev-3 incidents in 10 minutes.

**Independent Test**: Place a phone in camera view → verify `incidents` table gets a `phone_on_desk` row with `severity=3` within 5 seconds.

### Implementation

- [ ] T065 [US5] Implement `python-api/services/proctor_service.py`: `detect_phone(frame)` via YOLO (class 67 = cell phone) → return True/False; `detect_head_rotation(frame)` via MediaPipe FaceMesh → compute yaw angle → flag if >30°; `detect_absence(frame, known_encodings, exam_id)` → no face detected for >5s → flag `absent`; `detect_multiple_persons(frame)` → YOLO person count > 1; `detect_identity_mismatch(frame, expected_student_id, known_encodings)` → face_recognition vs enrolled; all save screenshot to `data/evidence/{exam_id}_{timestamp}.jpg`
- [ ] T066 [US5] Implement `run_proctor(exam_id, camera_url, stop_event)` in `python-api/services/proctor_service.py`: same 5s loop pattern as vision_pipeline; for each detection → INSERT `Incident` row; 60-second polling check: query `SELECT COUNT(*) FROM incidents WHERE exam_id=? AND severity=3 AND timestamp > datetime('now','-10 minutes')` → if ≥ 3 → call `POST /exam/submit` internally
- [ ] T067 [US5] Implement real `python-api/routers/exam.py`: `POST /exam/start {exam_id, student_id}` → create `threading.Event`, spawn `threading.Thread(target=run_proctor, args=(exam_id, CLASSROOM_CAMERA_URL, stop_event))`; `POST /exam/submit {exam_id, student_id, reason}` → set stop_event, broadcast `{type: "exam:autosubmit", exam_id, student_id, reason}` over WS; `GET /exam/incidents/{exam_id}` → query all `Incident` rows for exam
- [ ] T068 [US5] Implement `react-native-app/app/(exam)/exam.tsx`: call `POST /exam/start` on mount; `AppState` listener → background → emit `{type: "focus_strike", ..., context: "exam"}`; listen for `{type: "exam:autosubmit"}` WS event → navigate to "Exam Submitted" screen with reason message
- [ ] T069 [US5] Add exam incidents panel to `shiny-app/server/lecturer_server.R` (or `admin_server.R`): DT reading `incidents.csv`; severity color coding (1=yellow, 2=orange, 3=red); xlsx download button

**Checkpoint**: Full exam proctoring working. Phone detection, head rotation, auto-submit all functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end integration, CI/CD, final README.

- [x] T070 [P] Add `POST /upload/material` real implementation in `python-api/routers/upload.py`: receive file + lecture_id + title → upload to Google Drive via `google-api-python-client` (using `GCLOUD_KEY_B64` env var decoded at startup) → insert `Material` row with `drive_link`
- [ ] T071 [P] Create `.github/workflows/deploy.yml` as specified in CLAUDE.md §15.4: triggers on push to `main`, deploys `python-api` to Railway using `RAILWAY_TOKEN` secret
- [ ] T072 End-to-end integration test (manual, 15-minute session): Roster upload → Start lecture → vision pipeline detects 3+ students → Whisper captions appear in RN app → Shiny live dashboard updates → trigger confusion spike → Gemini question appears → End lecture → next day: CSV exports generated → student views smart notes
- [ ] T073 Final README: clone-to-run guide covering all 3 services (FastAPI, Shiny, React Native) with local setup, env vars, and deployment — save to root `README.md`
- [ ] T074 [P] Deploy Shiny to final hosting (shinyapps.io or DigitalOcean self-hosted): update `shiny-app/config.yml` with production API URL; run full demo dry-run with all 4 panels verified

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundation)**: Depends on Phase 1 — **BLOCKS all user stories**
- **Phase 3 (US1 — Vision)**: Depends on Phase 2 ✓
- **Phase 4 (US2 — Shiny)**: Depends on Phase 2 ✓ (can run in parallel with Phase 3)
- **Phase 5 (US3 — Mobile)**: Depends on Phase 2 ✓ (can run in parallel with Phase 3/4)
- **Phase 6 (US4 — AI)**: Depends on Phase 3 (needs transcripts in DB)
- **Phase 7 (US5 — Exam)**: Depends on Phase 3 (shares vision infrastructure)
- **Phase 8 (Polish)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (Vision Pipeline)**: Foundation → start here first for single developer
- **US2 (Shiny Portal)**: Foundation + mock endpoints → can build in parallel with US1
- **US3 (Mobile App)**: Foundation + WS endpoint → can build in parallel with US1/US2
- **US4 (AI)**: US1 complete (needs transcripts + emotion data in SQLite)
- **US5 (Exam)**: US1 infrastructure reused (shared vision loop pattern)

### Critical Path (Single Developer)

```
Phase 1 (Setup) → Phase 2 (Foundation + mocks deployed) →
  ├── Phase 3 (US1: Vision) → Phase 6 (US4: AI) → Phase 7 (US5: Exam)
  └── Phase 4 (US2: Shiny) [parallel with US1]
  └── Phase 5 (US3: Mobile) [parallel with US1]
→ Phase 8 (Polish + Integration)
```

---

## Parallel Opportunities

```bash
# Phase 2 — run in parallel (T014–T020 are all independent stub files):
Task: T014 - stub emotion.py
Task: T015 - stub attendance.py
Task: T016 - stub session.py
Task: T017 - stub gemini.py
Task: T018 - stub roster.py
Task: T019 - stub upload.py
Task: T020 - stub exam.py

# Phase 4 — run in parallel:
Task: T038 - admin_ui.R
Task: T039 - lecturer_ui.R

# Phase 5 — run in parallel:
Task: T051 - login.tsx
Task: T052 - home.tsx
```

---

## Implementation Strategy

### MVP Scope (Phases 1–5, ~8 weeks solo)

1. Phase 1: Setup (1 day)
2. Phase 2: Foundation + mock endpoints deployed (Week 1–2)
3. Phase 3: Vision pipeline (Week 3–4) — core differentiator
4. Phase 4: Shiny analytics (Week 5–8) — most time-intensive
5. Phase 5: React Native app (Week 6–8, parallel with Shiny)
6. **DEMO-READY**: Live lecture with emotion detection, captions, admin panels, student app

### Full Scope (Phases 1–8, ~12–16 weeks solo)

Add: AI Gemini features (Phase 6), exam proctoring (Phase 7), polish + CI/CD (Phase 8)

### Cut Candidates (if time-pressured)

Drop in this order (lowest demo impact first):
1. T068 Exam mobile auto-submit screen → backend auto-submit still works
2. T056 Notes Share.share() export → screenshots work
3. T047 PDF student report → show HTML in browser
4. T069 Exam incidents Shiny panel → admins can query DB directly
5. T036 K-means clustering → remove Admin Panels 7 from Shiny

---

## Phase 9: Moodle Redesign & Feature Additions

**Spec**: `specs/aast-lms-validation/spec-moodle-redesign.md`
**Plan**: `specs/aast-lms-validation/plan-moodle-redesign.md`

**Constitution Check:**
✅ III. Interface split: RN changes = Student only; Shiny changes = Admin/Lecturer only
✅ VII. Confidence values LOCKED — Req. 7 is display-label rename only
✅ IV. Data isolation — Shiny reads snapshots via API, never direct file access
✅ XII. Schema change is ADD COLUMN only (non-destructive, nullable)

### 9A — Schema & Backend (S3 + S1)

- [ ] T075 [S3] Run migration: add `snapshot_path TEXT` (nullable) to `attendance_log`
  - Update `python-api/models.py` → `AttendanceLog` model: add `snapshot_path = Column(Text, nullable=True)`
  - Run: `python -c "from database import engine; engine.execute('ALTER TABLE attendance_log ADD COLUMN snapshot_path TEXT')"`
  - Verify: `PRAGMA table_info(attendance_log)` shows new column

- [ ] T076 [S1] Add snapshot capture to `python-api/services/vision_pipeline.py`
  - On first student detection per lecture: crop face ROI, check `h >= 100 and w >= 100`
  - If valid: `cv2.imwrite(f"data/snapshots/{lecture_id}/{student_id}.jpg", roi, [cv2.IMWRITE_JPEG_QUALITY, 80])`
  - Pass `snapshot_path` to `AttendanceLog` INSERT
  - On re-detection: overwrite file only (no new DB row)
  - Add `os.makedirs(f"data/snapshots/{lecture_id}", exist_ok=True)` at pipeline start
  - Add `data/snapshots/` to `.gitignore`

- [ ] T077 [S3] Add `GET /attendance/snapshot/{lecture_id}/{student_id}` to `python-api/routers/attendance.py`
  - Returns `FileResponse` with `media_type="image/jpeg"` or 404
  - No auth required for this endpoint

- [ ] T078 [S3] Add `POST /roster/student` to `python-api/routers/roster.py`
  - `multipart/form-data`: `student_id` (9-digit regex validated), `name`, `email` (optional), `photo` (file, max 5MB)
  - Returns 201 `{student_id, name, encoding_saved: bool}`
  - Returns 409 if student_id already exists
  - Returns 422 if no face detected in photo
  - Returns 413 if photo > 5MB

- [ ] T079 [S3] Add `GET /roster/students` to `python-api/routers/roster.py`
  - Returns list of all students: `[{student_id, name, email, has_encoding: bool}]`
  - Used by Admin Student Management tab to populate the DT table

- [ ] T080 [S3] Update `python-api/services/export_service.py` attendance query
  - Change query to: `SELECT student_id, lecture_id, timestamp, status, method, snapshot_path FROM attendance_log`
  - Verify `attendance.csv` includes `snapshot_path` column after re-export

- [ ] T081 [S3] Update `GET /emotion/live` response to include `confidence_rate` alias
  - In `python-api/routers/emotion.py`: add `confidence_rate` field = same value as `confidence`
  - Update Pydantic schema description: `Field(..., description="Fixed confidence proxy for engagement level")`

### 9B — Shiny UI (S2)

- [ ] T082 [S2] Redesign Submodule C (Attendance) in `shiny-app/server/lecturer_server.R`
  - Replace plain DT table with `renderUI` grid of student cards
  - Each card: photo (snapshot if `snapshot_path` set, else `www/default_student.png`), student_id, name, toggle (Present/Absent), reason text input
  - Photo src: `paste0(FASTAPI_BASE, "/attendance/snapshot/", lecture_id, "/", student_id)`
  - Add `shinyWidgets::materialSwitch` per student
  - Save button → `httr2 POST /attendance/manual` for changed rows
  - Add `shinyWidgets` to R package list in global.R

- [ ] T083 [S2] Update `shiny-app/ui/lecturer_ui.R` Submodule C panel
  - Replace static DT UI with `uiOutput("attendance_grid")`
  - Add "Save Attendance" bulk button

- [ ] T084 [S2] Add attendance card CSS to `shiny-app/www/custom.css`
  - `.attendance-grid`, `.student-card`, `.student-card.present`, `.student-card.absent`, `.student-photo` styles
  - Grid: `display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px`
  - Green left border = Present, Red = Absent

- [ ] T085 [S2] Add "Student Management" tab (Panel 9) to `shiny-app/ui/admin_ui.R`
  - Fields: Student ID (text), Full Name (text), Email (optional text), Photo (fileInput)
  - Submit button + success/error notification area
  - DT table showing all current students (from `GET /roster/students`)

- [ ] T086 [S2] Implement "Student Management" server logic in `shiny-app/server/admin_server.R`
  - Validate 9-digit student_id client-side (nchar == 9, all digits)
  - `httr2 multipart POST /roster/student` with all 4 fields
  - Handle 201 → `shinyalert("Success", paste("Student", name, "added"))`, refresh DT
  - Handle 409 → `shinyalert("Error", "Student ID already exists")`
  - Handle 422 → `shinyalert("Error", "No face detected in the photo")`
  - Handle 413 → `shinyalert("Error", "Photo too large (max 5MB)")`

- [ ] T087 [S2] Add "Confidence Rate" label updates across `shiny-app/`
  - In all DT column headers: rename `"confidence"` → `"Confidence Rate"`
  - Add `DT::formatStyle` tooltip or column title: "Model certainty for this emotion prediction"
  - This is display-layer only — no backend values change

### 9C — React Native (S4)

- [ ] T088 [S4] Create `react-native-app/constants/theme.ts`
  - Export `AAST` constants: `navy: '#002147'`, `gold: '#C9A84C'`, `white: '#FFFFFF'`, `lightGray: '#F5F5F5'`, `fontFamily: 'Roboto'`

- [ ] T089 [S4] Install Roboto font
  - `npx expo install expo-font @expo-google-fonts/roboto`
  - Load fonts in `_layout.tsx` using `useFonts({ Roboto_400Regular, Roboto_700Bold })`

- [ ] T090 [S4] Redesign `react-native-app/app/(auth)/login.tsx`
  - AAST logo centered at top
  - Navy header background, white card below for inputs
  - Gold "Sign In" button with Navy text
  - Roboto font throughout

- [ ] T091 [S4] Redesign `react-native-app/app/(student)/home.tsx`
  - Navy top bar with AAST logo + "Welcome, {name}"
  - Upcoming lecture cards: white background, subtle shadow, Gold left accent bar
  - Course name (bold), Lecturer name, Time fields per card
  - Gold "Join Lecture" button
  - Bottom tab bar: Navy background, Gold active icon/label

- [ ] T092 [S4] Add lecture timer to `react-native-app/app/(student)/focus.tsx`
  - Parse `start_time` from `session:start` WS payload → store as `lectureStart: Date`
  - `setInterval` every 1000ms: `setElapsed(Math.floor((Date.now() - lectureStart.getTime()) / 1000))`
  - `clearInterval` on `session:end` (freeze timer, do NOT reset)
  - Display: `HH:MM:SS` format, Gold text (`#C9A84C`), 36px bold, labeled "Lecture Duration"
  - Timer uses local `Date.now()` math — resilient to network drops

- [ ] T093 [S4] Redesign `react-native-app/app/(student)/focus.tsx` overall layout
  - Navy full-screen background
  - Timer prominent at top-center
  - Strike counter below timer (Gold text, warn red at 3 strikes)
  - Caption overlay at very bottom
  - Slide URL "View Slides" button (Gold outlined button)

- [ ] T094 [S4] Redesign `react-native-app/app/(student)/notes.tsx`
  - White background, card-style sections
  - ✱ highlights in Gold background (`backgroundColor: '#FFF3CD'`)
  - Navy section headings
  - Gold "Share Notes" button

- [ ] T095 [S4] Confirm `session:start` WS payload includes `start_time`
  - Check `python-api/routers/session.py` broadcast payload
  - If missing: add `"start_time": lecture.start_time.isoformat()` to the payload
  - S4 relies on this for the timer

---

## Notes

- [P] tasks = different files, no blocking dependencies — can be launched simultaneously
- [Story] labels enable single-story MVP slicing
- All tasks reference exact file paths for LLM-executable implementation
- Constitution compliance gate: re-check `.specify/memory/constitution.md` before Phase 3
- Verify tests fail before implementing (N/A here — no test tasks requested)
- Commit after each T0XX or logical group
- Stop at each Phase Checkpoint to validate independently
