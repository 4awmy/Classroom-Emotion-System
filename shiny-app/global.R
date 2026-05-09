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

# ============================================================================
# Database Connection Manager
# ============================================================================

# Function to get a fresh DB connection with retry logic and better error handling
get_db_con <- function() {
  # We use the pooler host as it's more stable across different networks
  # Host: aws-0-eu-central-1.pooler.supabase.com
  # Port: 6543 (Transaction mode)
  # User: postgres.[project_ref]
  
  host <- Sys.getenv("SUPABASE_DB_HOST", "aws-0-eu-central-1.pooler.supabase.com")
  port <- as.integer(Sys.getenv("SUPABASE_DB_PORT", "6543"))
  user <- Sys.getenv("SUPABASE_DB_USER", "postgres.asefcgykjadlekhwwzar")
  pw   <- Sys.getenv("SUPABASE_DB_PASSWORD", "kdJTnejv0XYhud5C")
  
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      dbname   = "postgres",
      host     = host,
      port     = port,
      user     = user,
      password = pw,
      sslmode  = "require"  # CRITICAL: Supabase requires SSL
    )
    return(con)
  }, error = function(e) {
    message("ERROR: Database connection failed: ", e$message)
    return(NULL)
  })
}

# Initial global connection
con <- get_db_con()

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
  if (is.null(score) || is.na(score)) return("0.0%")
  paste0(round(score * 100, 1), "%")
}

get_engagement_level <- function(score) {
  if (is.null(score) || is.na(score)) return("N/A")
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

if (is.null(con)) {
  cat("! WARNING: Shiny started WITHOUT active Database connection\n")
} else {
  cat("✓ Shiny Global.R loaded successfully\n")
}
cat("✓ FastAPI Base:", FASTAPI_BASE, "\n")
