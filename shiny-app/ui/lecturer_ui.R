# Lecturer UI - Updated for Schema v2

lecturer_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(
      title = tags$span(
        tags$strong("AAST LMS"),
        tags$small(" | Lecturer", style = "font-size:0.8em; margin-right:4px;")
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
        # New v2 Tabs
        shinydashboard::menuItem("Personal Info", tabName = "lec_profile", icon = icon("user")),
        shinydashboard::menuItem("My Schedule", tabName = "lec_schedule", icon = icon("calendar-alt")),
        shinydashboard::menuItem("My Classes", tabName = "lec_classes", icon = icon("chalkboard")),
        
        # Legacy/Refactored Tabs
        shinydashboard::menuItem("Materials", tabName = "lec_materials", icon = icon("book")),
        shinydashboard::menuItem("Attendance", tabName = "lec_attendance", icon = icon("check-square")),
        shinydashboard::menuItem("Live Dashboard", tabName = "lec_live", icon = icon("tv"), badgeLabel = "LIVE", badgeColor = "green"),
        shinydashboard::menuItem("Reports", tabName = "lec_reports", icon = icon("file-alt")),
        
        # New v2 Exam Tab
        shinydashboard::menuItem("Exams", tabName = "lec_exams", icon = icon("shield-alt"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(
        # ====================================================================
        # Tab A: Personal Info
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_profile",
          h2("Personal Profile"),
          fluidRow(
            column(6,
              shinydashboard::box(
                title = "Lecturer Information", status = "primary", solidHeader = TRUE, width = NULL,
                uiOutput("lec_profile_card")
              )
            )
          )
        ),

        # ====================================================================
        # Tab B: Schedule
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_schedule",
          h2("Weekly Timetable"),
          p("Your assigned teaching slots for the current semester."),
          DT::dataTableOutput("lec_schedule_table")
        ),

        # ====================================================================
        # Tab C: My Classes
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_classes",
          h2("Class Management"),
          p("Overview of your sections and enrolled students."),
          uiOutput("lec_classes_grid")
        ),

        # ====================================================================
        # Tab D: Materials
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_materials",
          h2("LMS Content Management"),
          wellPanel(
            fluidRow(
              column(4, textInput("lec_mat_lecture", "Lecture ID")),
              column(4, textInput("lec_mat_title", "Title")),
              column(4, br(), actionButton("lec_mat_upload", "Upload", class="btn-primary"))
            )
          ),
          DT::dataTableOutput("lec_materials_table")
        ),

        # ====================================================================
        # Tab E: Attendance
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_attendance",
          h2("Attendance Verification"),
          fluidRow(
            column(4, textInput("lec_att_lecture", "Lecture ID")),
            column(4, br(), actionButton("lec_att_refresh", "Refresh", class="btn-info"))
          ),
          br(),
          uiOutput("lec_attendance_grid")
        ),

        # ====================================================================
        # Tab F: Live Dashboard
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_live",
          h2("Live Class Monitoring"),
          fluidRow(
            column(4, textInput("lec_live_lecture", "Lecture ID")),
            column(4, br(), actionButton("lec_live_start", "Start Session", class="btn-success"))
          ),
          br(),
          fluidRow(
            column(8, shiny::uiOutput("lec_live_stream_ui")),
            column(4, plotly::plotlyOutput("lec_live_gauge"))
          )
        ),

        # ====================================================================
        # Tab G: Reports
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_reports",
          h2("Performance Reports"),
          selectInput("lec_rep_student", "Select Student", choices = c()),
          plotly::plotlyOutput("lec_rep_trend")
        ),

        # ====================================================================
        # Tab H: Exams (NEW)
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_exams",
          h2("Exam Management & Proctoring"),
          tabsetPanel(
            tabPanel("Setup", 
              br(),
              wellPanel(
                textInput("lec_exam_id", "Exam ID"),
                textInput("lec_exam_title", "Title"),
                actionButton("lec_exam_create", "Create Exam", class="btn-primary")
              ),
              DT::dataTableOutput("lec_exam_table")
            ),
            tabPanel("Live Proctor", 
              br(),
              h4("Real-time Incident Feed"),
              DT::dataTableOutput("lec_exam_incidents")
            )
          )
        )
      )
    )
  )
}
