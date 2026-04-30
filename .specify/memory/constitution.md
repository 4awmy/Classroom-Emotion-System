<!--
SYNC IMPACT REPORT
==================
Version change: [TEMPLATE] → 1.0.0 (initial fill — all 16 principles from CLAUDE.md §17)
Modified principles: N/A (first population)
Added sections: Core Principles (16), Interface & Data Isolation, Development Governance
Removed sections: N/A
Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check section references principles by number
  ✅ .specify/templates/spec-template.md — no structural changes needed; principles govern scope
  ✅ .specify/templates/tasks-template.md — no structural changes needed
Follow-up TODOs:
  - RATIFICATION_DATE set to 2026-04-30 (today, first formal adoption)
  - ARCHITECTURE.md still shows old WebSocket event key — update in follow-up PR
-->

# AAST LMS & Emotion Analytics Constitution

## Core Principles

### I. Single Classroom Camera
The system MUST use exactly one fixed IP camera per classroom for all vision-based detection
(emotion, attendance, exam proctoring). Student webcams, mobile device cameras, or any
per-student capture device are FORBIDDEN. All AI processing is server-side in
`vision_pipeline.py`. No exceptions.

### II. Sequential Vision Pipeline — Fixed Rate
The vision pipeline MUST run in the exact sequence: **YOLOv8 person detection →
face_recognition identity match → HSEmotion emotion classification**, processing one
frame every 5 seconds. This rate is non-negotiable. No parallel processing of pipeline
stages, no higher frequency, no skipping stages.

### III. Interface Split — Non-Negotiable
| Audience | Interface | Technology |
|---|---|---|
| Admin + Lecturer | Web portal | R + Shiny ONLY |
| Students | Mobile app | React Native (Expo) ONLY |

Admin and Lecturer features MUST NOT be built in React Native. Student features MUST NOT
be built in R/Shiny. Never mix these surfaces.

### IV. Data Isolation — Live vs. Analytics
- Live lecture data MUST be written to SQLite (never to CSV files directly).
- R/Shiny MUST read ONLY the nightly-exported static CSVs in `data/exports/`.
- R/Shiny MUST NEVER connect directly to the SQLite database.
- Violation of this rule causes concurrent read/write file locks that crash the analytics layer.

### V. Nightly Export — APScheduler Only
The nightly CSV export MUST run at 02:00 via APScheduler in `export_service.py`. It MUST
use atomic writes (`os.replace` pattern) and `encoding="utf-8-sig"` for Arabic name support.
Manual export scripts are acceptable for testing only; the production trigger MUST be the
scheduler.

### VI. Whisper for Audio Transcription
All classroom audio transcription MUST use OpenAI Whisper (`whisper-1` model). Google Cloud
Speech-to-Text is FORBIDDEN because it cannot handle the lecturer's Arabic/English
code-switching without a declared language. Whisper's auto-detection handles `ar-EG/en-US`
mixed audio natively.

### VII. Locked Engagement Confidence Values
Engagement confidence values are FIXED per emotion state and MUST NOT be derived from
model softmax outputs:

| State | Confidence |
|---|---|
| Focused | 1.00 |
| Engaged | 0.85 |
| Confused | 0.55 |
| Anxious | 0.35 |
| Frustrated | 0.25 |
| Disengaged | 0.00 |

`engagement_score == confidence`. These values are academically defensible and must not
be changed without a full team review and schema migration.

### VIII. AppState API for Mobile Focus Mode
The student focus mode MUST use React Native's `AppState` API to detect when the app
enters the background. OS-level device locks, kiosk mode, or any MDM enforcement are
FORBIDDEN. Focus monitoring is advisory only; strikes are recorded but the device is
never locked.

### IX. Camera-Based Exam Proctoring Only
Exam integrity monitoring MUST use: YOLOv8 (phone/person detection) + MediaPipe FaceMesh
(head posture). JavaScript browser lockdowns, DOM manipulation, or browser extension
hooks are FORBIDDEN. All detection is server-side from the classroom camera feed.

### X. R/Shiny Injects into Pre-Existing AAST Templates
S2 MUST inject Shiny `renderUI` components into the slots of the pre-existing AAST HTML
templates using `htmlTemplate()` or `includeHTML()`. Rebuilding or overwriting the AAST
chrome (navy `#002147`, gold `#C9A84C`, Cairo font, RTL support) is FORBIDDEN.

