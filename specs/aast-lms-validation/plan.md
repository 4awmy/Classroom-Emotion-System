# Implementation Plan: AAST LMS & Emotion Analytics — Full System

**Branch**: `dev` | **Date**: 2026-04-30 | **Spec**: CLAUDE.md (single source of truth)
**Input**: CLAUDE.md v3 (updated 2026-04-30) + ARCHITECTURE.md + StudentPicsDataset.xlsx

## Summary

AI-powered Classroom Emotion Detection System for AAST. A single classroom IP camera feeds
a sequential vision pipeline (YOLO → face_recognition → HSEmotion) that writes real-time
emotion + attendance data to SQLite. R/Shiny serves Admin/Lecturer analytics; React Native
serves students with focus mode, captions, and smart notes. FastAPI is the shared backend.

**Validation scope:** Cross-reference CLAUDE.md WBS tasks against ARCHITECTURE.md contracts,
assess timeline realism for a single developer, and identify MVP candidates for cuts.

## Technical Context

**Language/Version**: Python 3.11 (backend + AI), R 4.3+ (Shiny), TypeScript/React Native (mobile)
**Primary Dependencies**: FastAPI, SQLAlchemy, YOLOv8, face_recognition, HSEmotion-ONNX,
  OpenAI Whisper, Google Gemini 1.5 Flash, R/Shiny + httr2 + plotly, Expo + socket.io-client
**Storage**: SQLite (live, WAL mode) + CSV exports (analytics layer)
**Testing**: Manual integration tests per WBS "Done when" criteria; no automated test suite planned
**Target Platform**: Railway (FastAPI), shinyapps.io or DigitalOcean (Shiny), Android/iOS (Expo)
**Project Type**: Multi-frontend web service + mobile app + AI pipeline
**Performance Goals**: Vision pipeline: 1 frame/5s max; API: <500ms p95; WS: real-time captions
**Constraints**: Free/low-cost tooling only; SQLite (not Postgres); professor-locked tech stack
**Scale/Scope**: 127 students, 1 classroom, demo-grade (not production-grade)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|---|---|---|
| I. Single camera | ✅ PASS | Vision pipeline uses `CLASSROOM_CAMERA_URL` RTSP; no per-student capture |
| II. Sequential pipeline (YOLO→FR→HSE, 5s) | ✅ PASS | `run_pipeline()` loop: YOLO → face_recognition → HSEmotion; `FRAME_INTERVAL=5` |
| III. Interface split (Shiny=Admin+Lecturer, RN=Students) | ✅ PASS | Monorepo enforces this; Section 1 table is non-negotiable |
| IV. Data isolation (SQLite live, CSV analytics) | ✅ PASS | Two-layer strategy documented; R/Shiny has no SQLite connection |
| V. Nightly export (APScheduler, atomic) | ✅ PASS | `export_service.py` uses `os.replace` + `encoding="utf-8-sig"` |
| VI. Whisper only | ✅ PASS | No Google Cloud Speech; `whisper-1` model specified |
| VII. Locked confidence values | ✅ PASS | Hardcoded dict in `vision_pipeline.py`; matches Section 8.2 table |
| VIII. AppState focus mode | ✅ PASS | `AppState.addEventListener` in focus.tsx; no MDM/kiosk |
| IX. Camera-based proctoring | ✅ PASS | YOLOv8 + MediaPipe only; no browser lockdowns |
| X. AAST template injection | ✅ PASS | S2 uses `htmlTemplate()`; custom.css is gitignored-protected |
| XI. R formulas locked | ✅ PASS | `engagement_score.R` matches Section 8 formulas exactly |
| XII. Schema locked Week 1 | ✅ PASS | All 9 schemas committed; no renames planned |
| XIII. Mock endpoints by Week 2 | ✅ PASS | WBS P1-S3-04 deliverable enforces this |
| XIV. 9-digit student IDs | ✅ PASS | Post-fix: `S01` removed; examples use `231006367` |
| XV. `"type"` WS key | ✅ PASS | Post-fix: all payloads use `"type"`; `"event"` key removed |
| XVI. Free/low-cost tooling | ✅ PASS | All services on free tiers; DigitalOcean student credit noted |

**Constitution Check: ALL PASS** ✅ — No violations after CLAUDE.md updates.

## Project Structure

### Documentation (this feature)

