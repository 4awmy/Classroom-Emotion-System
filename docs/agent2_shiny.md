# Agent 2: Build Phase 1 Shiny Shell (S2) with AAST Moodle Styles

## MANDATORY RULES — READ BEFORE DOING ANYTHING

### Collaboration Protocol (from GEMINI.md)
1. **Use `gh` CLI** to create branches, commits, and PRs for every implementation.
2. **No Unsolicited Work**: Do NOT start any new task or sub-task beyond what is listed below.
3. **PR & Merge Workflow**:
   a. Create a feature branch: `git checkout -b feature/phase1-s2-shiny-shell`
   b. Commit frequently with descriptive messages.
   c. Push and create a **Draft PR** against `dev`: `gh pr create --base dev --draft --title "[Phase1-S2] Shiny shell with AAST Moodle styles" --body-file <body>`
   d. After creating the PR, perform a **self-review** comment on the PR.
   e. Tag **@Copilot** in a PR comment requesting review.
   f. Do NOT merge. Wait for user approval.
4. **Stuck/Blocked Protocol**: If you hit a blocker (missing R package, unclear spec, file conflict), **comment on the PR tagging @4awmy** and explain the blocker. Do NOT silently skip tasks.
5. **Plan Validation**: If you find an error in `ARCHITECTURE.md` or `CLAUDE.md`, STOP immediately and comment on the PR explaining the discrepancy.
6. **Branch Cleanup**: When merging (only after user says "Merge"), use `gh pr merge --delete-branch`.

### Architecture Rules (from constitution.md)
- **Principle III**: R/Shiny is for Admin + Lecturer ONLY. NEVER build student features in Shiny.
- **Principle IV**: R/Shiny must NEVER connect to SQLite directly. Only read CSV exports from `data/exports/`.
- **Principle X**: INJECT Shiny components into pre-existing AAST HTML templates. Do NOT rebuild the AAST chrome.
- **Principle XI**: Use EXACT engagement formulas from CLAUDE.md Section 8.
- **Data reads**: Use `httr2` for API calls, `read.csv()` for CSV files. No RSQLite, no RODBC.

### Multi-Agent Coordination
- You are Agent 2 (Shiny/R). Agent 1 (Backend) is running in parallel.
- Do NOT touch any files in `python-api/`. That's Agent 1's territory.
- Do NOT touch any files in `react-native-app/`. That's Phase 5 work.
- Your scope is `shiny-app/` ONLY.

---

## Available AAST Style Files (already copied to shiny-app/www/moodle-styles/)
- `style_1.css` — Main AAST Moodle theme (1.5MB, full Moodle CSS)
- `style_2.css` — Roboto font faces (300, 400, 500, 700 weights)
- `assets/aast_main_logo.png` — AAST header logo
- `assets/aast_footer_logo.png` — AAST footer logo
- `assets/arab_league.png` — Arab League badge
- `assets/qs_stars.png` — QS Stars rating badge

## AAST Brand Colors
- Navy primary: `#002147`
- Gold accent: `#C9A84C`
- Background: `#f5f5f5`
- Font: Roboto (loaded via style_2.css)

## Tasks To Complete

### Task 1: Create shiny-app/www/template.html
HTML template that wraps Shiny UI in AAST Moodle chrome:
- `<head>`: link to all 3 CSS files in `moodle-styles/`
- AAST navy header bar (`#002147`) with `aast_main_logo.png` + navigation
- A `{{ body }}` placeholder where Shiny injects UI (for `htmlTemplate()`)
- AAST footer with `aast_footer_logo.png`, `arab_league.png`, `qs_stars.png`
- Copyright: "Arab Academy for Science, Technology & Maritime Transport"
- Responsive and RTL-aware (Arabic support)

### Task 2: Create shiny-app/global.R (T034)
```r
library(shiny)
library(shinydashboard)
library(shinyalert)
library(shinyjs)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(lubridate)
library(httr2)
library(config)

FASTAPI_BASE <- Sys.getenv("FASTAPI_BASE", "http://localhost:8000")

load_csv_safe <- function(path) {
  if (file.exists(path)) {
    read.csv(path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  } else {
    data.frame()
  }
}

EXPORT_DIR <- normalizePath(file.path("..", "python-api", "data", "exports"), mustWork = FALSE)
```

### Task 3: Rewrite shiny-app/app.R
Replace current minimal app.R with:
- Uses `htmlTemplate("www/template.html", body = ...)` for AAST chrome injection
- `shinydashboard` layout: sidebar with "Admin Dashboard" and "Lecturer Panel"
- Sources `global.R`, `ui/admin_ui.R`, `ui/lecturer_ui.R`, `server/admin_server.R`, `server/lecturer_server.R`

### Task 4: Create shiny-app/ui/admin_ui.R (T038)
8 empty tab panels with placeholder content:
1. Attendance Overview
2. Engagement Trend
3. Department Heatmap
4. At-Risk Students
5. Lecturer Effectiveness Score (LES)
6. Emotion Distribution
7. Cluster Map
8. Time-of-Day Heatmap

### Task 5: Create shiny-app/ui/lecturer_ui.R (T039)
5 submodule tabs with placeholder UI:
1. Roster Setup — `fileInput("roster_xlsx", accept=".xlsx")`
2. Material Upload — `fileInput` + `textInput`
3. Attendance — DT table placeholder
4. Live Dashboard — 7 value box placeholders (D1-D7)
5. Student Reports — `selectInput` + chart placeholder

### Task 6: Create shiny-app/server/admin_server.R (stub)
Stub module rendering placeholder output for all 8 panels.

### Task 7: Create shiny-app/server/lecturer_server.R (stub)
Stub module rendering placeholder output for all 5 submodules.

### Task 8: Verify the app launches
```r
Rscript -e "shiny::runApp('shiny-app', port=3838)"
```
Verify: app loads with AAST chrome, all tabs clickable, no R errors.

## After All Tasks

1. `git add shiny-app/`
2. `git commit -m "feat(shiny): Phase 1 S2 shell — AAST Moodle template, admin/lecturer UI stubs"`
3. `git push -u origin feature/phase1-s2-shiny-shell`
4. Create draft PR: `gh pr create --base dev --draft --title "[Phase1-S2] Shiny shell with AAST Moodle styles — 8 admin panels + 5 lecturer submodules" --label "Phase 4: US2 Shiny" --label "S2: R/Shiny"`
5. Post self-review comment on the PR
6. Tag @Copilot: `gh pr comment <PR_NUMBER> --body "@Copilot Please review this PR. Focus on: AAST template injection, Shiny module structure, R package usage."`
7. If blocked, tag @4awmy: `gh pr comment <PR_NUMBER> --body "@4awmy BLOCKER: <describe issue>"`
