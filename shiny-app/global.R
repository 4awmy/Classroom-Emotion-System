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
FASTAPI_BASE <- Sys.getenv("API_URL", "https://classroomx-lkbxf.ondigitalocean.app")

# Ensure we have a clean trailing slash-free base
FASTAPI_BASE <- sub("/$", "", FASTAPI_BASE)

# PRODUCTION ROUTING RULE:
# All API calls must go through the /api ingress route
# DigitalOcean will strip /api and send the rest to the backend
API_ENTRY <- paste0(FASTAPI_BASE, "/api")

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
    message(paste("[DB] Query failed for", table_name, ":", e$message))
    return(data.frame())
  })
}

# ============================================================================
# API Client Helper Function (FastAPI)
# ============================================================================

api_call <- function(endpoint, method = "GET", body = NULL, auth_token = NULL, content_type = "application/json") {
  # Endpoint should start with /
  url <- paste0(API_ENTRY, endpoint)
  message(paste("[API] Attempting:", method, url))

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
    message(paste("[API] Response Status:", resp_status(resp)))
    
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
    message(paste("[API] FATAL ERROR:", e$message))
    shinyalert::shinyalert(
      title = "Connection Error",
      text = "The system is having trouble reaching the security server. Please try again in a few moments.",
      type = "error"
    )
    return(NULL)
  })
}

# ============================================================================
# Initial Boot Logs
# ============================================================================
message("✓ Shiny Global.R loaded successfully")
message(paste("✓ API Gateway Target:", API_ENTRY))
