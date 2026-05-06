---
title: Milestone 1 Completion Design
design_depth: deep
task_complexity: medium
date: 2026-05-06
status: approved
---

# Design Document: Milestone 1 Completion (Phase 1)

## 1. Problem Statement
The "Classroom Emotion System" is currently in the late scaffolding stage of Milestone 1. While core structures exist, significant gaps remain that block the S1 (Vision), S2 (Shiny), and S4 (Mobile) leads from performing end-to-end testing. 

Specifically:
- **Environment**: The `requirements.txt` lacks the AI/ML dependencies required for camera and emotion detection testing. — *Rationale: Prevents S1 from validating hardware connectivity as required by task P1-011.*
- **Data Gap**: There is no synthetic data or generator, leaving the R/Shiny analytics modules empty. — *Rationale: Blocks UI validation for S2.*
- **API Gap**: Approximately 15 mock endpoints are missing, and current mocks are "static," preventing stateful testing (e.g., login not persisting, session starts not reflecting in lists). — *Rationale: Blocks S4 from validating the complete mobile user journey (P1-027).*

**Goal**: Deliver a "fully mocked but database-backed" system where data flows through the backend and displays correctly on Mobile and Shiny apps, with a verified AI environment.

## 2. Requirements

### Functional Requirements
- **FR-1**: Implement a one-time synthetic data seeder generating ~50-100 rows per table. [Traces To: P1-014]
- **FR-2**: Complete all 30+ FastAPI mock endpoints using SQLAlchemy for real SQLite persistence. [Traces To: P1-008]
- **FR-3**: Verify full AI stack installation (YOLOv8, HSEmotion, face_recognition). [Traces To: P1-010]
- **FR-4**: Implement a "Low-Volume" one-time data script for quick seeder testing. — *Rationale: User preference for faster initial verification.*

### Non-Functional Requirements
- **NFR-1**: Environment portability (support CPU-based execution for AI libraries). — *Rationale: Ensures testing works on standard development machines without dedicated GPUs.*
- **NFR-2**: Design Consistency (Mocks must follow the `data-schema/README.md` authoritative contract). [Traces To: P1-001]

### Constraints
- **C-1**: Branching — All work must reside in the `milestone-1-completion` branch.
- **C-2**: Python 3.11+ compatibility.

## 3. Approach
We will use a **Database-Integrated Mocking** approach.

### Strategy
1.  **Dependency Fix**: Update `python-api/requirements.txt` with `ultralytics`, `hsemotion`, `face-recognition`, and `google-generativeai`. Update `vision/Dockerfile` to include system-level dependencies (libGL, etc.).
2.  **Stateful API**: Refactor current static mocks to perform `db.add()` and `db.commit()` operations. — *Rationale: This directly supports S4 (Mobile) testing of the JWT flow and S2 (Shiny) testing of real-time data ingestion.*
3.  **Seeder Logic**: Create `python-api/scripts/seed_mock_data.py` using standard `random` and `datetime` libs to populate 50-100 rows per table.

### Decision Matrix
| Criterion | Weight | Database-Backed Mocks | Static JSON Mocks |
|-----------|--------|-----------------------|-------------------|
| Test Realism | 40% | 5: Supports end-to-end flows | 2: Fails to test stateful logic |
| Implementation Speed | 30% | 3: Requires ORM logic | 5: Extremely fast |
| Phase 2 Transition | 30% | 5: Logic is 70% "real" | 1: Must be completely rewritten |
| **Weighted Total** | | **4.4** | **2.6** |

**Alternatives Considered**:
- *Static JSON*: Rejected because it blocks S4 from testing screen transitions that depend on database state.

## 4. Architecture
[Database: SQLite] <--> [ORM: SQLAlchemy] <--> [API: FastAPI] <--> [Frontend: Shiny/React Native]
*Rationale: Using the real DB for mocks ensures the "Database-Backed" requirement is met while keeping infra simple.*

## 5. Agent Team
1.  **`coder` (Backend & Seeder)**: Refactors mocks and writes the seeder.
2.  **`devops_engineer` (Environment)**: Fixes dependencies and Docker.
3.  **`tester` (Verification)**: Validates DB and endpoints.
4.  **`technical_writer` (Documentation)**: Creates `MILESTONE_1_REPORT.md` explaining all completed work.

## 6. Risk Assessment
- **Risk 1: AI Dependency Size**: Large packages may fail on limited machines. *Mitigation: Prioritize CPU-only packages.*
- **Risk 2: SQLite Lock Contention**: Potential locks during seeding. *Mitigation: Run seeder sequentially.*

## 7. Success Criteria
1.  `verify_db.py` passes.
2.  All 30+ endpoints return 200 OK.
3.  Full AI stack installs in a fresh environment.
4.  `MILESTONE_1_REPORT.md` delivered and approved.
