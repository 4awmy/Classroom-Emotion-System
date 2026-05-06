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
library(curl)             # curl::form_file() for multipart roster/material uploads
library(openxlsx)
library(rmarkdown)
library(bslib)
library(aws.s3)

# ============================================================================
# Configuration
# ============================================================================

# FastAPI Base URL - change based on environment
# Local development:
FASTAPI_BASE <- "http://localhost:8000"

# Production (after Railway deployment):
# FASTAPI_BASE <- "https://your-railway-app.railway.app"

# S3 Configuration (Digital Ocean Spaces)
SPACES_BUCKET <- Sys.getenv("SPACES_BUCKET")
SPACES_REGION <- Sys.getenv("SPACES_REGION")
SPACES_ENDPOINT <- Sys.getenv("SPACES_ENDPOINT")

# Set AWS credentials for aws.s3 package
Sys.setenv(
  "AWS_ACCESS_KEY_ID" = Sys.getenv("SPACES_KEY"),
  "AWS_SECRET_ACCESS_KEY" = Sys.getenv("SPACES_SECRET"),
  "AWS_DEFAULT_REGION" = SPACES_REGION
)

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

# Get file modification time (local or S3)
get_file_mtime <- function(filepath) {
  if (SPACES_BUCKET != "") {
    filename <- basename(filepath)
    tryCatch({
      meta <- aws.s3::head_object(
        object = paste0("exports/", filename),
        bucket = SPACES_BUCKET,
        base_url = SPACES_ENDPOINT
      )
      return(as.numeric(attr(meta, "last-modified")))
    }, error = function(e) {
      return(0)
    })
  } else {
    if (file.exists(filepath)) {
      return(as.numeric(file.info(filepath)$mtime))
    } else {
      return(0)
    }
  }
}

# Load CSV with error handling (local or S3)
load_csv <- function(filepath) {
  if (SPACES_BUCKET != "") {
    filename <- basename(filepath)
    tryCatch({
      aws.s3::s3read_using(
        FUN = read.csv,
        object = paste0("exports/", filename),
        bucket = SPACES_BUCKET,
        base_url = SPACES_ENDPOINT,
        stringsAsFactors = FALSE,
        encoding = "UTF-8"
      )
    }, error = function(e) {
      if (!file.exists(filepath)) {
        return(data.frame())
      }
      read.csv(filepath, stringsAsFactors = FALSE)
    })
  } else {
    if (!file.exists(filepath)) {
      return(data.frame())
    }
    tryCatch({
      read.csv(filepath, stringsAsFactors = FALSE)
    }, error = function(e) {
      return(data.frame())
    })
  }
}

# ============================================================================
# Session Information Logging
# ============================================================================

cat("✓ Shiny Global.R loaded successfully\n")
cat("✓ FastAPI Base:", FASTAPI_BASE, "\n")
