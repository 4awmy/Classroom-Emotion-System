# Integration Point Verification Checklist: AAST LMS

**Purpose**: Validate that all integration points between subsystems (FastAPI ↔ R/Shiny, FastAPI ↔ React Native, Vision Pipeline ↔ SQLite, Whisper ↔ WebSocket) are fully and consistently specified.
**Created**: 2026-04-30
**Feature**: CLAUDE.md §11, §12 + specs/aast-lms-validation/contracts/

## WebSocket Payload Consistency

- [ ] CHK029 — Are all server→client WebSocket message types listed in `contracts/websocket.md` also handled in the React Native client spec (CLAUDE.md §12.3)? [Consistency, contracts/websocket.md vs CLAUDE.md §12.3]
- [ ] CHK030 — Are all client→server WebSocket message types listed in `contracts/websocket.md` also handled in the FastAPI `session.py` spec? [Consistency, contracts/websocket.md vs CLAUDE.md §11 State 2]
- [ ] CHK031 — Is the `"type"` key (not `"event"`) consistently used across ALL WebSocket payload examples in CLAUDE.md? [Consistency, CLAUDE.md §9.2, §11, §12.3]
- [ ] CHK032 — Are the `focus_strike` payload field names (`student_id`, `lecture_id`, `strike_type`, `context`) consistently documented across the React Native emit spec and the FastAPI handler spec? [Consistency, CLAUDE.md §12.3 vs §11 State 2 Step 5]
- [ ] CHK033 — Is the `context: "exam"` field for exam-mode strikes documented in both the mobile emit code and the server routing logic? [Completeness, contracts/websocket.md, CLAUDE.md §12.3]
- [ ] CHK034 — Are requirements defined for what happens when the WebSocket connection drops mid-lecture for the CaptionBar (should it retry, show a "disconnected" state, or silently fail)? [Edge Case, Gap]

## Vision Pipeline ↔ SQLite Integration

- [ ] CHK035 — Is the `load_student_encodings()` call timing documented (at pipeline start, or reloaded per-frame, or on roster change)? [Clarity, CLAUDE.md §7.4]
- [ ] CHK036 — Is the `seen_today` set reset between lecture sessions (i.e., per `run_pipeline()` call, not persisted across calls)? [Clarity, CLAUDE.md §7.4]
- [ ] CHK037 — Are requirements defined for what happens when `db.commit()` fails in the vision pipeline loop (skip and continue, or stop the loop)? [Edge Case, Gap]
- [ ] CHK038 — Is the `stop_event.set()` call in `POST /session/end` documented as the authoritative mechanism to terminate the vision thread? [Completeness, CLAUDE.md §7.4, §11 State 2 Step 8]
- [ ] CHK039 — Are requirements defined for the maximum time between `session/end` being called and the vision thread actually stopping (e.g., within one `FRAME_INTERVAL = 5` seconds)? [Measurability, Gap]

## Whisper ↔ Transcript ↔ WebSocket Integration

- [ ] CHK040 — Is the `active_connections` list shared between `whisper_service.py` and `session.py` documented as a module-level variable or dependency-injected? [Clarity, CLAUDE.md §9.2]
- [ ] CHK041 — Are requirements defined for what happens when Whisper returns an empty transcription (empty string after `.strip()`)? [Edge Case, CLAUDE.md §9.2 — "if not text: continue" is specified]
- [ ] CHK042 — Is the Whisper chunk language stored as `"mixed"` regardless of actual detected language, or should it store the detected language per chunk? [Clarity, CLAUDE.md §9.2 — currently hardcoded to "mixed"]
- [ ] CHK043 — Are requirements defined for what happens when the OpenAI Whisper API call times out or returns an error (retry, skip, or stop stream)? [Edge Case, CLAUDE.md §9.2 — "except Exception: print" specified but no retry logic]

## R/Shiny ↔ CSV ↔ FastAPI Integration

- [ ] CHK044 — Are requirements defined for what happens when R/Shiny reads a CSV that is mid-write (i.e., before `os.replace` completes)? [Edge Case — atomic write with `os.replace` prevents this; confirm it's documented as the reason]
- [ ] CHK045 — Is the `reactivePoll` interval (60s) aligned with the expected freshness requirement for analytics data? [Measurability, CLAUDE.md §12.1]
- [ ] CHK046 — Are all CSV column names required by `compute_engagement()` in R guaranteed to be present in `emotions.csv`? [Consistency, CLAUDE.md §6.3 vs §8.5]
- [ ] CHK047 — Is the `httr2 POST /roster/upload` call from Shiny documented with the correct multipart field name (`roster_xlsx`) matching the FastAPI endpoint parameter? [Consistency, CLAUDE.md §12.2 Submodule A vs §10.3]
- [ ] CHK048 — Are requirements defined for how Shiny handles a non-200 response from `POST /roster/upload` (e.g., 413 Too Large)? [Edge Case, Gap]

## Gemini AI Integration Points

- [ ] CHK049 — Are requirements defined for what Gemini returns when slide text is empty (no PDF content extracted)? [Edge Case, Gap]
- [ ] CHK050 — Is the `generate_fresh_brainer()` output length constraint (≤ 2 sentences) documented as a prompt instruction and enforced at the API layer? [Measurability, CLAUDE.md §11 State 3 Step 4]
- [ ] CHK051 — Are requirements defined for what happens when the Gemini API is rate-limited (15 rpm free tier)? [Edge Case, Gap]
- [ ] CHK052 — Is the nightly `generate_intervention_plan()` job documented with its trigger, the input it reads (emotion_log over all lectures), and the output path (`data/plans/{student_id}.md`)? [Completeness, CLAUDE.md §16 P3-S1-04]

## Requirements Completeness

- [ ] CHK053 — Are requirements defined for all 3 attendance modes (AI, Manual, QR) in terms of what the Shiny UI shows to the lecturer during each mode? [Completeness, CLAUDE.md §12.2 Submodule C]
- [ ] CHK054 — Are requirements defined for the exam auto-submit 60-second polling check — specifically, does it query `incidents` per `exam_id` or per `student_id`? [Clarity, CLAUDE.md §16 P4-S1-03]
- [ ] CHK055 — Are requirements for the offline strike cache drain queue specified with an ordering guarantee (FIFO)? [Completeness, contracts/websocket.md]

## Notes

- Check items off as completed: `[x]`
- Gap items (CHK034, CHK037, CHK039, CHK048–CHK051) are the highest-risk integration gaps
- CHK042: Language detection hardcoded to "mixed" — confirm this is intentional for the AAST use case
