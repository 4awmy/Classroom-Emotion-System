# Task Breakdown — AAST Classroom Emotion System

## Phase 1 Tasks (Weeks 1–3)

### Week 1: Data Contract (CRITICAL PATH)
- [ ] **P1-001** (S3): Create `data-schema/README.md` with 9 SQLite schemas + 6 CSV schemas + JWT payload
- [ ] **P1-002** (All): Review + approve schema PR (all 4 members sign off)
- [ ] **P1-003** (S3): Create `database.py` + `models.py` ORM models from schema
- [ ] **P1-004** (S3): Verify `create_all()` creates all 9 tables without errors

### Week 1–2: FastAPI Setup (S3)
- [ ] **P1-005** (S3): Scaffold `main.py`, CORS, 7 routers (emotion, attendance, session, auth, gemini, exam, roster, upload)
- [ ] **P1-006** (S3): Implement mock `/health` endpoint
- [ ] **P1-007** (S3): Implement mock `POST /auth/login` → JWT token
- [ ] **P1-008** (S3): Implement all other 30+ mock endpoints (return hardcoded JSON)
- [ ] **P1-009** (S3): Deploy to Railway, share URL with team

### Week 1–3: Python Environment (S1)
- [ ] **P1-010** (S1): Install all packages in `requirements.txt` (YOLO, face_recognition, hsemotion, openai, etc.)
- [ ] **P1-011** (S1): Test camera connectivity (RTSP stream, save test_frame.jpg)
- [ ] **P1-012** (S1): Test YOLO on sample classroom image
- [ ] **P1-013** (S1): Test HSEmotion on sample face
- [ ] **P1-014** (S1): Create `notebooks/generate_synthetic_data.py` (seed 1000+ emotion_log rows)

### Week 1–3: R/Shiny Setup (S2)
- [ ] **P1-015** (S2): Install all R packages (shiny, DT, plotly, ggplot2, httr2, etc.)
- [ ] **P1-016** (S2): Audit AAST HTML templates, document slot locations
- [ ] **P1-017** (S2): Create `shiny-app/app.R` shell with `htmlTemplate()` injection
- [ ] **P1-018** (S2): Create `admin_ui.R` with 8 empty tab panels
- [ ] **P1-019** (S2): Create `lecturer_ui.R` with 5 empty submodule tabs
- [ ] **P1-020** (S2): Test httr2 connection to Railway mock API (`GET /health`)
- [ ] **P1-021** (S2): Create `modules/engagement_score.R` skeleton, test against synthetic CSV

### Week 1–3: React Native Setup (S4)
- [ ] **P1-022** (S4): Scaffold Expo project with Router, Zustand, socket.io-client
- [ ] **P1-023** (S4): Create `login.tsx` (calls `POST /auth/login`, stores JWT)
- [ ] **P1-024** (S4): Create `home.tsx` stub (shows after login)
- [ ] **P1-025** (S4): Create `focus.tsx` stub (AppState listener logs to console)
- [ ] **P1-026** (S4): Create `api.ts` WebSocket client (connects to mock WS)
- [ ] **P1-027** (S4): Test login flow + WebSocket connection on Expo Go

### Acceptance Criteria — Phase 1 Complete
- ✅ Schema PR merged + all 4 members approved
- ✅ FastAPI on Railway, all mock routes return 200
- ✅ R/Shiny loads in browser, AAST chrome preserved
- ✅ Expo app starts, login works, WebSocket connects
- ✅ Synthetic data seeded to SQLite (1000+ rows)
- ✅ S2 and S4 have unblocked mock API to build against

---

## Phase 2 Tasks (Weeks 4–8)

### Vision Pipeline (S1)
- [ ] **P2-001** (S1): YOLO person detection on live camera frame
- [ ] **P2-002** (S1): face_recognition encoding → student_id match
- [ ] **P2-003** (S1): HSEmotion emotion classification + map to educational state
- [ ] **P2-004** (S1): Fixed confidence lookup (switch-case, LOCKED values)
- [ ] **P2-005** (S1): 5-second loop, threading, stop_event flag
- [ ] **P2-006** (S1): Roster upload (XLSX → parse → Drive download → encode → INSERT)
- [ ] **P2-007** (S1): Whisper audio capture + transcription
- [ ] **P2-008** (S1): RTSP reconnection (5 retries, 10s backoff)

### Analytics (S2)
- [ ] **P2-009** (S2): Write `compute_engagement()` (locked formulas per Section 8)
- [ ] **P2-010** (S2): Write `cluster_lecturers()` (K-means, k=3)
- [ ] **P2-011** (S2): Implement Admin Panel 1 (Attendance DT + filters + xlsx export)
- [ ] **P2-012** through **P2-018** (S2): Implement Admin Panels 2–8 (one per task)
- [ ] **P2-019** through **P2-023** (S2): Implement Lecturer submodules A–E (one per task)

### Real API (S3)
- [ ] **P2-024** (S3): Real `GET /emotion/live` (read from emotion_log)
- [ ] **P2-025** (S3): Real `POST /attendance/start`, `/manual`
- [ ] **P2-026** (S3): Real `POST /roster/upload` (parse XLSX, download Drive, encode)
- [ ] **P2-027** (S3): Real `POST /upload/material` (Drive upload, INSERT materials)
- [ ] **P2-028** (S3): Real WebSocket broadcast (session:start, session:end, caption)
- [ ] **P2-029** (S3): APScheduler nightly export (atomic CSV writes)
- [ ] **P2-030** (S3): Real JWT auth (validate token, protect routes)
- [ ] **P2-031** (S3): `GET /confusion-rate?lecture_id=&window=` endpoint
- [ ] **P2-032** (S3): `POST /session/broadcast` (WS broadcast any payload)
- [ ] **P2-033** (S3): WAL mode PRAGMA in `main.py` startup

