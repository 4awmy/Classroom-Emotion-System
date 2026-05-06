# Admin UI - 8 Analytics Panels
# Layout: Tabbed dashboard with AAST branding

admin_ui <- function() {
  navbarPage(
    title = "AAST LMS - Admin Dashboard",
    theme = bslib::bs_theme(
      version = 5,
      primary = AAST_NAVY,
      secondary = AAST_GOLD
    ),
    # ========================================================================
    # Panel 1: Attendance Overview
    # ========================================================================
    tabPanel(
      "Attendance Overview",
      br(),
      h2("Attendance Summary by Course"),
      fluidRow(
        column(
          3,
          selectInput("admin_dept_filter", "Filter by Department:",
                     choices = c("All", "Engineering", "Sciences", "Maritime"),
                     selected = "All")
        ),
        column(
          3,
          dateRangeInput("admin_date_range", "Date Range:",
                        start = Sys.Date() - 30, end = Sys.Date())
        ),
        column(
          3,
          downloadButton("admin_attendance_xlsx", "Export to Excel")
        )
      ),
      br(),
      DT::dataTableOutput("admin_attendance_table")
    ),
    # ========================================================================
    # Panel 2: Engagement Trend
    # ========================================================================
    tabPanel(
      "Engagement Trend",
      br(),
      h2("Weekly Engagement Trends by Department"),
      plotly::plotlyOutput("admin_engagement_trend"),
      br(),
      p("Trend shows average engagement score over time by department")
    ),
    # ========================================================================
    # Panel 3: Department Engagement Heatmap
    # ========================================================================
    tabPanel(
      "Dept Engagement Heatmap",
      br(),
      h2("Department Engagement Heatmap"),
      plotOutput("admin_dept_heatmap"),
      br(),
      p("Heatmap shows engagement by department and week")
    ),
    # ========================================================================
    # Panel 4: At-Risk Cohort
    # ========================================================================
    tabPanel(
      "At-Risk Cohort",
      br(),
      h2("At-Risk Students (>20% Engagement Drop)"),
      p("Students showing significant engagement decline across 3+ consecutive lectures"),
      br(),
      DT::dataTableOutput("admin_at_risk_table"),
      br(),
      actionButton("admin_notify_button", "Notify Lecturer", class = "btn-warning")
    ),
    # ========================================================================
    # Panel 5: Lecture Effectiveness Score (LES)
    # ========================================================================
    tabPanel(
      "Lecture Effectiveness",
      br(),
      h2("Lecture Effectiveness Score (LES)"),
      p("LES = 0.5×avg_engagement + 0.3×(1−confusion_rate) + 0.2×attendance_rate"),
      br(),
      DT::dataTableOutput("admin_les_table")
    ),
    # ========================================================================
    # Panel 6: Emotion Distribution
    # ========================================================================
    tabPanel(
      "Emotion Distribution",
      br(),
      h2("Emotion State Distribution by Department"),
      plotOutput("admin_emotion_dist"),
      br(),
      p("Stacked bar chart showing all 6 emotion states across departments")
    ),
    # ========================================================================
    # Panel 7: Lecturer Cluster Map
    # ========================================================================
    tabPanel(
      "Lecturer Clusters",
      br(),
      h2("Lecturer Performance Clusters"),
      p("K-means clustering: High Performers | Consistent | Needs Support"),
      br(),
      plotly::plotlyOutput("admin_lecturer_clusters")
    ),
    # ========================================================================
    # Panel 8: Time-of-Day Heatmap
    # ========================================================================
    tabPanel(
      "Time-of-Day Analysis",
      br(),
      h2("Engagement by Time of Day & Weekday"),
      plotOutput("admin_tod_heatmap"),
      br(),
      p("Heatmap showing peak/low engagement times")
    ),
    # ========================================================================
    # Panel 9: Student Management
    # ========================================================================
    tabPanel(
      "Student Management",
      br(),
      h2("Manage Student Enrolment"),
      p("Manually add a student or view the existing roster with face encoding status."),
      br(),
      fluidRow(
        column(4,
          wellPanel(
            textInput("admin_student_id", "Student ID (9 digits)", placeholder = "231006367"),
            textInput("admin_student_name", "Full Name"),
            textInput("admin_student_email", "Email (Optional)"),
            fileInput("admin_student_photo", "Face Photo (Max 5MB)", accept = c("image/jpeg", "image/png")),
            actionButton("admin_student_submit", "Add Student", class = "btn-primary")
          )
        ),
        column(8,
          DT::dataTableOutput("admin_student_table")
        )
      )
    )
  )
}
