# Workload Division — 4 Students

## Role Definitions
| Student | Role | Tech Stack |
|---|---|---|
| **S1** | AI & Vision Lead | Python: YOLO, face_recognition, HSEmotion, Whisper, Gemini |
| **S2** | R/Shiny UI Lead | R: Admin panels, Lecturer dashboard, analytics, PDF reports |
| **S3** | Backend Lead | Python: FastAPI, SQLite, endpoints, deployment, CI/CD |
| **S4** | Mobile Lead | TypeScript: React Native, Expo, WebSocket client |

---

## Task Assignments

### Phase 1: Setup (Week 0) — Everyone sets up their own stack
| Task | Assignee | Description |
|---|---|---|
| T001 | S1 | Verify Python 3.11 |
| T002 | S3 | Create python-api/.env |
| T003 | S4 | Create react-native-app/.env |
| T004 | S3 | Add openpyxl/requests/qrcode to requirements.txt |
| T005 | S1 | Install Python dependencies |
| T006 | S2 | Install R packages |
| T007 | S4 | Install Node dependencies |
| T008 | S3 | Create data directories |

### Phase 2: Foundation (Weeks 1-2) — S3 leads, blocks everyone
| Task | Assignee | Description |
|---|---|---|
| T009 | S3 *(all review)* | Data Contract schema README |
| T010 | S3 | database.py with WAL mode |
| T011 | S3 | All 9 ORM models |
| T012 | S3 | Verify schema creation |
| T013 | S3 | Auth endpoint with JWT |
| T014 | S3 | Stub emotion.py |
| T015 | S3 | Stub attendance.py |
| T016 | S3 | Stub session.py + WebSocket |
| T017 | S3 | Stub gemini.py |
| T018 | S3 | Stub roster.py |
| T019 | S3 | Stub upload.py |
| T020 | S3 | Stub exam.py |
| T021 | S3 | main.py with all routers |
| T022 | S3 | Local server verification |
| T023 | S3 | Deploy to Railway/DigitalOcean |
| T024 | S2 | Wire Shiny global.R to API |
| T025 | S1 | Fix synthetic data seeder |

### Phase 3: Vision Pipeline (Weeks 3-5) — S1 leads, S3 supports
| Task | Assignee | Description |
|---|---|---|
| T026 | **S1** | Vision pipeline full implementation |
| T027 | **S1** | Vision pipeline unit test |
| T028 | **S3** | Real session.py (thread spawning) |
| T029 | **S1** | Real roster.py (XLSX + Drive download) |
| T030 | **S3** | Real emotion.py endpoints |
| T031 | **S3** | Real attendance.py endpoints |
| T032 | **S3** | Export service (atomic CSV) |
| T033 | **S1** | Whisper service implementation |

### Phase 4: Shiny Portal (Weeks 4-8) — S2 owns entirely
| Task | Assignee | Description |
|---|---|---|
| T034 | **S2** | Shiny global.R setup |
| T035 | **S2** | engagement_score.R module |
| T036 | **S2** | clustering.R module |
| T037 | **S2** | attendance.R helpers |
| T038 | **S2** | Admin UI (8 tab panels) |
| T039 | **S2** | Lecturer UI (5 submodules) |
| T040 | **S2** | Admin server (all 8 panels) |
| T041 | **S2** | Lecturer: Roster submodule |
| T042 | **S2** | Lecturer: Materials submodule |
| T043 | **S2** | Lecturer: Attendance submodule |
| T044 | **S2** | Lecturer: Live Dashboard D1-D7 |
| T045 | **S2** | Confusion observer + Gemini alert |
| T046 | **S2** | Lecturer: Student Reports |
| T047 | **S2** | student_report.Rmd PDF |
| T048 | **S2** | Deploy Shiny to hosting |

