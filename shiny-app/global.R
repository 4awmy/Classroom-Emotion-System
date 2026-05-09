# Global Setup for Shiny Application
# Loads libraries, sets configuration, and initializes utilities

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

# Supabase Connection
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "postgres",
  host = Sys.getenv("SUPABASE_DB_HOST"),
  port = 5432,
  user = "postgres",
  password = Sys.getenv("SUPABASE_DB_PASSWORD")
)

# ============================================================================
# API Client Helper Function
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, content_type = "application/json") {
  url <- paste0(FASTAPI_BASE, endpoint)

  req <- request(url) |>
    req_method(method) |>
    req_headers("Content-Type" = content_type) |>
    req_error(is_error = \(resp) FALSE)

  if (!is.null(body)) {
    req <- req |> req_body_json(body)
  }

  tryCatch({
    resp <- req_perform(req)
    
    if (resp_status(resp) >= 400) {
      err_body <- resp_body_json(resp)
      detail <- if (!is.null(err_body$detail)) {
        if (is.list(err_body$detail)) paste(err_body$detail, collapse = "; ") else err_body$detail
      } else {
        err_body$message %||% "Internal Server Error"
      }
      
      shinyalert::shinyalert(
        title = paste("API Error", resp_status(resp)),
        text = as.character(detail),
        type = "error"
      )
      return(NULL)
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    shinyalert::shinyalert("Network Error", as.character(e), type = "error")
    return(NULL)
  })
}

# ============================================================================
# Theme Configuration (AAST Branding)
# ============================================================================

AAST_NAVY <- "#002147"
AAST_GOLD <- "#C9A84C"
AAST_WHITE <- "#FFFFFF"
AAST_LIGHT_GRAY <- "#F5F5F5"

# ============================================================================
# Utility Functions
# ============================================================================

format_engagement <- function(score) {
  paste0(round(score * 100, 1), "%")
}

get_engagement_level <- function(score) {
  if (score >= 0.75) return("High")
  if (score >= 0.45) return("Moderate")
  if (score >= 0.25) return("Low")
  return("Critical")
}

emotion_colors <- list(
  "Focused" = "#1B5E20",
  "Engaged" = "#4CAF50",
  "Confused" = "#FFC107",
  "Frustrated" = "#FF9800",
  "Anxious" = "#9C27B0",
  "Disengaged" = "#F44336"
)

get_emotion_color <- function(emotion) {
  color <- emotion_colors[[emotion]]
  if (is.null(color)) return("#CCCCCC")
  return(color)
}

# ============================================================================
# Session Information Logging
# ============================================================================

cat("✓ Shiny Global.R loaded successfully\n")
cat("✓ FastAPI Base:", FASTAPI_BASE, "\n")