```text
specs/aast-lms-validation/
├── plan.md              # This file
├── research.md          # Phase 0: gap analysis + timeline assessment
├── data-model.md        # Phase 1: SQLite schema summary
├── contracts/           # Phase 1: API + WS contracts
│   ├── http-api.md
│   └── websocket.md
└── tasks.md             # Not created here — use /speckit-tasks
```

### Source Code (repository root)

```text
python-api/              # FastAPI backend (S3 + S1)
├── main.py
├── database.py
├── models.py
├── routers/             # 8 routers: auth, emotion, attendance, session, gemini, exam, roster, upload
└── services/            # 5 services: vision_pipeline, whisper_service, gemini_service, proctor_service, export_service

shiny-app/               # R/Shiny web portal (S2)
├── app.R
├── global.R
├── ui/                  # admin_ui.R, lecturer_ui.R
├── server/              # admin_server.R, lecturer_server.R
├── modules/             # engagement_score.R, clustering.R, attendance.R
└── reports/             # student_report.Rmd

react-native-app/        # Student mobile app (S4)
├── app/(auth)/          # login.tsx
├── app/(student)/       # home.tsx, focus.tsx, notes.tsx
├── app/(exam)/          # exam.tsx
├── components/          # CaptionBar.tsx, FocusOverlay.tsx, NotesViewer.tsx
├── store/               # useStore.ts
└── services/            # api.ts
```

**Structure Decision**: Multi-project monorepo. Three separate deployment targets (API/Shiny/RN)
sharing one git repository. No shared code libraries between targets by design.

## Complexity Tracking

No constitution violations. Complexity is inherent to the multi-frontend academic requirement.

## Phase 0: Research Findings Summary

See `research.md` for full details. Key decisions:

1. **Roster photo source**: Google Drive direct download (no service account needed for public
   share links). `requests.get(drive_uc_url)` is simpler than Drive API for this use case.

2. **Hosting**: DigitalOcean ($200 student credit) recommended over Railway free tier to avoid
   sleep cold starts during class hours.

3. **Timeline**: 16 weeks for one developer covering 4 roles is aggressive. See research.md
   for MVP scope recommendation.

4. **ARCHITECTURE.md gap**: Still references ZIP-based roster (Section 7) and `"event"` WS key
   (Sections 4.1, 4.2). Needs a follow-up update once team agrees on v2 contract.

## Phase 1: Design Summary

See `data-model.md` for schema details and `contracts/` for API + WS contracts.

### Remaining Gaps After CLAUDE.md Update

| Gap | Severity | Resolution |
|---|---|---|
| ARCHITECTURE.md Section 7 shows ZIP roster flow | Medium | Update ARCHITECTURE.md in follow-up PR |
| ARCHITECTURE.md Sections 4.1/4.2 use `"event"` key | Medium | Update ARCHITECTURE.md in follow-up PR |
| `generate_synthetic_data.py` uses `S01` IDs | High | Must fix before Phase 1 testing begins |
| `python-api/requirements.txt` missing openpyxl + requests | High | Must fix before roster.py can run |
| P2-S2-11 WBS task doesn't specify XLSX format | Low | Clarify when S2 starts Submodule A |
| No automated test suite planned | Medium | Acceptable for capstone demo; manual tests per WBS |

### MVP Cut Recommendations (single-developer reality)

If timeline pressure requires cuts, recommended priority order to drop (lowest impact first):

1. **Cut P4-S4-02 (auto-submit handling screen)** — The backend auto-submit works without the
   mobile screen transition. Students see a generic "session ended" message.
2. **Cut P3-S4-03 (Notes export Share.share())** — Students can screenshot notes instead.
3. **Cut P4-S2-03 (PDF report)** — Keep the Rmd template but skip PDF generation; show HTML.
4. **Cut Admin Panel 7 (Lecturer Cluster Map)** — K-means clustering is a nice-to-have.
5. **Cut Admin Panel 8 (Time-of-Day Heatmap)** — Limited demo value without months of data.

**Do NOT cut:** Vision pipeline, Whisper captions, emotion live dashboard, confusion alert,
smart notes (core demo value), attendance, exam phone detection.

## Phase 1: Agent Context Update

The plan reference in CLAUDE.md has been noted. The `<!-- SPECKIT START -->` block points to
the plan for additional context.
