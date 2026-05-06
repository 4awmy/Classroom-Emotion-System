# global.R — Runs once at app startup (shared by all sessions)
# Loads libraries, sets constants, and wires up the nightly-CSV reactive poll.
#
# Architecture note (see explanation.md §2 & §3):
#   • This app NEVER connects to SQLite directly.
#   • All analytics data comes from CSV files exported nightly at 02:00
#     by python-api/services/export_service.py.
#   • reactivePoll checks file modification times every 60 s; data is only
#     re-read when the nightly export has actually written a new file.

library(shiny)
library(shinydashboard)   # dashboardPage() — required for Admin & Lecturer UIs
library(shinyalert)       # live confusion-spike popups
library(shinyjs)          # show/hide helpers
library(DT)               # interactive DataTables
library(plotly)           # interactive charts
library(ggplot2)          # static/export charts
library(dplyr)            # data wrangling
library(lubridate)        # date/time helpers (floor_date, etc.)
library(httr2)            # FastAPI HTTP calls
library(curl)             # curl::form_file() for multipart uploads
library(openxlsx)         # xlsx export for download handlers
library(rmarkdown)        # PDF report generation

# ── API base URL ──────────────────────────────────────────────────────────────
# During local development point to localhost; swap to Railway URL before deploy.
# See Section 15 of CLAUDE.md for the Railway setup steps.
FASTAPI_BASE <- Sys.getenv("FASTAPI_BASE_URL", unset = "http://localhost:8000")

# ── CSV export directory (written by python-api nightly at 02:00) ─────────────
EXPORT_DIR <- file.path(
  Sys.getenv("EXPORT_DIR",
             unset = file.path(dirname(getwd()), "python-api", "data", "exports"))
)

CSV_PATHS <- list(
  emotions      = file.path(EXPORT_DIR, "emotions.csv"),
  attendance    = file.path(EXPORT_DIR, "attendance.csv"),
  materials     = file.path(EXPORT_DIR, "materials.csv"),
  incidents     = file.path(EXPORT_DIR, "incidents.csv"),
  transcripts   = file.path(EXPORT_DIR, "transcripts.csv"),
  notifications = file.path(EXPORT_DIR, "notifications.csv")
)

# ── Helper: safe CSV reader (returns empty tibble on missing file) ────────────
safe_read_csv <- function(path) {
  if (file.exists(path)) {
    tryCatch(
      read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8"),
      error = function(e) {
        warning(paste("Could not read", path, ":", conditionMessage(e)))
        data.frame()
      }
    )
  } else {
    data.frame()
  }
}

# ── reactivePoll factory ──────────────────────────────────────────────────────
# Returns a reactive expression that re-reads *all* CSV exports whenever any
# file's modification time changes.  Poll interval: 60 000 ms (1 minute).
#
# Usage inside server():
#   exports <- make_csv_poll(session)
#   emotions_df <- reactive({ exports()$emotions })
make_csv_poll <- function(session) {
  shiny::reactivePoll(
    intervalMillis = 60000,
    session        = session,

    # checkFunc: returns the vector of last-modified times for all CSVs.
    # reactivePoll only calls valueFunc when this changes.
    checkFunc = function() {
      sapply(unlist(CSV_PATHS), function(p) {
        if (file.exists(p)) file.mtime(p) else NA
      })
    },

    # valueFunc: re-reads all CSVs into a named list.
    valueFunc = function() {
      lapply(CSV_PATHS, safe_read_csv)
    }
  )
}

# ── Source modular UI and server files ────────────────────────────────────────
source(file.path("ui",      "admin_ui.R"),      local = TRUE)
source(file.path("ui",      "lecturer_ui.R"),   local = TRUE)
source(file.path("server",  "admin_server.R"),  local = TRUE)
source(file.path("server",  "lecturer_server.R"), local = TRUE)
source(file.path("modules", "engagement_score.R"), local = TRUE)
source(file.path("modules", "clustering.R"),    local = TRUE)
source(file.path("modules", "attendance.R"),    local = TRUE)
