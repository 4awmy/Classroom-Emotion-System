# Implementation Plan — AAST Classroom Emotion System

## Constitution Check
✅ All 16 principles from `.specify/memory/constitution.md` govern this plan.
✅ No interface mixing (Shiny ≠ React Native).
✅ Data isolation: SQLite ← Vision, CSV → R/Shiny only.
✅ Mock endpoints by Week 2.
✅ Spec-driven development approach approved.

## Phase 1: Foundation (Weeks 1–3)

### S3 (Backend Lead)
- [ ] Week 1: Data Contract — lock SQLite schema (9 tables, 6 CSV exports, JWT payload)
- [ ] Week 1–2: FastAPI skeleton + mock endpoints (all 7 routers)
- [ ] Week 2: Deploy to Railway with mock data
- [ ] Week 3: Integrate with S2 + S4 testing

### S1 (Vision Lead)
- [ ] Week 1–2: Environment setup (YOLO, face_recognition, HSEmotion, Whisper)
- [ ] Week 2–3: Vision pipeline stub + synthetic data seeder
- [ ] Week 3: Test YOLO + HSEmotion on sample images

### S2 (R/Shiny Lead)
- [ ] Week 1–2: Audit AAST templates, set up Shiny shell
- [ ] Week 2–3: Admin UI shell (8 empty panels), Lecturer UI shell (5 tabs)
- [ ] Week 3: Test httr2 connection to mock API

### S4 (Mobile Lead)
- [ ] Week 1–2: Expo scaffold, auth screen stub
- [ ] Week 2–3: WebSocket client, AppState listener
- [ ] Week 3: Test login + home screen against mock API

## Phase 2: Core Features (Weeks 4–8)

### S1
- [ ] YOLO person detection + ROI extraction
- [ ] face_recognition identity matching
- [ ] HSEmotion integration + fixed confidence lookup
- [ ] 5-second loop + threading
- [ ] Roster ingestion (XLSX → Drive photos → encodings)
- [ ] Whisper audio capture + transcription
- [ ] RTSP reconnection logic

### S2
- [ ] `compute_engagement()` module (locked formulas)
- [ ] `cluster_lecturers()` module (K-means, k=3)
- [ ] Admin Panels 1–8 (all 8 complete + functional)
- [ ] Lecturer submodules A–E (all 5 complete)
- [ ] httr2 integration with real API endpoints

### S3
- [ ] Real endpoints for emotion, attendance, roster, materials, session
- [ ] WebSocket broadcast (session:start, session:end, caption, freshbrainer)
- [ ] Nightly export (APScheduler + atomic writes)
- [ ] JWT auth (real token validation)

### S4
- [ ] Home screen (real API fetch)
- [ ] AppState focus mode + WS strikes
- [ ] CaptionBar overlay
- [ ] Offline strike caching

## Phase 3: AI + Live Systems (Weeks 9–12)

### S1
- [ ] Gemini smart notes (`generate_smart_notes()`)
- [ ] Gemini fresh-brainer (`generate_fresh_brainer()`)
- [ ] Gemini intervention plan (`generate_intervention_plan()`)
- [ ] Nightly plan generation (APScheduler)

### S2
- [ ] D1–D7 live dashboard (all 7 panels, reactiveTimer)
- [ ] Confusion observer (≥0.40 → alert + Gemini question)
- [ ] Student report cards (PDF generation)
- [ ] Plan rendering from API

### S3
- [ ] GET `/gemini/question` endpoint
- [ ] GET `/notes/{student_id}/{lecture_id}` endpoint
- [ ] GET `/notes/{student_id}/plan` endpoint
- [ ] WS focus_strike handling

### S4
- [ ] Smart Notes viewer (post-session fetch)
- [ ] Fresh-brainer bottom-sheet overlay
- [ ] Notes export (native share)

## Phase 4: Exam + Polish (Weeks 13–16)

### S1
- [ ] YOLOv8 phone detection
- [ ] MediaPipe head posture detection
- [ ] Auto-submit trigger (3×Sev-3 in 10 min)
- [ ] Evidence screenshot capture

### S2
- [ ] Exam incident panel
- [ ] AAST UI polish (design review)
- [ ] PDF report finalization

### S3
- [ ] Exam endpoints
- [ ] Notify + WS broadcast
- [ ] GitHub Actions CI/CD

### S4
- [ ] Exam screen + auto-submit handling
- [ ] Full end-to-end integration test

## Dependencies & Blockers
- S3 mock endpoints MUST be live by Week 2 (S2 + S4 unblocked)
- Schema lock in Week 1 blocks all feature work
- S1 real models not required until Phase 2 (use synthetic data in Phase 1)

## Deliverables by Phase End
- **Phase 1**: All shells deployed, mock routes live, synthetic data working
- **Phase 2**: Real data flowing, all 8 admin panels functional, roster ingestion working
- **Phase 3**: Gemini live, confusion alert working, smart notes delivered
- **Phase 4**: Full demo ready, exam proctoring working, CI/CD live
