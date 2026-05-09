# Admin UI - 13 Management & Analytics Panels (shinydashboard sidebar layout)

admin_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",  # overridden by custom.css
    shinydashboard::dashboardHeader(
      title = tags$span(
        tags$strong("AAST LMS"),
        tags$small(" | Admin", style = "font-size:0.8em; margin-right:4px;")
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
        id = "admin_menu",
        shinydashboard::menuItem("Overview", tabName = "admin_attendance", icon = icon("chart-bar")),
        shinydashboard::menuItem("Global Statistics", tabName = "admin_stats", icon = icon("calculator"), badgeLabel = "NEW", badgeColor = "blue"),
        shinydashboard::menuItem("Audit & Compliance", tabName = "admin_audit", icon = icon("clipboard-check"), badgeLabel = "AUDIT", badgeColor = "red"),
        shinydashboard::menuItem("Engagement", tabName = "admin_engagement", icon = icon("chart-line")),
        shinydashboard::menuItem("Dept Heatmap", tabName = "admin_heatmap", icon = icon("th")),
        shinydashboard::menuItem("At-Risk", tabName = "admin_atrisk", icon = icon("exclamation-triangle")),
        shinydashboard::menuItem("LES Scores", tabName = "admin_les", icon = icon("star")),
        shinydashboard::menuItem("Emotion Mix", tabName = "admin_emotions", icon = icon("smile")),
        shinydashboard::menuItem("Clusters", tabName = "admin_clusters", icon = icon("users")),
        shinydashboard::menuItem("Time Analysis", tabName = "admin_time", icon = icon("clock")),
        tags$li(class = "header", "MANAGEMENT"),
        shinydashboard::menuItem("Lecturers", tabName = "admin_lecturers", icon = icon("chalkboard-teacher")),
        shinydashboard::menuItem("Students", tabName = "admin_students", icon = icon("user-plus")),
        shinydashboard::menuItem("Incidents", tabName = "admin_incidents", icon = icon("shield-alt"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(

        # ====================================================================
        # Panel 0: Global Statistics
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_stats",
          h2("System-Wide Statistical Analysis"),
          p("Filter by Student, Course, or Lecture to perform deep emotional trend analysis."),
          br(),
          wellPanel(
            fluidRow(
              column(4, uiOutput("stats_course_selector")),
              column(4, uiOutput("stats_lecture_selector")),
              column(4, uiOutput("stats_student_selector"))
            )
          ),
          fluidRow(
            column(6,
              shinydashboard::box(
                title = "Emotion Frequency Distribution", width = NULL, status = "primary", solidHeader = TRUE,
                plotly::plotlyOutput("stats_emotion_pie")
              )
            ),
            column(6,
              shinydashboard::box(
                title = "Engagement Score Calculation", width = NULL, status = "info", solidHeader = TRUE,
                plotly::plotlyOutput("stats_engagement_gauge")
              )
            )
          ),
          fluidRow(
            column(12,
              shinydashboard::box(
                title = "Time-Based Emotional Trends", width = NULL, status = "warning", solidHeader = TRUE,
                plotly::plotlyOutput("stats_trend_line")
              )
            )
          )
        ),

        # ====================================================================
        # Panel Audit: Punctuality & Statistical Validation (NEW)
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_audit",
          h2("Administrative Audit & Statistical Compliance"),
          p("Auditing lecturer punctuality and session reliability using inferential statistics."),
          br(),
          wellPanel(
            fluidRow(
              column(6, uiOutput("audit_lecturer_selector")),
              column(6, dateInput("audit_date_filter", "Select Date:", value = Sys.Date()))
            )
          ),
          fluidRow(
            column(12,
              shinydashboard::box(
                title = "Compliance Flagged Sessions (Start Delay > 10m / Early Exit > 10m)", 
                width = NULL, status = "danger", solidHeader = TRUE,
                DT::dataTableOutput("admin_audit_table")
              )
            )
          ),
          fluidRow(
            column(6,
              shinydashboard::box(
                title = "Data Reliability (95% Confidence Interval)", width = NULL, status = "info", solidHeader = TRUE,
                plotly::plotlyOutput("admin_reliability_plot")
              )
            ),
            column(6,
              shinydashboard::box(
                title = "Hypothesis Test (α=0.05): Premature Conclusion", width = NULL, status = "warning", solidHeader = TRUE,
                DT::dataTableOutput("admin_conclusion_test_results")
              )
            )
          )
        ),

        # ====================================================================
        # Panel 1: Attendance Overview
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_attendance",
          h2("Attendance Summary"),
          fluidRow(
            column(3,
              selectInput("admin_dept_filter", "Filter by Department:",
                         choices = c("All"), selected = "All")
            ),
            column(4,
              dateRangeInput("admin_date_range", "Date Range:",
                            start = Sys.Date() - 30, end = Sys.Date())
            ),
            column(3,
              br(),
              downloadButton("admin_attendance_xlsx", "Export Excel")
            )
          ),
          br(),
          DT::dataTableOutput("admin_attendance_table")
        ),

        # ====================================================================
        # Panel 2: Engagement Trend
        # ====================================================================
        ... (Rest of code remains same) ...
      )
    )
  )
}