### Mobile (S4)
- [ ] **P2-034** (S4): Home screen fetches `GET /session/upcoming`
- [ ] **P2-035** (S4): AppState background → WS `focus_strike` event
- [ ] **P2-036** (S4): CaptionBar (WS caption → overlay → 4s auto-clear, RTL-aware)
- [ ] **P2-037** (S4): FocusOverlay strike counter + warnings
- [ ] **P2-038** (S4): AsyncStorage offline strike caching

### Acceptance Criteria — Phase 2 Complete
- ✅ Real emotion data flowing to SQLite (vision pipeline running)
- ✅ All 8 admin panels functional (Admin can log in + see analytics)
- ✅ All 5 lecturer submodules functional (Lecturer can upload roster + manage materials)
- ✅ Roster ingestion working (9-digit student IDs, 127 encodings)
- ✅ Nightly CSV exports working (APScheduler at 02:00)
- ✅ Student app AppState strikes logged to DB
- ✅ Captions displayed in real-time on mobile

---

## Phase 3 Tasks (Weeks 9–12)

### Gemini Services (S1)
- [ ] **P3-001** (S1): Implement `generate_smart_notes(transcript, timestamps)`
- [ ] **P3-002** (S1): Implement `generate_fresh_brainer(slide_text)`
- [ ] **P3-003** (S1): Implement `generate_intervention_plan(emotion_history)`
- [ ] **P3-004** (S1): APScheduler nightly plan generation (writes to `data/plans/{student_id}.md`)

### Live Dashboard (S2)
- [ ] **P3-005** through **P3-011** (S2): Implement D1–D7 dashboard panels (7 tasks, one per panel)
- [ ] **P3-012** (S2): Confusion observer (≥0.40 → shinyalert with question)
- [ ] **P3-013** (S2): Student report cards (selectInput → plan rendering + PDF export)

### API Endpoints (S3)
- [ ] **P3-014** (S3): Implement `GET /gemini/question?lecture_id=`
- [ ] **P3-015** (S3): Implement `GET /notes/{student_id}/{lecture_id}`
- [ ] **P3-016** (S3): Implement `GET /notes/{student_id}/plan`
- [ ] **P3-017** (S3): Handle WS `focus_strike` events (INSERT to focus_strikes or incidents)

### Mobile (S4)
- [ ] **P3-018** (S4): Smart Notes viewer (fetch post-session, render with ✱ highlights)
- [ ] **P3-019** (S4): Fresh-brainer bottom-sheet overlay
- [ ] **P3-020** (S4): Notes native share (`Share.share()`)

### Acceptance Criteria — Phase 3 Complete
- ✅ Gemini smart notes generated + available to students
- ✅ Confusion alert fires when class confusion ≥40%
- ✅ Lecturer receives freshbrainer question in Shiny alert
- ✅ Lecturer can ask question → broadcast to all students
- ✅ Students receive question in bottom-sheet
- ✅ Live dashboard shows all 7 panels with real data

---

## Phase 4 Tasks (Weeks 13–16)

### Exam Proctoring (S1)
- [ ] **P4-001** (S1): YOLOv8 phone detection (class 67 in COCO)
- [ ] **P4-002** (S1): MediaPipe head posture extreme rotation
- [ ] **P4-003** (S1): Auto-submit logic (3×Sev-3 in 10 min → POST /exam/submit)
- [ ] **P4-004** (S1): Evidence screenshot capture (save to `data/evidence/`)

### Final Polish (S2 + S3 + S4)
- [ ] **P4-005** (S2): Exam incident panel (DT, severity colors, xlsx export)
- [ ] **P4-006** (S2): AAST UI design review + polish
- [ ] **P4-007** (S2): PDF report generation finalization
- [ ] **P4-008** (S3): `POST /exam/start`, `/exam/submit`, `GET /exam/incidents/{id}`
- [ ] **P4-009** (S3): `POST /notify/lecturer` + WS broadcast
- [ ] **P4-010** (S3): GitHub Actions CI/CD (deploy.yml)
- [ ] **P4-011** (S4): Exam screen + auto-submit handling
- [ ] **P4-012** (All): Full end-to-end integration test (roster → lecture → analytics)

### Acceptance Criteria — Phase 4 Complete
- ✅ Exam proctoring functional (phone + head detection working)
- ✅ Auto-submit triggers after 3 severity-3 incidents
- ✅ All 4 phases implemented + merged to main
- ✅ 15-minute live demo passes all feature tests
- ✅ README.md documents clone-to-run setup
- ✅ GitHub Actions CI/CD passes on main branch pushes

---

## Legend
- S1 = AI Vision Lead (Weeks 1–16)
- S2 = R/Shiny UI Lead (Weeks 1–16)
- S3 = FastAPI Backend Lead (Weeks 1–16)
- S4 = React Native Mobile Lead (Weeks 4–16)

**CRITICAL**: All PRs must include a "Constitution Check" confirming adherence to the 16 principles in `.specify/memory/constitution.md` before merge.
