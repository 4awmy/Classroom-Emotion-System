library(shiny)
library(bslib)
library(DT)
library(plotly)

admin_ui <- tagList(
  tags$style(HTML("
    .card-header {
      background-color: #003366 !important;
      color: #FFD700 !important;
      font-weight: bold;
    }
    .btn-primary {
      background-color: #003366 !important;
      border-color: #003366 !important;
      color: #FFD700 !important;
    }
    .btn-secondary {
      background-color: #FFD700 !important;
      border-color: #FFD700 !important;
      color: #003366 !important;
    }
  ")),
  layout_column_wrap(
    width = 1/2,
    fill = FALSE,
    # 1. Overall Engagement (Chart)
    card(
      card_header("Overall Engagement"),
      plotlyOutput("overall_engagement_chart", height = "300px")
    ),
    # 2. Attendance Heatmap
    card(
      card_header("Attendance Heatmap"),
      plotlyOutput("attendance_heatmap", height = "300px")
    ),
    # 3. Incident Log (DT table)
    card(
      card_header("Incident Log"),
      DTOutput("incident_log_table")
    ),
    # 4. Real-time Alerts
    card(
      card_header("Real-time Alerts"),
      div(
        id = "alerts_container",
        style = "height: 300px; overflow-y: auto;",
        uiOutput("realtime_alerts")
      )
    ),
    # 5. Historical Trends
    card(
      card_header("Historical Trends"),
      plotlyOutput("historical_trends_chart", height = "300px")
    ),
    # 6. Department Comparison
    card(
      card_header("Department Comparison"),
      plotlyOutput("dept_comparison_chart", height = "300px")
    ),
    # 7. Student Search
    card(
      card_header("Student Search"),
      textInput("student_search_input", "Search Student ID/Name:", placeholder = "Enter ID or Name..."),
      DTOutput("student_search_results")
    ),
    # 8. Export Tools
    card(
      card_header("Export Tools"),
      p("Download analytics reports in various formats:"),
      layout_column_wrap(
        width = 1/2,
        downloadButton("export_csv", "Export CSV", class = "btn-primary w-100"),
        downloadButton("export_pdf", "Export PDF", class = "btn-secondary w-100")
      )
    )
  )
)