### XI. R Analytics Formulas Are Locked
S2 MUST implement engagement metrics using exactly the formulas in CLAUDE.md Section 8:
- `cognitive_load = confusion_rate + frustration_rate`
- `class_valence = (focused + engaged) - (frustrated + disengaged + anxious)`
- K-means clustering with k=3 for both lecturer and student clusters

Deviating from these formulas invalidates the academic study results.

### XII. SQLite Schema Is Locked After Week 1
All 9 SQLite table schemas are locked after the Week 1 PR is merged and approved by all 4
team members. Column names MUST NEVER be renamed after lock. New columns MAY be added via
migration but MUST NOT break existing queries. Schema changes require a full team review PR.

### XIII. Mock Endpoints Live by End of Week 2
S3 MUST have all mock API endpoints deployed to Railway by end of Week 2. S2 and S4 MUST
NEVER be blocked waiting for AI models or real data. Development decoupling via mocks is
mandatory.

### XIV. Student IDs Are 9-Digit Strings
All student identifiers MUST use the AAST 9-digit format (e.g., `231006367`). Short-form
IDs like `S01` or `S02` are FORBIDDEN in production code, database entries, and API
examples. The `student_id` column is `TEXT PRIMARY KEY` to accommodate leading zeros.

### XV. WebSocket Payloads Use `"type"` Key
All WebSocket messages (server → client and client → server) MUST use `"type"` as the
event discriminator key. The `"event"` key is FORBIDDEN. Standard payload types:
`session:start`, `session:end`, `caption`, `freshbrainer`, `focus_strike`, `exam:autosubmit`.
Exam context strikes MUST include `"context": "exam"` to route to the `incidents` table.

### XVI. All Tooling Must Be Free or Low-Cost
Every tool, service, and API MUST use a free tier or low-cost plan appropriate for a
student capstone project:
- Hosting: Railway free (500h/month) or DigitalOcean ($200 student credit)
- Shiny: shinyapps.io free (25h/month) or self-hosted on same droplet
- AI Models: Gemini 1.5 Flash (free tier: 15 rpm, 1M tokens/day), Whisper (~$0.006/min)
- Mobile: Expo Go + EAS Build free tier
- No paid AI APIs (no GPT-4, no Claude API in production app)

## Interface & Data Isolation Rules

These rules elaborate on Principles III and IV with concrete enforcement points:

1. **Never import SQLAlchemy in R code.** The R/Shiny layer MUST use only `httr2` (HTTP)
   and `read.csv()` (CSV files). No RODBC, no RSQLite connections to the live database.

2. **Never write student-facing UI in Shiny.** Any `input$student_*` widget in the Shiny
   app is a constitution violation.

3. **Never write admin/lecturer logic in React Native.** Lecturer controls (start/end lecture,
   roster upload, material upload) MUST be in Shiny only.

4. **Vision pipeline writes, API reads.** The vision pipeline thread writes emotion rows.
   The FastAPI endpoint reads them. No direct DB access from R or React Native.

5. **WAL mode MUST be enabled** at startup: `PRAGMA journal_mode=WAL` — enables concurrent
   reads from the API while the vision pipeline thread writes.

## Development Governance

### Amendment Procedure
1. Any team member proposes a change via a PR to `dev` with the updated `CLAUDE.md` section.
2. All 4 team members must approve before merge.
3. Schema changes (Principle XII) additionally require a SQLite migration script.
4. This constitution file must be updated in the same PR.
5. Version bump: PATCH for wording; MINOR for new principle; MAJOR for principle removal.

### Versioning Policy
- `CONSTITUTION_VERSION` follows semantic versioning.
- Current: `1.0.0` — initial adoption with all 16 principles.

### Compliance Review
- Every PR must include a "Constitution Check" confirming no principles are violated.
- The `plan-template.md` Constitution Check gate enforces this before implementation begins.
- Violations found in code review MUST be fixed before merge — not post-merge.

### Source of Truth Precedence
`CLAUDE.md` > `ARCHITECTURE.md` > `constitution.md` > individual team member opinions.
In case of conflict between documents, `CLAUDE.md` governs.

**Version**: 1.0.0 | **Ratified**: 2026-04-30 | **Last Amended**: 2026-04-30
