# Claude Code Task — Plan Validation & Architecture Update

## Context
Read these files FIRST before doing anything:
1. `docs/plan_validation.md` — Pre-computed analysis with specific issues found
2. `CLAUDE.md` — The current project plan (source of truth)
3. `ARCHITECTURE.md` — Data contracts and flow specs
4. `StudentPicsDataset.xlsx` — Real dataset (127 students, 9-digit IDs, Google Drive photo links)

## Task 1: Fix CLAUDE.md (apply all fixes from plan_validation.md)

### 1A — Roster Pipeline Redesign
The plan assumes `images.zip` with `{student_id}.jpg` files. The REAL dataset has Google Drive photo links.

Update these sections:
- **Section 10 (Roster Ingestion Pipeline):** Replace ZIP extraction with Google Drive download flow. New flow: parse Excel/CSV → for each student, download photo from Drive link → face_recognition encode → store BLOB.
- **Section 12.2 Submodule A (Roster Setup):** Change `fileInput("images_zip")` to `fileInput("roster_xlsx")` that accepts the Excel file directly.
- **Section 14 (Phase 1 S3 mock):** Update `/roster/upload` mock to accept Excel format.
- **Section 10.3 (roster.py implementation):** Rewrite the endpoint to parse XLSX, download from Google Drive, encode faces.

### 1B — Student ID Format
Replace ALL instances of `S01`, `S02` format examples with `231006367`-style 9-digit IDs. This affects:
- Section 3.2 (Auth), 3.4 (Emotion), 3.7 (Notes), 3.8 (Exam)
- Section 6.2 (schema comments)
- Section 14 (mock endpoint examples)
- Section 16 (WBS "Done when" criteria)

### 1C — WebSocket Payload Standardization
Standardize ALL WebSocket payloads to use ARCHITECTURE.md format:
- Change `"event"` key to `"type"` everywhere in CLAUDE.md
- In Section 9.2 (whisper_service.py): change broadcast payload to include `type`, `timestamp`, `language`
- In Section 12.3 (focus.tsx strike): change `socket.emit('strike', {event: ..., type: ...})` to `{type: "focus_strike", strike_type: "app_background", ...}`
- Add `context: "exam"` field documentation for exam strikes

### 1D — Add 7 Missing WBS Tasks
Add these to the appropriate phase in Section 16:
1. P2-S3-XX: Implement confusion-rate endpoint `GET /emotion/confusion-rate` (MOVE from Phase 3 to Phase 2 — Shiny live dashboard needs it)
2. P2-S4-XX: Implement offline strike caching + reconnect drain queue
3. P2-S3-XX: Implement atomic CSV export with `os.replace` pattern
4. P2-S1-XX: Implement RTSP camera reconnection (5 retries, 10s backoff)
5. P4-S1-03: Expand auto-submit to include 60-second polling check implementation
6. P2-S3-XX: Implement `POST /session/broadcast` endpoint
7. P2-S3-XX: Implement real JWT auth (not just stub)

### 1E — Add WAL Mode to database.py
In Section 5.2 or 13.1, add SQLite WAL mode enablement:
```python
with engine.connect() as conn:
    conn.execute(text("PRAGMA journal_mode=WAL"))
```

### 1F — Add Thread Stop Mechanism
In Section 7.4 (vision_pipeline.py), add a `threading.Event` stop flag to allow `POST /session/end` to gracefully stop the vision loop.

## Task 2: Architecture / Tech Stack Review

Write a new section at the bottom of `docs/plan_validation.md` titled "## 6. Tech Stack Review" covering:

1. **Is the current stack (FastAPI + R/Shiny + React Native + SQLite) the right choice?** Give honest pros/cons.
2. **Student account perks:** We have GitHub Student Developer Pack, which unlocks free credits on Azure, DigitalOcean, Heroku, etc. Does this change any hosting decisions? Should we use a different hosting provider than Railway/shinyapps.io?
3. **Could the stack be simpler?** The professor likely locked the tech stack, but note if there were simpler alternatives (e.g., Streamlit instead of R/Shiny, or a monolithic Next.js app).
4. **Is SQLite sufficient at scale?** 127 students × 12 emotion samples/minute × 1-hour lecture = ~91K rows per lecture. Will SQLite handle this without locking issues?
5. **Railway free tier limitations:** 500 hours/month. Is this enough for a system that needs to run during all class hours?

## Task 3: Validate the Updated Plan

After making all changes, re-read the updated CLAUDE.md and verify:
- All 9 SQLite table schemas are still consistent
- All HTTP endpoints in Section 3 match their WBS tasks
- All WebSocket payloads in Section 4 use `"type"` key consistently
- The roster flow now correctly handles XLSX + Drive links
- No S01-format student IDs remain in examples
- The WBS task count is complete — no ARCHITECTURE.md feature is untasked

Write a brief "## 7. Post-Update Verification" section at the bottom of `docs/plan_validation.md` confirming all fixes were applied or listing any remaining issues.

## Task 4: Speckit Formal Plan Validation

After Tasks 1-3 are complete, use the installed Speckit skills to formally validate the updated plan matches our project vision.

### 4A — Constitution Setup
Run `/speckit-constitution` — use CLAUDE.md Section 17 ("Key Constraints") as the constitutional principles. These 16 constraints are non-negotiable rules that every implementation must respect. Map them as:
- Principle 1: Single classroom camera only
- Principle 2: Sequential vision pipeline (YOLO → face_recognition → HSEmotion, 1 frame/5s)
- Principle 3: Interface split (R/Shiny = Admin+Lecturer, React Native = Students)
- Principle 4: Data isolation (SQLite live, CSV for R/Shiny, never direct DB)
- Principle 5: Locked confidence values
- Principle 6: Camera-based proctoring only (no JS lockdowns)
- And so on for all 16 constraints

Save the filled constitution to `.specify/memory/constitution.md`.

### 4B — Run /speckit-plan
Run `/speckit-plan` with this guidance:
```
Validate the UPDATED CLAUDE.md against ARCHITECTURE.md. The project is an AI-powered Classroom Emotion Detection System for AAST (Arab Academy). Key context:
- Real dataset: 127 students with 9-digit IDs and Google Drive photo links
- One person will do most of the implementation work across all 4 roles (S1-S4)
- We have GitHub Student Developer Pack perks (free cloud credits)
- The tech stack is R/Shiny + FastAPI + React Native + SQLite (likely locked by professor)
- Focus on: Are there any remaining gaps between CLAUDE.md WBS and ARCHITECTURE.md contracts? Any unrealistic timelines? Any features that should be cut for MVP?
```

### 4C — Run /speckit-analyze (optional but recommended)
Run `/speckit-analyze` for cross-artifact consistency:
- Verify CLAUDE.md, ARCHITECTURE.md, and the actual codebase are aligned
- Flag any contracts defined in ARCHITECTURE.md that are still not covered by a WBS task
- Flag any WBS task that contradicts a constitutional principle

### 4D — Run /speckit-checklist
Run `/speckit-checklist` to generate quality checklists:
- Requirements completeness checklist
- Data contract coverage checklist  
- Integration point verification checklist

Save all Speckit outputs to the `specs/` directory as the Speckit workflow expects.

## Rules
- Be direct, no fluff
- Do NOT create new files beyond what's specified (except Speckit's own output files in `specs/`)
- Do NOT change ARCHITECTURE.md — it's the contract spec. Only CLAUDE.md gets updated.
- For Speckit skills, follow the skill instructions in `.claude/skills/speckit-*/SKILL.md` exactly.
