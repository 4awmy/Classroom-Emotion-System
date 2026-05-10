# Global Setup for Shiny Application - Hybrid v3
# Local PostgreSQL for Data + FastAPI for Auth

# ============================================================================
# Load Libraries
# ============================================================================

library(shiny)
library(shinydashboard)
library(shinyalert)
library(shinyjs)
library(shinyWidgets)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(lubridate)
library(httr2)
library(curl)
library(base64enc)
library(openxlsx)
library(rmarkdown)
library(bslib)
library(config)
library(DBI)
library(RPostgres)

# ============================================================================
# Configuration
# ============================================================================

# Prioritize Environment Variables (DigitalOcean)
FASTAPI_BASE <- Sys.getenv("API_URL", "")

if (FASTAPI_BASE == "") {
  # Fallback to config file for local development
  tryCatch({
    cfg <- config::get(file = "config.yml")
    FASTAPI_BASE <- cfg$fastapi_base
  }, error = function(e) {
    FASTAPI_BASE <- "http://localhost:8000"
  })
}

# Ensure API_URL points to /api if not already specified (for multi-service routing)
if (!grepl("/api$", FASTAPI_BASE) && !grepl("/api/$", FASTAPI_BASE)) {
    # Strip trailing slash then add /api
    FASTAPI_BASE <- paste0(sub("/$", "", FASTAPI_BASE), "/api")
}

# --- Database Query Helper ---
# Local Shiny defaults to cached CSV exports to avoid repeated failed DB connects.
.query_table_cache <- new.env(parent = emptyenv())

query_table <- function(table_name) {
  cache_key <- table_name
  if (exists(cache_key, envir = .query_table_cache, inherits = FALSE)) {
    return(base::get(cache_key, envir = .query_table_cache, inherits = FALSE))
  }

  use_database <- identical(tolower(Sys.getenv("USE_DATABASE", "false")), "true")
  db_url <- Sys.getenv("DATABASE_URL", "")
  if (use_database && db_url != "") {
    db_result <- tryCatch({
      con <- dbConnect(RPostgres::Postgres(), dbname = db_url)
      on.exit(dbDisconnect(con), add = TRUE)
      dbReadTable(con, table_name)
    }, error = function(e) {
      print(paste("[DB] Query failed for", table_name, ":", e$message))
      NULL
    })
    if (!is.null(db_result)) {
      assign(cache_key, db_result, envir = .query_table_cache)
      return(db_result)
    }
  }

  csv_name <- switch(
    table_name,
    "emotion_log" = "emotions",
    "attendance_log" = "attendance",
    table_name
  )
  csv_path <- file.path("..", "python-api", "data", "exports", paste0(csv_name, ".csv"))
  if (file.exists(csv_path)) {
    csv_result <- read.csv(csv_path, stringsAsFactors = FALSE)
    assign(cache_key, csv_result, envir = .query_table_cache)
    return(csv_result)
  }

  empty_result <- data.frame()
  assign(cache_key, empty_result, envir = .query_table_cache)
  empty_result
}

# ============================================================================
# API Client Helper Function (FastAPI)
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, auth_token = NULL, content_type = "application/json") {
  url <- paste0(FASTAPI_BASE, endpoint)
  print(paste("[API] Calling:", method, url))

  req <- request(url) |>
    req_method(method) |>
    req_headers("Content-Type" = content_type) |>
    req_error(is_error = \(resp) FALSE)

  if (!is.null(auth_token)) {
    req <- req |> req_headers("Authorization" = paste("Bearer", auth_token))
  }

  if (!is.null(body)) {
    req <- req |> req_body_json(body)
  }

  tryCatch({
    resp <- req_perform(req)
    print(paste("[API] Response Status:", resp_status(resp)))
    
    if (resp_status(resp) >= 400) {
      # Handle common error responses
      try({
        err_body <- resp_body_json(resp)
        detail <- if (!is.null(err_body$detail)) {
          if (is.list(err_body$detail)) paste(err_body$detail, collapse = "; ") else err_body$detail
        } else {
          err_body$message %||% "Internal Server Error"
        }
        
        shinyalert::shinyalert(
          title = paste("Login Failed"),
          text = as.character(detail),
          type = "error"
        )
      }, silent = TRUE)
      return(NULL)
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    print(paste("[API] FATAL ERROR:", e$message))
    shinyalert::shinyalert(
      title = "Connection Error",
      text = paste("Could not reach backend:", e$message),
      type = "error"
    )
    return(NULL)
  })
}

# ============================================================================
# Theme & Utilities
# ============================================================================

AAST_NAVY <- "#002147"
AAST_GOLD <- "#C9A84C"

format_engagement <- function(score) {
  if (is.null(score) || is.na(score)) return("0.0%")
  paste0(round(score * 100, 1), "%")
}

emotion_colors <- list(
  "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
  "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
)

get_emotion_color <- function(emotion) {
  color <- emotion_colors[[emotion]]
  if (is.null(color)) return("#CCCCCC")
  return(color)
}

# ============================================================================
# Initial Boot Logs
# ============================================================================
print("✓ Shiny Global.R loaded successfully")
print(paste("✓ API URL Target:", FASTAPI_BASE))
print(paste("✓ DB URL Present:", nchar(Sys.getenv("DATABASE_URL", "")) > 0))
