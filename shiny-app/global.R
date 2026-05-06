# Global Setup for Shiny Application
# Loads libraries, sets configuration, and initializes utilities

# ============================================================================
# Load Libraries
# ============================================================================

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
library(curl)             # curl::form_file() for multipart roster/material uploads
library(openxlsx)
library(rmarkdown)
library(bslib)

# ============================================================================
# Configuration
# ============================================================================

# FastAPI Base URL - change based on environment
# Local development:
FASTAPI_BASE <- "http://localhost:8000"

# Production (after Railway deployment):
# FASTAPI_BASE <- "https://your-railway-app.railway.app"

# ============================================================================
# API Client Helper Function
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, content_type = "application/json") {
  url <- paste0(FASTAPI_BASE, endpoint)

  req <- request(url) |>
    req_method(method) |>
    req_headers("Content-Type" = content_type)

  if (!is.null(body)) {
    req <- req |> req_body_json(body)
  }

  tryCatch({
    resp <- req_perform(req)
    resp_body_json(resp)
  }, error = function(e) {
    shinyalert::shinyalert("API Error", as.character(e), type = "error")
    return(NULL)
  })
}

# ============================================================================
# Theme Configuration (AAST Branding)
# ============================================================================

# AAST Colors
AAST_NAVY <- "#002147"
AAST_GOLD <- "#C9A84C"
AAST_WHITE <- "#FFFFFF"
AAST_LIGHT_GRAY <- "#F5F5F5"

# ============================================================================
# Utility Functions
# ============================================================================

# Format engagement score as percentage
format_engagement <- function(score) {
  paste0(round(score * 100, 1), "%")
}

# Get engagement level label
get_engagement_level <- function(score) {
  if (score >= 0.75) return("High")
  if (score >= 0.45) return("Moderate")
  if (score >= 0.25) return("Low")
  return("Critical")
}

# Get emotion color mapping
emotion_colors <- list(
  "Focused" = "#1B5E20",      # Dark green
  "Engaged" = "#4CAF50",      # Green
  "Confused" = "#FFC107",     # Amber
  "Frustrated" = "#FF9800",   # Orange
  "Anxious" = "#9C27B0",      # Purple
  "Disengaged" = "#F44336"    # Red
)

# Get color for emotion
get_emotion_color <- function(emotion) {
  color <- emotion_colors[[emotion]]
  if (is.null(color)) return("#CCCCCC")
  return(color)
}

# ============================================================================
# Data Loading Utilities
# ============================================================================

# Load CSV with error handling
load_csv <- function(filepath) {
  if (!file.exists(filepath)) {
    return(data.frame())
  }
  tryCatch({
    read.csv(filepath, stringsAsFactors = FALSE)
  }, error = function(e) {
    return(data.frame())
  })
}

# ============================================================================
# Session Information Logging
# ============================================================================

cat("✓ Shiny Global.R loaded successfully\n")
cat("✓ FastAPI Base:", FASTAPI_BASE, "\n")
