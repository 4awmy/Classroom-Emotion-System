# Implementation Plan - Lecturer Portal "Command Center" Overhaul

**Task Complexity**: Medium

## Plan Overview
Overhaul the Lecturer Portal to become a "Command Center" with a refactored Live Dashboard and a new Reports tab featuring advanced analytics.

## Execution Strategy
| Phase | Objective | Agent | Execution Mode |
|-------|-----------|-------|----------------|
| 1 | Live Dashboard Overhaul | coder | Sequential |
| 2 | Reports & Analytics Overhaul | coder | Sequential |

## Phase 1: Live Dashboard Overhaul
- **Objective**: Refactor the Live Dashboard to include a 3-step selector and a 2-column layout with real-time stats.
- **Agent**: `coder`
- **Files to Modify**:
    - `shiny-app/ui/lecturer_ui.R`:
        - Replace `lec_live_class_selector` with `lec_live_course_selector` and `lec_live_class_selector`.
        - Add `lec_live_schedule_info` display.
        - Split layout into `column(8, ...)` for video and `column(4, ...)` for stats.
        - Add UI for Attendance counter, Engagement gauge, and Confusion Ticker.
    - `shiny-app/server/lecturer_server.R`:
        - Implement `output$lec_live_course_selector` and `output$lec_live_class_selector`.
        - Add reactive filtering for classes based on course.
        - Implement `output$lec_live_schedule_info`.
        - Add `reactiveTimer(5000)` for polling live stats.
        - Implement `output$lec_live_attendance_count`, `output$lec_live_engagement_gauge`, and `output$lec_live_confusion_ticker`.
- **Validation**:
    - Verify Course -> Class filtering works.
    - Verify Start Session works with the new selector.
    - Verify video feed displays in the left column.
    - Verify stats update every 5 seconds in the right column.

## Phase 2: Reports & Analytics Overhaul
- **Objective**: Refactor the Reports tab to include session history and a 2x2 grid of charts.
- **Agent**: `coder`
- **Files to Modify**:
    - `shiny-app/ui/lecturer_ui.R`:
        - Update `lec_reports` tab with a session history selector.
        - Add a 2x2 grid layout using `fluidRow` and `column(6, ...)`.
        - Add placeholders for: Emotion Frequency (Pie), Engagement Timeline (Line), Attendance Table (DT), and Student Drill-down.
    - `shiny-app/server/lecturer_server.R`:
        - Implement session history selector logic.
        - Implement logic for the 4 charts/tables using `compute_engagement` and `aggregate_attendance` modules.
        - Implement student drill-down logic (selector + timeline).
- **Validation**:
    - Verify session history selector filters data correctly.
    - Verify all 4 charts/tables in the 2x2 grid display correct data.
    - Verify student drill-down shows specific timeline for selected student.

## File Inventory
| Action | Path | Purpose |
|--------|------|---------|
| Modify | `shiny-app/ui/lecturer_ui.R` | UI refactor for Live Dashboard and Reports. |
| Modify | `shiny-app/server/lecturer_server.R` | Server logic for filtering, polling, and analytics. |

## Execution Profile
- Total phases: 2
- Parallelizable phases: 0 (Sequential due to shared file modifications)
- Sequential-only phases: 2
- Estimated wall time: 40 mins
