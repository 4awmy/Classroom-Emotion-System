# Admin UI - 10 Analytics Panels (shinydashboard sidebar layout)

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
        shinydashboard::menuItem(
          "Attendance",
          tabName = "admin_attendance",
          icon = icon("calendar-check")
        ),
        shinydashboard::menuItem(
          "Engagement",
          tabName = "admin_engagement",
          icon = icon("chart-line")
        ),
        shinydashboard::menuItem(
          "Dept Heatmap",
          tabName = "admin_heatmap",
          icon = icon("th")
        ),
        shinydashboard::menuItem(
          "At-Risk",
          tabName = "admin_atrisk",
          icon = icon("exclamation-triangle")
        ),
        shinydashboard::menuItem(
          "LES",
          tabName = "admin_les",
          icon = icon("star")
        ),
        shinydashboard::menuItem(
          "Emotions",
          tabName = "admin_emotions",
          icon = icon("smile")
        ),
        shinydashboard::menuItem(
          "Clusters",
          tabName = "admin_clusters",
          icon = icon("users")
        ),
        shinydashboard::menuItem(
          "Time Analysis",
          tabName = "admin_time",
          icon = icon("clock")
        ),
        shinydashboard::menuItem(
          "Students",
          tabName = "admin_students",
          icon = icon("user-plus")
        ),
        shinydashboard::menuItem(
          "Incidents",
          tabName = "admin_incidents",
          icon = icon("shield-alt")
        )
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(

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
        shinydashboard::tabItem(
          tabName = "admin_engagement",
          h2("Weekly Engagement Trend"),
          p("Average engagement score per lecture group over time."),
          plotly::plotlyOutput("admin_confidence_trend", height = "450px")
        ),

        # ====================================================================
        # Panel 3: Dept Heatmap
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_heatmap",
          h2("Department Engagement Heatmap"),
          plotOutput("admin_dept_heatmap", height = "450px")
        ),

        # ====================================================================
        # Panel 4: At-Risk Cohort
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_atrisk",
          h2("At-Risk Students"),
          p("Students with >20% engagement drop over 3+ consecutive lectures."),
          br(),
          DT::dataTableOutput("admin_at_risk_table"),
          br(),
          actionButton("admin_notify_button", "Notify Lecturer",
                       class = "btn-warning", icon = icon("bell"))
        ),

        # ====================================================================
        # Panel 5: Lecture Effectiveness Score
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_les",
          h2("Lecture Effectiveness Score"),
          p("LES = 0.5 × avg_engagement + 0.3 × (1 − confusion_rate) + 0.2 × attendance_rate"),
          br(),
          DT::dataTableOutput("admin_les_table")
        ),

        # ====================================================================
        # Panel 6: Emotion Distribution
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_emotions",
          h2("Emotion Distribution"),
          p("Analysis of emotional states across departments and time."),
          br(),
          fluidRow(
            column(6,
              shinydashboard::box(
                title = "Emotion Mix by Department",
                width = NULL, status = "primary", solidHeader = TRUE,
                plotOutput("admin_emotion_dist", height = "400px")
              )
            ),
            column(6,
              shinydashboard::box(
                title = "Emotion Trend Over Time",
                width = NULL, status = "info", solidHeader = TRUE,
                plotly::plotlyOutput("admin_emotion_trend", height = "400px")
              )
            )
          )
        ),

        # ====================================================================
        # Panel 7: Clusters
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_clusters",
          h2("Performance Clusters"),
          p("K-means clustering for both lecturers and students based on engagement patterns."),
          br(),
          fluidRow(
            column(6,
              shinydashboard::box(
                title = "Lecturer Clusters",
                width = NULL, status = "primary", solidHeader = TRUE,
                plotly::plotlyOutput("admin_lecturer_clusters", height = "400px")
              )
            ),
            column(6,
              shinydashboard::box(
                title = "Student Behavior Clusters",
                width = NULL, status = "info", solidHeader = TRUE,
                plotly::plotlyOutput("admin_student_clusters", height = "400px")
              )
            )
          )
        ),

        # ====================================================================
        # Panel 8: Time-of-Day Heatmap
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_time",
          h2("Time-of-Day Engagement"),
          p("Heatmap showing peak and low engagement times by weekday and hour."),
          plotOutput("admin_tod_heatmap", height = "450px")
        ),

        # ====================================================================
        # Panel 9: Student Management
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_students",
          h2("Student Management"),
          p("Add a student manually or view the existing roster with face encoding status."),
          br(),
          fluidRow(
            column(4,
              wellPanel(
                textInput("admin_student_id", "Student ID (9 digits)",
                         placeholder = "231006367"),
                textInput("admin_student_name", "Full Name"),
                textInput("admin_student_email", "Email (optional)"),
                fileInput("admin_student_photo", "Face Photo (Max 5MB)",
                         accept = c("image/jpeg", "image/png")),
                actionButton("admin_student_submit", "Add Student",
                             class = "btn-primary", icon = icon("user-plus"))
              )
            ),
            column(8,
              DT::dataTableOutput("admin_student_table")
            )
          )
        ),

        # ====================================================================
        # Panel 10: Exam Incidents
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "admin_incidents",
          h2("Proctoring Incident Logs"),
          p("Review flags detected during exam sessions."),
          br(),
          DT::dataTableOutput("admin_incidents_table")
        )
      )
    )
  )
}
