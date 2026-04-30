# Requirements Completeness Checklist: AAST LMS

**Purpose**: Validate that all functional requirements are fully specified, unambiguous, and ready for implementation. Covers all 4 roles (S1–S4) and all 4 phases.
**Created**: 2026-04-30
**Feature**: CLAUDE.md v3 (updated 2026-04-30)

## Requirement Completeness — Vision Pipeline (S1)

- [ ] CHK056 — Is the YOLOv8 person detection threshold/confidence documented (what NMS threshold is acceptable for crowd scenes)? [Completeness, Gap]
- [ ] CHK057 — Is the face_recognition `tolerance` parameter (0.5) documented as a calibratable constant or a fixed value? [Clarity, CLAUDE.md §7.4]
- [ ] CHK058 — Are requirements defined for the minimum face ROI size before running HSEmotion (avoid feeding 5×5px crops to the model)? [Edge Case, Gap]
- [ ] CHK059 — Is the behavior defined when multiple encodings are returned from `face_recognition.face_encodings(rgb_roi)` (currently uses only `encs[0]`)? [Clarity, CLAUDE.md §7.4]
- [ ] CHK060 — Are requirements defined for the `identify_face()` tolerance parameter — is it fixed or tunable via env var? [Clarity, CLAUDE.md §7.4]
- [ ] CHK061 — Is the `HIGH_INTENSITY` threshold (0.65) for Confused vs. Frustrated mapping documented as fixed or configurable? [Clarity, CLAUDE.md §7.3]

## Requirement Completeness — Backend API (S3)

- [ ] CHK062 — Are requirements defined for JWT token expiry (`exp` field in payload)? [Completeness, CLAUDE.md §14 Phase 1 — JWT payload mentioned but expiry duration not specified]
- [ ] CHK063 — Are requirements defined for token refresh (can a student use the same JWT across multiple lectures, or must they re-authenticate)? [Completeness, Gap]
- [ ] CHK064 — Are CORS `allow_origins` requirements documented — should it be `["*"]` in production or restricted to known client origins? [Completeness, CLAUDE.md §13.1 — currently `["*"]`; plan_validation.md §1.4 flags this]
- [ ] CHK065 — Are requirements defined for the `GET /session/upcoming` endpoint — what is "upcoming" (next 24h, next 7 days, all future)? [Clarity, CLAUDE.md §12.3 — not quantified]
- [ ] CHK066 — Is the `POST /attendance/start` endpoint spec documented with what it returns while AI scanning is in progress (polling vs. streaming)? [Completeness, CLAUDE.md §12.2 Submodule C]
- [ ] CHK067 — Are requirements for `GET /attendance/qr/{lecture_id}` documented — QR code format (base64 PNG), size, expiry time? [Completeness, Gap — CHK009 in integration.md covers related]
- [ ] CHK068 — Is the `qrcode` Python library listed in requirements.txt for QR generation? [Gap, CLAUDE.md §13.2 — C9 from speckit-analyze]

## Requirement Completeness — R/Shiny Analytics (S2)

- [ ] CHK069 — Are the 8 Admin Panel queries (Attendance, Engagement Trend, Heatmap, At-Risk, LES, Emotion Distribution, Cluster Map, Time-of-Day) each documented with their exact data source columns from the CSV exports? [Completeness, CLAUDE.md §12.1]
- [ ] CHK070 — Is the "At-Risk Cohort" detection algorithm quantified (">20% engagement drop over 3 consecutive lectures") in terms of how consecutive lectures are identified from the data? [Clarity, CLAUDE.md §12.1 Panel 4]
- [ ] CHK071 — Is the `cluster_lecturers()` K-means input documented — which columns from which CSV are the features? [Completeness, CLAUDE.md §12.1 Panel 7 — mentions `avg_LES, attendance_variance` but CSV source not stated]
- [ ] CHK072 — Are requirements defined for what happens when `compute_engagement()` receives an empty dataframe (no emotion data for a lecture)? [Edge Case, CLAUDE.md §8.5]
- [ ] CHK073 — Is the `trend_slope` computation (linear regression coefficient) documented with what a positive vs. negative slope means for the student report? [Clarity, CLAUDE.md §8.5]
- [ ] CHK074 — Are the `student_report.Rmd` section contents documented precisely enough for a developer to implement without design choices? [Completeness, CLAUDE.md §12.2 Submodule E]

## Requirement Completeness — React Native (S4)

- [ ] CHK075 — Are requirements defined for what the student sees while a lecture session is NOT active (Home screen state when no current lecture)? [Completeness, CLAUDE.md §12.3]
- [ ] CHK076 — Are requirements defined for the maximum number of strikes before the app restricts the student (currently warns at 3, but no lock behavior specified)? [Clarity, CLAUDE.md §12.3 FocusOverlay]
- [ ] CHK077 — Are requirements defined for what happens when the student's JWT expires while in focus mode (mid-lecture)? [Edge Case, Gap]
- [ ] CHK078 — Are accessibility requirements specified for RTL Arabic text in the CaptionBar? [Completeness, CLAUDE.md §12.3 CaptionBar — "RTL-aware" mentioned but not quantified]
- [ ] CHK079 — Are requirements defined for the ✱ marker visual style in the Smart Notes viewer (color, font weight, background highlight)? [Completeness, CLAUDE.md §12.3 Notes — "highlight style" mentioned but not specified]

## Scenario Coverage

- [ ] CHK080 — Are requirements defined for the "first lecture" scenario (no historical emotion data in CSV exports — empty file on first use)? [Coverage, Gap]
- [ ] CHK081 — Are requirements defined for a lecturer who forgets to click "End Lecture" (dangling session — vision thread runs indefinitely)? [Edge Case, Gap]
- [ ] CHK082 — Are requirements defined for what happens when two lecturers start sessions simultaneously (is multi-lecture concurrent operation supported)? [Coverage, Gap]
- [ ] CHK083 — Are requirements defined for AAST-specific date/time format (Arabic locale, Gregorian vs. Hijri calendar display)? [Coverage, Gap]
- [ ] CHK084 — Are requirements defined for handling students who are absent from the entire lecture (no detection events → attendance remains "Absent")? [Coverage, CLAUDE.md §6.2 attendance_log — absence is implied but not explicitly stated as a path]

## Non-Functional Requirements

- [ ] CHK085 — Are the vision pipeline performance requirements quantified (e.g., max processing time per frame to stay within the 5-second interval)? [Measurability, Gap]
- [ ] CHK086 — Are API response time requirements quantified for the live dashboard endpoint `GET /emotion/live` (called every 10 seconds)? [Measurability, Gap]
- [ ] CHK087 — Are memory requirements for the vision pipeline server documented (YOLOv8 + face_recognition + HSEmotion models loaded simultaneously)? [Measurability, Gap — relevant for Railway/DigitalOcean droplet sizing]
- [ ] CHK088 — Are requirements defined for the Whisper API latency budget (5-second chunks processed in <5 seconds to stay real-time)? [Measurability, Gap]
- [ ] CHK089 — Are data retention requirements defined for SQLite (does emotion_log grow indefinitely or is there a cleanup policy)? [Completeness, Gap]

## Notes

- Check items off as completed: `[x]`
- CHK056–CHK061 (vision pipeline gaps) are highest-risk: model behavior in edge cases is hard to specify upfront and may require empirical tuning
- CHK081–CHK082 (concurrent session handling) should be resolved before Phase 2 session.py implementation
- Many non-functional gaps (CHK085–CHK089) are acceptable for a demo-grade capstone; document explicitly as "out of scope for MVP" if so
