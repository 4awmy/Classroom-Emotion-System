## Summary

Aligns the Phase 2 Foundation codebase with the validated Speckit plan.

### Code Fixes
- **database.py**: Added SQLite WAL mode via event listener for concurrent reads
- **emotion.py**: Replaced S01/S02 with real 9-digit AAST student IDs
- **roster.py**: Rewrote from images_zip to single .xlsx upload
- **exam.py**: Replaced S01 with 231006367 in mock incidents
- **session.py**: Fixed broadcast field event to type (ARCHITECTURE.md contract)
- **requirements.txt**: Added openpyxl, requests, qrcode, apscheduler
- Created data/exports/, data/plans/, data/evidence/ directories

### Documentation
- Updated CLAUDE.md (roster pipeline, 7 missing WBS tasks, WAL, thread stop)
- Added docs/plan_validation.md, workload_division.md
- Added .specify/memory/constitution.md (16 principles)
- Added specs/aast-lms-validation/ (Speckit plan, research, 74 tasks)

### Verification
- Server imports pass: `python -c "from main import app; print('OK')"`

### Constitution Compliance
- Principle I: Single camera - no changes
- Principle IV: Data isolation - WAL mode improves this
- Principle XII: Schema unchanged
- Principle XIV: 9-digit student IDs now enforced
- Principle XV: WebSocket payloads use type key