### Phase 5: Mobile App (Weeks 5-8) — S4 leads, S3 supports
| Task | Assignee | Description |
|---|---|---|
| T049 | **S4** | Zustand store |
| T050 | **S4** | API client + WebSocket |
| T051 | **S4** | Login screen |
| T052 | **S4** | Home screen |
| T053 | **S4** | Focus mode |
| T054 | **S4** | CaptionBar component |
| T055 | **S4** | FocusOverlay component |
| T056 | **S4** | Smart Notes viewer |
| T057 | **S4** | NotesViewer component |
| T058 | **S3** | WS strike handler (backend) |
| T059 | **S3** | Notification endpoint (backend) |

### Phase 6: AI Interventions (Weeks 9-10) — S1 + S3
| Task | Assignee | Description |
|---|---|---|
| T060 | **S1** | Gemini service implementation |
| T061 | **S1** | Real gemini.py question endpoint |
| T062 | **S1** | Smart notes endpoint |
| T063 | **S3** | Intervention plan endpoint |
| T064 | **S1** | Nightly plan generation job |

### Phase 7: Exam Proctoring (Weeks 11-13) — S1 + S3 + S4 + S2
| Task | Assignee | Description |
|---|---|---|
| T065 | **S1** | Proctor service (all detections) |
| T066 | **S1** | Proctor loop + auto-submit |
| T067 | **S3** | Real exam.py endpoints |
| T068 | **S4** | Exam screen (exam.tsx) |
| T069 | **S2** | Exam incidents Shiny panel |

### Phase 8: Polish (Weeks 14-16) — Mixed
| Task | Assignee | Description |
|---|---|---|
| T070 | **S3** | Real upload/material endpoint |
| T071 | **S3** | GitHub Actions CI/CD |
| T072 | **ALL** | End-to-end integration test |
| T073 | **S3** | Final README |
| T074 | **S2** | Deploy Shiny to final hosting |

---

## Workload Summary

| Student | Total Tasks | Phases Active | Est. Hours |
|---|---|---|---|
| **S1** (AI/Vision) | **17** | 1, 2, 3, 6, 7 | ~85h |
| **S2** (R/Shiny) | **18** | 1, 2, 4, 7, 8 | ~90h |
| **S3** (Backend) | **24** | 1, 2, 3, 5, 6, 7, 8 | ~72h (smaller tasks) |
| **S4** (Mobile) | **12** | 1, 5, 7 | ~60h |
| **Shared** | **3** | 2 (review), 8 (integration) | ~6h each |
| **TOTAL** | **74** | | |

### Why S3 has 24 tasks but fewer hours:
S3's Phase 2 tasks (T014-T020) are all stub endpoints — each takes ~15 minutes. The bulk of S3's work is Phase 2 setup (one-time) and supporting other phases with backend endpoints.

### Why S4 has only 12 tasks:
React Native screens are more complex per-task. Each screen (focus.tsx, notes.tsx) involves multiple components, state management, WebSocket integration, and device testing.

---

## Parallel Execution Timeline

```
Week 1-2:  S3 builds foundation (T009-T023) — BLOCKS S1, S2, S4
           S1 prepares environment (T001, T005, T025)
           S2 installs R packages (T006)
           S4 installs Node deps (T007)

Week 3-5:  S1 builds vision pipeline (T026-T029, T033)
           S2 starts Shiny portal (T034-T040) — parallel with S1
           S3 builds real endpoints (T028, T030-T032) — supports S1
           S4 starts mobile app (T049-T052) — parallel with S1/S2

Week 5-8:  S1 finishes vision + Whisper
           S2 finishes all 15 Shiny tasks (T034-T048)
           S4 finishes all mobile screens (T053-T057)
           S3 finishes support endpoints (T058-T059)

Week 9-10: S1 builds Gemini AI (T060-T062, T064)
           S3 builds plan endpoint (T063)

Week 11-13: S1 builds exam proctoring (T065-T066)
            S3 builds exam endpoints (T067)
            S4 builds exam screen (T068)
            S2 builds exam Shiny panel (T069)

Week 14-16: S3 polishes (T070-T071, T073)
            S2 final deploy (T074)
            ALL integration test (T072)
```
