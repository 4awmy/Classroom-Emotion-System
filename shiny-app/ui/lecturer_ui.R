# Lecturer UI - Updated for Schema v3 (Hybrid)

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
        shinydashboard::menuItem("Personal Info", tabName = "lec_profile", icon = icon("user")),
        shinydashboard::menuItem("My Schedule", tabName = "lec_schedule", icon = icon("calendar-alt")),
        shinydashboard::menuItem("My Classes", tabName = "lec_classes", icon = icon("chalkboard")),
        shinydashboard::menuItem("Materials", tabName = "lec_materials", icon = icon("book")),
        shinydashboard::menuItem("Attendance", tabName = "lec_attendance", icon = icon("check-square")),
        shinydashboard::menuItem("Live Dashboard", tabName = "lec_live", icon = icon("tv"), badgeLabel = "LIVE", badgeColor = "green"),
        shinydashboard::menuItem("Reports", tabName = "lec_reports", icon = icon("file-alt")),
        shinydashboard::menuItem("Exams", tabName = "lec_exams", icon = icon("shield-alt"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(
        # Personal Info
        shinydashboard::tabItem(tabName = "lec_profile",
          h2("Personal Profile"),
          shinydashboard::box(title = "Lecturer Information", status = "primary", solidHeader = TRUE, width = 6, uiOutput("lec_profile_card"))
        ),

        # Schedule
        shinydashboard::tabItem(tabName = "lec_schedule",
          h2("Weekly Timetable"),
          DT::dataTableOutput("lec_schedule_table")
        ),

        # Classes
        shinydashboard::tabItem(tabName = "lec_classes",
          h2("Class Management"),
          uiOutput("lec_classes_grid")
        ),

        # Live Dashboard (REFACTORED - Command Center)
        shinydashboard::tabItem(tabName = "lec_live",
          h2("Live Class Monitoring"),
          tabsetPanel(
            tabPanel("Active Session", 
              br(),
              fluidRow(
                column(12, 
                  wellPanel(
                    fluidRow(
                      column(4, uiOutput("lec_live_course_selector")),
                      column(4, uiOutput("lec_live_class_selector")),
                      column(4, 
                        div(style="margin-top: 25px;",
                          actionButton("lec_live_start", "Start Session", class="btn-success", icon=icon("play")),
                          # Hidden input to store the generated lecture_id
                          conditionalPanel("false", textInput("active_lecture_id_hidden", ""))
                        )
                      )
                    ),
                    uiOutput("lec_live_schedule_info")
                  )
                )
              ),
              br(),
              fluidRow(
                column(8, 
                  shinydashboard::box(title = "Live Vision Feed", width = NULL, status = "primary", solidHeader = TRUE,
                    uiOutput("lec_live_stream_ui")
                  )
                ),
                column(4, 
                  shinydashboard::box(title = "Live Stats", width = NULL, status = "warning", solidHeader = TRUE,
                    shinydashboard::infoBoxOutput("lec_live_attendance_count", width = NULL),
                    plotly::plotlyOutput("lec_live_gauge", height="200px"),
                    tags$hr(),
                    h4("Confusion Ticker"),
                    uiOutput("lec_live_confusion_ticker")
                  )
                )
              )
            ),
            tabPanel("Session History",
              br(),
              wellPanel(
                uiOutput("lec_past_selector_ui")
              ),
              plotly::plotlyOutput("lec_past_analytics_plot", height="450px")
            )
          )
        ),
        
        # Exams
        shinydashboard::tabItem(tabName = "lec_exams",
          h2("Exam Management"),
          DT::dataTableOutput("lec_exam_table")
        ),
        
        # Placeholder tabs
        shinydashboard::tabItem(tabName = "lec_materials", h2("Materials")),
        shinydashboard::tabItem(tabName = "lec_attendance", h2("Attendance")),

        # Reports (REFACTORED - Command Center)
        shinydashboard::tabItem(tabName = "lec_reports",
          h2("Class Analytics & Reports"),
          wellPanel(
            fluidRow(
              column(4, uiOutput("lec_report_course_selector")),
              column(4, uiOutput("lec_report_class_selector")),
              column(4, uiOutput("lec_report_session_selector"))
            )
          ),
          fluidRow(
            column(6, 
              shinydashboard::box(title = "Emotion Frequency", width = NULL, status = "primary", solidHeader = TRUE,
                plotly::plotlyOutput("lec_report_emotion_pie", height = "300px")
              )
            ),
            column(6, 
              shinydashboard::box(title = "Engagement Timeline", width = NULL, status = "primary", solidHeader = TRUE,
                plotly::plotlyOutput("lec_report_engagement_line", height = "300px")
              )
            )
          ),
          fluidRow(
            column(6, 
              shinydashboard::box(title = "Student Attendance", width = NULL, status = "primary", solidHeader = TRUE,
                DT::dataTableOutput("lec_report_attendance_table")
              )
            ),
            column(6, 
              shinydashboard::box(title = "Individual Student Drill-down", width = NULL, status = "primary", solidHeader = TRUE,
                uiOutput("lec_report_student_selector_ui"),
                plotly::plotlyOutput("lec_report_student_timeline", height = "250px")
              )
            )
          )
        ),
      )
    )
  )
}
