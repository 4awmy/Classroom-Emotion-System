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

# Internal networking is better for cross-service calls in DO
# Fallback to public URL if internal env var not set
FASTAPI_BASE <- Sys.getenv("API_URL", "https://classroomx-lkbxf.ondigitalocean.app")

# Ensure we have a clean trailing slash-free base
FASTAPI_BASE <- sub("/$", "", FASTAPI_BASE)

# PRODUCTION ROUTING RULE:
# If calling publicly, we need the /api prefix (handled by DO Ingress)
# If calling internally (backend:8000), we DON'T need /api because we bypass the Ingress
if (grepl("backend:8000", FASTAPI_BASE)) {
    API_ENTRY <- FASTAPI_BASE
    print("[INIT] Using INTERNAL API Gateway (No /api prefix)")
} else {
    API_ENTRY <- paste0(FASTAPI_BASE, "/api")
    print("[INIT] Using PUBLIC API Gateway (With /api prefix)")
}

# --- Database Query Helper ---
query_table <- function(table_name) {
  db_url <- Sys.getenv("DATABASE_URL", "")
  if (db_url == "") return(data.frame())
  
  tryCatch({
    con <- dbConnect(RPostgres::Postgres(), url = db_url)
    res <- dbReadTable(con, table_name)
    dbDisconnect(con)
    return(res)
  }, error = function(e) {
    print(paste("[DB] Query failed for", table_name, ":", e$message))
    return(data.frame())
  })
}

# ============================================================================
# API Client Helper Function (FastAPI)
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, auth_token = NULL, content_type = "application/json") {
  # Ensure endpoint starts with /
  if (!grepl("^/", endpoint)) endpoint <- paste0("/", endpoint)
  
  url <- paste0(API_ENTRY, endpoint)
  print(paste("[API] Calling:", method, url))

  req <- request(url) |>
    req_method(method) |>
    req_headers("Content-Type" = content_type) |>
    req_error(is_error = \(resp) FALSE) |>
    req_timeout(10)

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
      err_body <- tryCatch(resp_body_json(resp), error = function(e) list(detail = "Unknown error"))
      detail <- if (!is.null(err_body$detail)) {
        if (is.list(err_body$detail)) paste(err_body$detail, collapse = "; ") else err_body$detail
      } else {
        "Request failed"
      }
      
      shinyalert::shinyalert(
        title = paste("Server Error", resp_status(resp)),
        text = as.character(detail),
        type = "error"
      )
      return(NULL)
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    print(paste("[API] CONNECTION FAILED:", e$message))
    shinyalert::shinyalert(
      title = "Connection Error",
      text = paste("Could not reach backend server at", url, ". Details:", e$message),
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
print(paste("✓ Final API Entry Point:", API_ENTRY))
