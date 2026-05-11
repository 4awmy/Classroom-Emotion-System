# Lecturer UI - Overhauled v3.6.0 (Dashboard Focused)

# Helper: Navigation Actions
lecturer_course_click_button <- function(row_index, destination, icon_name) {
  tags$button(
    type = "button",
    class = "reference-round-action",
    onclick = sprintf(
      "Shiny.setInputValue('lecturer_course_nav', {row:%d, dest:'%s', nonce:Math.random()}, {priority:'event'});",
      row_index,
      destination
    ),
    icon(icon_name)
  )
}

# Main Course Table
lecturer_attendance_course_table <- function(courses_df, selected_code = "", selected_class = "") {
  if (is.null(courses_df) || nrow(courses_df) == 0) {
    return(tags$div("No classes assigned to you in the database.", style="padding: 20px; color: #888;"))
  }

  tags$table(
    class = "reference-attendance-table",
    tags$thead(
      tags$tr(
        tags$th("Course"),
        tags$th("Code"),
        tags$th("Class"),
        tags$th("Attendance History"),
        tags$th("Live Dashboard")
      )
    ),
    tags$tbody(
      lapply(seq_len(nrow(courses_df)), function(i) {
        row <- courses_df[i, ]
        tags$tr(
          class = if (identical(row$code, selected_code) && identical(row$class, selected_class)) "selected-reference-row" else NULL,
          tags$td(row$course),
          tags$td(row$code),
          tags$td(row$class),
          tags$td(lecturer_course_click_button(i, "reports", "chart-bar")),
          tags$td(lecturer_course_click_button(i, "live", "play-circle"))
        )
      })
    )
  )
}

lecturer_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(
      title = tags$span(
        uiOutput("dashboard_logo", inline = TRUE),
        tags$strong("AAST LMS")
      ),
      titleWidth = 280,
      tags$li(
        class = "dropdown",
        actionLink(
          "logout_btn",
          label = tagList(icon("sign-out-alt"), " Logout"),
          style = "color: #C9A84C; padding: 15px 20px;"
        )
      )
    ),
    shinydashboard::dashboardSidebar(
      width = 260,
      shinydashboard::sidebarMenu(
        id = "lecturer_menu",
        shinydashboard::menuItem("My Classes", tabName = "lec_roster", icon = icon("house")),
        shinydashboard::menuItem("Live Dashboard", tabName = "lec_live", icon = icon("play-circle")),
        shinydashboard::menuItem("Reports & Analytics", tabName = "lec_reports", icon = icon("chart-bar")),
        shinydashboard::menuItem("LMS Materials", tabName = "lec_materials", icon = icon("file-upload"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
        tags$style("
          .student-card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 15px; padding: 10px; }
          .student-card { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); overflow: hidden; text-align: center; border-bottom: 4px solid #ccc; transition: all 0.3s; }
          .student-card.present { border-bottom-color: #28a745; }
          .student-card.absent { border-bottom-color: #dc3545; }
          .student-img { width: 100%; height: 150px; object-fit: cover; background: #eee; }
          .student-name { font-size: 0.9em; font-weight: bold; padding: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
          .student-status { font-size: 0.7em; color: #666; padding-bottom: 5px; }
          .live-2-col { display: flex; gap: 20px; }
          .live-left { flex: 2; }
          .live-right { flex: 1; }
        ")
      ),
      shinydashboard::tabItems(

        # --- HOME: MY CLASSES ---
        shinydashboard::tabItem(tabName = "lec_roster",
          div(
            class = "reference-page-card",
            h2("My Active Courses"),
            uiOutput("lecturer_course_table"),
            hr(),

            # DEBUG PANEL
            shinydashboard::box(title = "System Debug Info", width = 12, collapsible = TRUE, collapsed = TRUE, status = "danger",
              verbatimTextOutput("lecturer_debug_out")
            )
          )
        ),

        # --- LIVE LECTURE DASHBOARD (2-COLUMN) ---
        shinydashboard::tabItem(tabName = "lec_live",
          h2("Live Session Command Center"),

          # Step 1: Selector Bar
          wellPanel(
            fluidRow(
              column(4, uiOutput("lec_live_course_selector")),
              column(4, uiOutput("lec_live_class_selector")),
              column(4, uiOutput("lec_live_session_info"))
            )
          ),

          div(class = "live-2-col",
            # Column 1: Video & Student Grid
            div(class = "live-left",
              shinydashboard::box(title = "Live AI Video Stream", width = 12, status = "primary", solidHeader = TRUE,
                uiOutput("lecturer_live_stream_ui"),
                footer = uiOutput("lecturer_live_session_actions")
              ),
              shinydashboard::box(title = "Live Attendance Grid (Snapshot Sync)", width = 12, status = "info",
                uiOutput("lecturer_attendance_grid")
              )
            ),

            # Column 2: Analytics & Ticker
            div(class = "live-right",
              shinydashboard::box(title = "Class Engagement", width = 12, status = "warning", solidHeader = TRUE,
                plotly::plotlyOutput("lecturer_d1_gauge", height = "250px")
              ),
              shinydashboard::box(title = "Live Sentiment Ticker", width = 12, status = "primary",
                uiOutput("lecturer_live_sentiment_ticker")
              ),
              shinydashboard::box(title = "AI Interventions", width = 12, status = "danger",
                actionButton("lecturer_trigger_refresher", "Push Refresher", class = "btn-info btn-block"),
                actionButton("lecturer_trigger_check", "Push AI Quiz", class = "btn-warning btn-block"),
                hr(),
                uiOutput("lecturer_confusion_alert_ui")
              )
            )
          )
        ),

        # --- REPORTS & ANALYTICS (2X2 GRID) ---
        shinydashboard::tabItem(tabName = "lec_reports",
          h2("Lecture Insights & Session History"),
          wellPanel(
            fluidRow(
              column(4, uiOutput("lec_report_course_selector")),
              column(4, uiOutput("lec_report_class_selector")),
              column(4, uiOutput("lec_report_session_selector"))
            )
          ),

          fluidRow(
            column(6, shinydashboard::box(title = "Emotion Frequency", width = 12, status = "primary", solidHeader = TRUE, plotly::plotlyOutput("lec_report_emotion_pie"))),
            column(6, shinydashboard::box(title = "Engagement Timeline", width = 12, status = "info", solidHeader = TRUE, plotly::plotlyOutput("lec_report_engagement_line")))
          ),
          fluidRow(
            column(6, shinydashboard::box(title = "Attendance Summary", width = 12, status = "success", solidHeader = TRUE, DT::dataTableOutput("lec_report_attendance_table"))),
            column(6, shinydashboard::box(title = "Student Performance Clusters", width = 12, status = "warning", solidHeader = TRUE, plotly::plotlyOutput("lec_report_student_clusters")))
          )
        ),

        # --- MATERIALS ---
        shinydashboard::tabItem(tabName = "lec_materials",
          h2("LMS Content Management"),
          wellPanel(
            fluidRow(
              column(4, selectInput("lecturer_material_week", "Academic Week", choices = paste("Week", 1:16))),
              column(4, fileInput("lecturer_material_file", "Upload Slides (PDF)")),
              column(4, br(), actionButton("lecturer_material_upload", "Upload & Process", class = "btn-primary btn-block"))
            )
          ),
          shinydashboard::box(title = "Weekly Content", width = 12, status = "primary",
            DT::dataTableOutput("lecturer_materials_table")
          )
        )
      )
    )
  )
}
