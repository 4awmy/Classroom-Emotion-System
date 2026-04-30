# Data Contract Coverage Checklist: AAST LMS

**Purpose**: Validate completeness, clarity, and consistency of all data contracts (SQLite schemas, CSV exports, HTTP API, WS payloads) before implementation begins.
**Created**: 2026-04-30
**Feature**: CLAUDE.md §6, §9, §13 + specs/aast-lms-validation/contracts/

## Requirement Completeness

- [ ] CHK001 — Are all 9 SQLite table schemas fully specified with column names, types, constraints, and FK references? [Completeness, CLAUDE.md §6.2]
- [ ] CHK002 — Are the 6 CSV export schemas fully specified with column names that match the SQLite source queries exactly? [Completeness, CLAUDE.md §6.3]
- [ ] CHK003 — Is the `students.face_encoding` BLOB format documented (128-dim float64 numpy array, `tobytes()` serialization)? [Completeness, CLAUDE.md §6.2]
- [ ] CHK004 — Are all 9 SQLite tables included in the nightly export or is the exclusion of some (e.g., `focus_strikes`) intentional and documented? [Completeness, Gap — `focus_strikes` not in export list]
- [ ] CHK005 — Is the `student_id` format (9-digit string, e.g., `231006367`) consistently documented across schemas, mock examples, and seeder script? [Consistency, CLAUDE.md §6.2, §14]
- [ ] CHK006 — Are all HTTP API endpoints in `contracts/http-api.md` consistent with CLAUDE.md Section 13 router definitions? [Consistency, specs/aast-lms-validation/contracts/http-api.md]
- [ ] CHK007 — Are response schemas (field names, types, nullable fields) fully specified for all API endpoints, or only for some? [Completeness, Gap — several endpoints lack full response schemas]
- [ ] CHK008 — Is the `engagement_score` column in `emotion_log` documented as equal to `confidence` (not a separate computation)? [Clarity, CLAUDE.md §6.2, §8.1]

## Requirement Clarity

- [ ] CHK009 — Is the 9-digit `student_id` defined as `TEXT` (not `INTEGER`) to preserve leading zeros, and is this rationale documented? [Clarity, CLAUDE.md §6.2]
- [ ] CHK010 — Is the `language` field in `transcripts` documented with all allowed values (`ar`, `en`, `mixed`)? [Clarity, CLAUDE.md §6.2]
- [ ] CHK011 — Is the `status` field in `attendance_log` documented with all allowed values (`Present`, `Absent`)? [Clarity, CLAUDE.md §6.2]
- [ ] CHK012 — Is the `method` field in `attendance_log` documented with all allowed values (`AI`, `Manual`, `QR`)? [Clarity, CLAUDE.md §6.2]
- [ ] CHK013 — Is the `severity` field in `incidents` documented with its 1/2/3 scale and what each level means? [Clarity, CLAUDE.md §6.2]
- [ ] CHK014 — Is the Drive photo URL format (`https://drive.google.com/open?id=FILE_ID`) documented as the expected input format in the roster upload spec? [Clarity, CLAUDE.md §10.2]
- [ ] CHK015 — Is the maximum upload size limit (10 MB) for `POST /roster/upload` documented in the endpoint spec? [Clarity, CLAUDE.md §10.3]

## Requirement Consistency

- [ ] CHK016 — Do the CSV export column names in §6.3 exactly match the SELECT column aliases in the `export_service.py` query spec? [Consistency, CLAUDE.md §6.3 vs §6.4]
- [ ] CHK017 — Is the `emotion` field in `emotion_log` constrained to the 6 allowed states (`Focused`, `Engaged`, `Confused`, `Anxious`, `Frustrated`, `Disengaged`) consistently across schema, vision pipeline, and R analytics? [Consistency, CLAUDE.md §6.2, §7.3, §8.2]
- [ ] CHK018 — Are the confidence values in the `EMOTION_CONFIDENCE` dict in `vision_pipeline.py` identical to the table in CLAUDE.md §8.2? [Consistency, CLAUDE.md §7.4 vs §8.2]
- [ ] CHK019 — Does the HTTP API contract for `GET /emotion/live` return all fields required by the R/Shiny `live_timeline` aggregation? [Consistency, specs/contracts/http-api.md vs CLAUDE.md §12.2 D2]
- [ ] CHK020 — Is the `confusion_rate` formula in CLAUDE.md §8.4 consistent between the R module spec (§8.5) and the API endpoint spec (`GET /emotion/confusion-rate`)? [Consistency, CLAUDE.md §8.4 vs contracts/http-api.md]

## Acceptance Criteria Quality

- [ ] CHK021 — Is the WAL mode requirement stated as a testable criterion (`PRAGMA journal_mode=WAL` must return `wal` before the pipeline starts)? [Measurability, CLAUDE.md §13.1]
- [ ] CHK022 — Is the atomic CSV export requirement testable (can it be verified that `os.replace` is used rather than direct `to_csv`)? [Measurability, CLAUDE.md §6.4]
- [ ] CHK023 — Are the "Done when" criteria for all WBS data-contract tasks objective and verifiable (not subjective)? [Measurability, CLAUDE.md §16 P1-S3-01, P1-S3-02]

## Edge Case Coverage

- [ ] CHK024 — Are requirements defined for what happens when a student's face encoding cannot be computed from the Drive photo (e.g., no face detected)? [Edge Case, CLAUDE.md §10.3]
- [ ] CHK025 — Are requirements defined for the case where a student's Drive photo URL returns a virus-scan HTML page instead of an image? [Edge Case, Gap — C7 in speckit-analyze report]
- [ ] CHK026 — Are requirements defined for duplicate `student_id` entries in the roster XLSX (e.g., student uploaded twice)? [Edge Case, CLAUDE.md §10.3]
- [ ] CHK027 — Are requirements defined for what happens when the nightly export runs while an active lecture is writing emotion rows? [Edge Case, CLAUDE.md §6.4 — WAL mode handles this, but is it explicitly stated?]
- [ ] CHK028 — Are retention/rotation requirements defined for files in `data/plans/` and `data/evidence/`? [Edge Case, Gap — C8 in speckit-analyze report]

## Notes

- Check items off as completed: `[x]`
- Gap items (CHK007, CHK024–CHK028) require spec additions before implementation
- CHK004: `focus_strikes` data is not exported to CSV — confirm this is intentional
