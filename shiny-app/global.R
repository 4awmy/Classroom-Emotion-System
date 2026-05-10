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

# We use the Public URL for maximum reliability
# DigitalOcean's internal networking is bypassable via the public ingress
FASTAPI_BASE <- "https://classroomx-lkbxf.ondigitalocean.app/api"

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
    message(paste("[DB] Query failed:", e$message))
    return(data.frame())
  })
}

# ============================================================================
# API Client Helper Function (FastAPI)
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, auth_token = NULL, content_type = "application/json") {
  # Endpoint should start with /
  if (!grepl("^/", endpoint)) endpoint <- paste0("/", endpoint)
  
  url <- paste0(FASTAPI_BASE, endpoint)
  print(paste("[API] Calling:", method, url))

  req <- request(url) |>
    req_method(method) |>
    req_headers("Content-Type" = content_type) |>
    req_error(is_error = \(resp) FALSE) |>
    req_timeout(15)

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
      err_body <- tryCatch(resp_body_json(resp), error = function(e) list(detail = "Unknown error"))
      detail <- if (!is.null(err_body$detail)) {
        if (is.list(err_body$detail)) paste(err_body$detail, collapse = "; ") else err_body$detail
      } else {
        "Unauthorized or invalid request"
      }
      
      shinyalert::shinyalert(
        title = paste("Login Error", resp_status(resp)),
        text = as.character(detail),
        type = "error"
      )
      return(NULL)
    }
    
    resp_body_json(resp)
  }, error = function(e) {
    print(paste("[API] CONNECTION FAILED:", e$message))
    shinyalert::shinyalert(
      title = "System Busy",
      text = "The security server is currently initializing. Please wait 30 seconds and try again.",
      type = "info"
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
print("✓ Shiny System Active")
print(paste("✓ Target Gateway:", FASTAPI_BASE))
