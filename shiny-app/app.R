library(shiny)
library(bslib)
library(DT)
library(plotly)

# Source modular UI and server components
source("ui/admin_ui.R")
source("server/admin_server.R")

ui <- page_navbar(
  theme = bs_theme(
    bootswatch = "flatly",
    primary = "#003366",
    secondary = "#FFD700"
  ),
  title = "Classroom Emotion Analytics",
  
  nav_panel(
    title = "Live Session",
    layout_sidebar(
      sidebar = sidebar(
        title = "Session Filters",
        selectInput(
          "lecture_id", "Select Lecture:",
          choices = c("L01 - Statistics Intro", "L02 - Data Analysis")
        ),
        dateInput("date", "Session Date:", value = Sys.Date()),
        hr(),
        helpText("Select a session to view historical or real-time data.")
      ),
      
      # Main Panel Layout
      layout_column_wrap(
        width = 1,
        # Top Row: Real-time Feed
        card(
          full_screen = TRUE,
          card_header("Real-time Emotion Feed"),
          div(
            style = "height: 400px; background-color: #f8f9fa; border: 2px dashed #dee2e6; display: flex; align-items: center; justify-content: center;",
            "Live Video Stream Placeholder (Vision Node)"
          )
        ),
        
        # Bottom Row: Charts
        layout_column_wrap(
          width = 1/2,
          card(
            card_header("Overall Class Sentiment"),
            div(
              style = "height: 300px; display: flex; align-items: center; justify-content: center;",
              "Sentiment Over Time Chart"
            )
          ),
          card(
            card_header("Student Engagement Index"),
            div(
              style = "height: 300px; display: flex; align-items: center; justify-content: center;",
              "Engagement Metrics Gauge"
            )
          )
        )
      )
    )
  ),
  
  nav_panel(
    title = "Admin Panel",
    admin_ui
  )
)

server <- function(input, output, session) {
  # Call modular server logic
  admin_server(input, output, session)
}

shinyApp(ui, server)
