# Implementation Plan: Lecturer View Upgrade & Maintenance

## Overview
This plan covers the implementation of the 'Schedule View' for lecturers, production-ready features (Summaries, Trends), and the immediate removal of test user `9999999999999`.

## Phase 1: Database Maintenance (Immediate)
**Goal**: Clean up test data.
- **Task 1.1**: Execute `python-api/scripts/remove_user.py` to remove student `9999999999999`.
- **Agent**: `data_engineer`
- **Validation**: Verify student ID `9999999999999` is no longer in the `students` table.

## Phase 2: Backend - Schedule & Summaries
**Goal**: Extend API to support scheduling and automated summaries.
- **Task 2.1**: Create `Schedule` model and migration.
- **Task 2.2**: Implement `/schedule` endpoints (GET, POST).
- **Task 2.3**: Implement `/sessions/{id}/summary` endpoint using Gemini for insights.
- **Agent**: `api_designer`, `data_engineer`
- **Validation**: API tests for schedule retrieval and summary generation.

## Phase 3: Frontend - Schedule View
**Goal**: Add the Schedule tab to the Shiny UI.
- **Task 3.1**: Integrate `fullcalendar` or similar R-compatible calendar library.
- **Task 3.2**: Create `modules/schedule.R` for the UI and server logic.
- **Task 3.3**: Connect 'Start Session' button to existing vision pipeline trigger.
- **Agent**: `ux_designer`, `coder`
- **Validation**: Manual UI test - click a schedule slot and start a session.

## Phase 4: Frontend - Production Features
**Goal**: Add Summaries and Trends to the dashboard.
- **Task 4.1**: Implement 'Session Summary' modal/view in the History tab.
- **Task 4.2**: Implement 'Student Trends' view with longitudinal charts.
- **Agent**: `ux_designer`, `coder`
- **Validation**: Verify charts render correctly with mock/real data.

## Phase 5: Notifications & Final Review
**Goal**: Add real-time alerts and conduct final quality check.
- **Task 5.1**: Implement browser notifications for low engagement.
- **Task 5.2**: Final code review and documentation update.
- **Agent**: `code_reviewer`, `technical_writer`
- **Validation**: End-to-end test of the entire lecturer workflow.
