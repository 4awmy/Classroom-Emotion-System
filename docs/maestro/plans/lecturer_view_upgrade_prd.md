# Design: Lecturer View Upgrade - Schedule & Production Features

## Problem Statement
The current Classroom Emotion System lacks a structured way for lecturers to manage their teaching schedule. Lecturers must manually enter lecture IDs, which is error-prone and adds friction to starting a session. Additionally, the dashboard lacks production-ready features like automated notifications, session summaries, and long-term student performance trends, limiting its utility for pedagogical improvement.

## Target Users
- **Lecturers**: Primary users who need to manage sessions, monitor student engagement, and review performance.
- **Academic Administrators**: Secondary users who may need to see aggregated schedule and attendance data.

## Success Metrics
- **Reduced Friction**: Time from login to session start reduced by >50%.
- **Engagement**: Increase in lecturer logins post-session to review summaries.
- **Accuracy**: Reduction in "orphaned" or incorrectly labeled lecture sessions.

## Requirements

### 1. Schedule View (Must Have)
- **Calendar Integration**: View upcoming and past lectures in a weekly/monthly calendar format.
- **One-Click Start**: Start a session directly from a scheduled slot.
- **Automatic Metadata**: Pre-populate course name, lecture ID, and expected student roster from the schedule.

### 2. Session Summaries (Should Have)
- **Automated Reports**: Generate a PDF/Web summary after each session showing average engagement, peak boredom moments, and attendance.
- **AI Insights**: Use Gemini to provide 3 actionable tips based on the session's emotion data (e.g., "Engagement dropped at 10:15 AM; consider a break or interactive activity here next time").

### 3. Student Performance Trends (Should Have)
- **Longitudinal Tracking**: View engagement and attendance trends for individual students across the semester.
- **At-Risk Alerts**: Highlight students whose engagement has significantly declined over the last 3 sessions.

### 4. Notifications (Could Have)
- **Real-time Alerts**: Browser/Mobile notifications for significant events (e.g., "Class engagement is below 30%").
- **Schedule Reminders**: Reminders 5 minutes before a scheduled lecture.

## User Stories

### Schedule View
1. **As a lecturer**, I want to **see my weekly teaching schedule**, so that I can **plan my day and quickly access my upcoming classes**.
   - AC 1: Given I am on the dashboard, when I click 'Schedule', then I see a calendar view of my assigned courses.
   - AC 2: Given a scheduled slot, when I click it, then I see details (Course, Room, Time, Expected Students).
   - AC 3: Given a current or upcoming slot, when I click 'Start Session', then the vision pipeline begins with pre-filled metadata.

### Session Summaries
2. **As a lecturer**, I want to **receive a summary after my class**, so that I can **understand how my students felt without manually analyzing raw data**.
   - AC 1: Given a session has ended, when I visit the 'History' tab, then I see a 'Summary' button for that session.
   - AC 2: The summary must include a graph of engagement over time and a list of top 3 "high-engagement" and "low-engagement" moments.

## Prioritization (RICE)

| Feature | Reach | Impact | Confidence | Effort | RICE Score | Priority |
|---------|-------|--------|------------|--------|------------|----------|
| Schedule View | 100% | 3 (Massive) | 90% | 3 | 90 | Must Have |
| Session Summaries | 80% | 2 (High) | 80% | 2 | 64 | Should Have |
| Student Trends | 60% | 2 (High) | 70% | 4 | 21 | Should Have |
| Notifications | 40% | 1 (Med) | 50% | 2 | 10 | Could Have |

## Constraints & Assumptions
- **Assumption**: A source of truth for schedules (e.g., Moodle or a CSV upload) will be provided.
- **Constraint**: The Shiny UI must remain responsive while rendering calendar components.
- **Constraint**: Data privacy must be maintained; lecturers only see their own schedules.

## Open Questions
- Should the schedule be synced from an external API (Moodle/Google Calendar) or managed within the app?
- Do we need to support recurring vs. one-off sessions?

## Maintenance Tasks
- **User Removal**: Completely remove student ID `9999999999999` and all associated records (emotions, attendance, incidents, notifications, focus strikes) from the database to clean up test data.
