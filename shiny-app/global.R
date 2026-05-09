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

cfg <- config::get(file = "config.yml")
FASTAPI_BASE <- cfg$fastapi_base

# ============================================================================
# Database Connection Manager
# ============================================================================

get_db_con <- function() {
  # Connecting to LOCAL PostgreSQL (Docker)
  host <- Sys.getenv("LOCAL_DB_HOST", "localhost")
  port <- as.integer(Sys.getenv("LOCAL_DB_PORT", "5432"))
  user <- Sys.getenv("LOCAL_DB_USER", "postgres")
  pw   <- Sys.getenv("LOCAL_DB_PASSWORD", "password123")
  db   <- Sys.getenv("LOCAL_DB_NAME", "classroom_emotions")
  
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      dbname   = db,
      host     = host,
      port     = port,
      user     = user,
      password = pw
    )
    return(con)
  }, error = function(e) {
    message("ERROR: Local PostgreSQL connection failed: ", e$message)
    return(NULL)
  })
}

# Initial global connection
con <- get_db_con()

# ============================================================================
# API Client Helper Function (FastAPI)
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, auth_token = NULL, content_type = "application/json") {
  url <- paste0(FASTAPI_BASE, endpoint)

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
    
    if (resp_status(resp) >= 400) {
      # Handle common error responses
      try({
        err_body <- resp_body_json(resp)
        detail <- if (!is.null(err_body$detail)) {
          if (is.list(err_body$detail)) paste(err_body$detail, collapse = "; ") else err_body$detail
        } else {
          err_body$message %||% "Internal Server Error"
        }
        
        if (resp_status(resp) != 401) {
          shinyalert::shinyalert(
            title = paste("API Error", resp_status(resp)),
            text = as.character(detail),
            type = "error"
          )
        }
      }, silent = TRUE)
      return(NULL)
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    # Silence or log network errors
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
# Logging
# ============================================================================

if (is.null(con)) {
  cat("! WARNING: Shiny started WITHOUT Local PostgreSQL connection\n")
} else {
  cat("✓ Shiny Global.R loaded successfully (Hybrid v3: Local Postgres)\n")
}
cat("✓ FastAPI Base:", FASTAPI_BASE, "\n")
