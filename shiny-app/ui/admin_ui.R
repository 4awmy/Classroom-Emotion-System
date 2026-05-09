# Admin UI - 14 Management & Analytics Panels (shinydashboard sidebar layout)

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
      id = "admin_sidebar",
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
        
        tags$li(class = "header", "ADMINISTRATION"),
        shinydashboard::menuItem("Course Manager", tabName = "admin_courses", icon = icon("book")),
        shinydashboard::menuItem("Class Manager", tabName = "admin_classes", icon = icon("chalkboard")),
        
        tags$li(class = "header", "USER ACCESS"),
        shinydashboard::menuItem("Admins", tabName = "admin_manage_admins", icon = icon("user-shield")),
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

        # --- Statistics ---
        shinydashboard::tabItem(tabName = "admin_stats",
          h2("System-Wide Statistical Analysis"),
          wellPanel(fluidRow(column(4, uiOutput("stats_course_selector")), column(4, uiOutput("stats_lecture_selector")), column(4, uiOutput("stats_student_selector")))),
          fluidRow(column(6, shinydashboard::box(title = "Emotion Frequency", width = NULL, status = "primary", solidHeader = TRUE, plotly::plotlyOutput("stats_emotion_pie"))),
                   column(6, shinydashboard::box(title = "Engagement Score", width = NULL, status = "info", solidHeader = TRUE, plotly::plotlyOutput("stats_engagement_gauge")))),
          fluidRow(column(12, shinydashboard::box(title = "Time-Based Trends", width = NULL, status = "warning", solidHeader = TRUE, plotly::plotlyOutput("stats_trend_line"))))
        ),

        # --- Audit ---
        shinydashboard::tabItem(tabName = "admin_audit",
          h2("Audit & Compliance"),
          wellPanel(fluidRow(column(6, uiOutput("audit_lecturer_selector")), column(6, dateInput("audit_date_filter", "Select Date:", value = Sys.Date())))),
          DT::dataTableOutput("admin_audit_table"),
          fluidRow(column(6, shinydashboard::box(title = "Reliability (95% CI)", width = NULL, status = "info", solidHeader = TRUE, plotly::plotlyOutput("admin_reliability_plot"))),
                   column(6, shinydashboard::box(title = "Hypothesis Test", width = NULL, status = "warning", solidHeader = TRUE, DT::dataTableOutput("admin_conclusion_test_results"))))
        ),

        # --- Course Manager ---
        shinydashboard::tabItem(tabName = "admin_courses",
          h2("Course Management"),
          fluidRow(
            column(4,
              wellPanel(
                textInput("course_id_in", "Course ID (e.g. CS101)"),
                textInput("course_title_in", "Course Title"),
                textInput("course_dept_in", "Department"),
                numericInput("course_credits_in", "Credit Hours", value = 3),
                actionButton("course_submit", "Create Course", class="btn-primary")
              )
            ),
            column(8, DT::dataTableOutput("admin_courses_table"))
          )
        ),

        # --- Class Manager ---
        shinydashboard::tabItem(tabName = "admin_classes",
          h2("Class/Section Management"),
          fluidRow(
            column(4,
              wellPanel(
                uiOutput("class_course_selector"),
                uiOutput("class_lecturer_selector"),
                textInput("class_id_in", "Class ID", placeholder="CS101_A"),
                textInput("class_section_in", "Section Name", placeholder="Section 101"),
                textInput("class_room_in", "Room", placeholder="Room 402"),
                actionButton("class_submit", "Create Class", class="btn-primary")
              )
            ),
            column(8, DT::dataTableOutput("admin_classes_table"))
          )
        ),

        # --- Admin Management ---
        shinydashboard::tabItem(tabName = "admin_manage_admins",
          h2("Admin Access Management"),
          fluidRow(
            column(4,
              wellPanel(
                textInput("adm_id_in", "Admin ID"),
                textInput("adm_name_in", "Full Name"),
                textInput("adm_email_in", "Email"),
                passwordInput("adm_pwd_in", "Password"),
                actionButton("adm_submit", "Add Admin", class="btn-primary")
              )
            ),
            column(8, DT::dataTableOutput("admin_list_table"))
          )
        ),

        # --- Lecturer Management ---
        shinydashboard::tabItem(tabName = "admin_lecturers",
          h2("Lecturer Management"),
          fluidRow(
            column(4,
              wellPanel(
                textInput("admin_lecturer_id", "Lecturer ID"),
                textInput("admin_lecturer_name", "Full Name"),
                textInput("admin_lecturer_email", "Email"),
                passwordInput("admin_lecturer_pwd", "Password"),
                actionButton("admin_lecturer_submit", "Create Lecturer", class="btn-primary")
              )
            ),
            column(8, DT::dataTableOutput("admin_lecturer_table"))
          )
        ),

        # --- Student Management ---
        shinydashboard::tabItem(tabName = "admin_students",
          h2("Student Management"),
          fluidRow(
            column(4,
              wellPanel(
                textInput("admin_student_id", "Student ID"),
                textInput("admin_student_name", "Full Name"),
                textInput("admin_student_email", "Email"),
                passwordInput("admin_student_pwd", "Password"),
                fileInput("admin_student_photo", "Face Photo"),
                actionButton("admin_student_submit", "Add Student", class="btn-primary"),
                tags$hr(),
                h4("Action on Selected"),
                actionButton("admin_student_delete", "Delete Selected", class="btn-danger")
              )
            ),
            column(8, DT::dataTableOutput("admin_student_table"))
          )
        ),

        # --- Rest of panels (Attendance, Engagement, etc.) ---
        shinydashboard::tabItem(tabName = "admin_attendance", h2("Overview"), DT::dataTableOutput("admin_attendance_table")),
        shinydashboard::tabItem(tabName = "admin_engagement", h2("Engagement"), plotly::plotlyOutput("admin_confidence_trend")),
        shinydashboard::tabItem(tabName = "admin_heatmap", h2("Heatmap"), plotOutput("admin_dept_heatmap")),
        shinydashboard::tabItem(tabName = "admin_atrisk", h2("At-Risk"), DT::dataTableOutput("admin_at_risk_table")),
        shinydashboard::tabItem(tabName = "admin_les", h2("LES"), DT::dataTableOutput("admin_les_table")),
        shinydashboard::tabItem(tabName = "admin_emotions", h2("Emotions"), plotOutput("admin_emotion_dist")),
        shinydashboard::tabItem(tabName = "admin_clusters", h2("Clusters"), plotly::plotlyOutput("admin_lecturer_clusters")),
        shinydashboard::tabItem(tabName = "admin_time", h2("Time"), plotOutput("admin_tod_heatmap")),
        shinydashboard::tabItem(tabName = "admin_incidents", h2("Incidents"), DT::dataTableOutput("admin_incidents_table"))
      )
    )
  )
}
