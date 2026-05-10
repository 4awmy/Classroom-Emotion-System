# Lecturer UI - 5 Submodules (shinydashboard sidebar layout)

lecturer_course_button_id <- function(prefix, code, class) {
  paste(prefix, code, class, sep = "_")
}

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
        tags$th("Day"),
        tags$th("Slots"),
        tags$th("Attendance"),
        tags$th("Mobile Attendance")
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
          tags$td(row$day),
          tags$td(row$slots),
          tags$td(lecturer_course_click_button(
            i,
            "students",
            "clipboard-list"
          )),
          tags$td(lecturer_course_click_button(
            i,
            "qr",
            "qrcode"
          ))
        )
      })
    )
  )
}

lecturer_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",  # overridden by custom.css
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
        tags$li(class = "header", "Home"),
        shinydashboard::menuItem(
          "Home",
          tabName = "lec_roster",
          icon = icon("house")
        ),
        tags$li(class = "header", "Lecturer"),
        shinydashboard::menuItem(
          "Courses",
          icon = icon("chevron-left"),
          startExpanded = TRUE,
          shinydashboard::menuSubItem("Schedule/Results/Samples", tabName = "lec_materials", icon = icon("calendar-days")),
          shinydashboard::menuSubItem("Attendance", tabName = "lec_attendance", icon = icon("check-square")),
          shinydashboard::menuSubItem("My Office Hours", tabName = "lec_live", icon = icon("clock")),
          shinydashboard::menuSubItem("Term Models", tabName = "lec_roster", icon = icon("book")),
          shinydashboard::menuSubItem("Feedback", tabName = "lec_reports", icon = icon("comment"))
        ),
        tags$li(class = "header", "Reports"),
        shinydashboard::menuItem(
          "Reports",
          icon = icon("chevron-left"),
          startExpanded = TRUE,
          shinydashboard::menuSubItem("Attendance Report", tabName = "lec_attendance", icon = icon("clipboard-list")),
          shinydashboard::menuSubItem("Progress Sheet", tabName = "lec_reports", icon = icon("chart-line")),
          shinydashboard::menuSubItem("Course Review", tabName = "lec_reports", icon = icon("file-lines")),
          shinydashboard::menuSubItem("Program Reports", tabName = "lec_reports", icon = icon("folder-open"))
        ),
        shinydashboard::menuItem(
          "Student Attendance",
          tabName = "lec_attendance_students",
          icon = icon("users"),
          style = "display: none;"
        ),
        shinydashboard::menuItem(
          "Mobile Attendance QR",
          tabName = "lec_attendance_qr",
          icon = icon("qrcode"),
          style = "display: none;"
        )
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(

        # ====================================================================
        # Submodule A: Roster Setup
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_roster",
          h2("Student Roster Setup"),
          p("Upload the student roster XLSX file. Face images are fetched automatically from Google Drive links."),
          br(),
          wellPanel(
            fileInput("lecturer_roster_xlsx", "Select Roster XLSX File",
                     accept = c(".xlsx")),
            helpText("Expected columns: student_id, name, email, photo_link"),
            br(),
            actionButton("lecturer_roster_upload", "Upload Roster",
                        class = "btn-primary", icon = icon("upload"))
          ),
          br(),
          uiOutput("lecturer_roster_status")
        ),

        # ====================================================================
        # Submodule B: LMS Materials
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_materials",
          h2("LMS Content Management"),
          p("Organize materials by academic week."),
          br(),
          wellPanel(
            fluidRow(
              column(4,
                textInput("lecturer_lecture_select", "Lecture ID",
                          placeholder = "e.g. L1")
              ),
              column(4,
                selectInput("lecturer_week_select", "Academic Week",
                           choices = paste("Week", 1:16))
              ),
              column(4,
                textInput("lecturer_material_title", "Material Title")
              )
            ),
            fileInput("lecturer_material_file", "Select File (PDF, PPT, etc.)",
                     accept = c(".pdf", ".pptx", ".xlsx", ".docx")),
            actionButton("lecturer_material_upload", "Upload to LMS",
                        class = "btn-primary", icon = icon("upload"))
          ),
          br(),
          DT::dataTableOutput("lecturer_materials_table")
        ),

        # ====================================================================
        # Submodule C: Attendance
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_attendance",
          div(
            class = "reference-page-card reference-attendance-page",
            div(class = "semester-eyebrow", "The First Semester 2025/2026"),
            div(
              class = "attendance-title-row",
              h2("Attendance"),
              div(
                class = "department-filter",
                tags$label("Department"),
                selectInput(
                  "lecturer_reference_department",
                  NULL,
                  choices = c("All", "Computing", "Business", "Engineering"),
                  selected = "All",
                  width = "100%"
                )
              )
            ),
            div(
              class = "reference-attendance-table-wrap",
              uiOutput("lecturer_course_table")
            )
          )
        ),

        shinydashboard::tabItem(
          tabName = "lec_attendance_students",
          div(
            class = "course-attendance-detail",
            div(
              class = "course-attendance-detail-header",
              uiOutput("lecturer_selected_course_title"),
              div(
                class = "course-attendance-actions",
                actionButton("lecturer_back_to_courses_from_students", "Back",
                            class = "btn-info", icon = icon("arrow-left")),
                actionButton("lecturer_attendance_refresh", "Refresh",
                            class = "btn-info", icon = icon("sync")),
                actionButton("lecturer_attendance_save", "Save Changes",
                            class = "btn-success", icon = icon("save"))
              )
            ),
            uiOutput("lecturer_attendance_grid")
          )
        ),

        shinydashboard::tabItem(
          tabName = "lec_attendance_qr",
          div(
            class = "course-attendance-detail",
            div(
              class = "course-attendance-detail-header",
              uiOutput("lecturer_selected_course_title"),
              div(
                class = "course-attendance-actions",
                actionButton("lecturer_back_to_courses_from_qr", "Back",
                            class = "btn-info", icon = icon("arrow-left")),
                actionButton("lecturer_qr_generate", "Regenerate QR",
                            class = "btn-primary", icon = icon("qrcode"))
              )
            ),
            uiOutput("lecturer_mobile_attendance_panel")
          )
        ),

        # ====================================================================
        # Submodule D: Live Lecture Dashboard (D1–D7 + Analytics)
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_live",
          h2("Live Class Monitoring"),
          fluidRow(
            column(3,
              wellPanel(
                h4(icon("gear"), "Session Config"),
                textInput("lecturer_live_lecture", "Lecture ID", placeholder = "e.g. L1"),
                actionButton("lecturer_live_start", "Start Session", class = "btn-success btn-block", icon = icon("play")),
                br(),
                actionButton("lecturer_live_end", "End Session", class = "btn-danger btn-block", icon = icon("stop"))
              )
            ),
            column(5,
              wellPanel(
                h4(icon("video"), "Vision Node Setup"),
                p("Process AI on this laptop to use a Phone or Webcam."),
                selectInput("lecturer_vision_source", "Camera Source",
                           choices = list("Laptop Webcam (0)" = "0", "Phone (IP Webcam)" = "ip", "External Cam" = "1")),
                conditionalPanel(
                  condition = "input.lecturer_vision_source == 'ip'",
                  textInput("lecturer_vision_ip", "Phone IP Address", placeholder = "192.168.1.5:8080")
                ),
                downloadButton("lecturer_download_launcher", "Download Launcher", class = "btn-info btn-block")
              )
            ),
            column(4,
              wellPanel(
                h4(icon("link"), "Cloud Status"),
                uiOutput("lecturer_cloud_health_ui"),
                br(),
                p("Status: ", strong(textOutput("lecturer_vision_status_text", inline = TRUE)))
              )
            )
          ),
          br(),

          shinydashboard::tabBox(
            id = "lecturer_live_tabs",
            width = 12,
            
            # Tab 1: Live Feed & Primary Metrics
            tabPanel(
              title = "Live Stream", icon = icon("video"),
              fluidRow(
                column(8,
                  shinydashboard::box(
                    title = "Live AI Video Feed", status = "primary", solidHeader = TRUE, width = 12,
                    shiny::div(
                      style = "text-align: center; background: #000; min-height: 400px; border-radius: 8px; overflow: hidden; position: relative;",
                      shiny::uiOutput("lecturer_live_stream_ui")
                    )
                  )
                ),
                column(4,
                  shinydashboard::box(
                    title = "Live Sentiment Ticker", status = "warning", solidHeader = TRUE, width = 12,
                    shiny::uiOutput("lecturer_live_sentiment_ticker")
                  ),
                  shinydashboard::box(
                    title = "Engagement Gauge", status = "primary", solidHeader = TRUE, width = 12,
                    plotly::plotlyOutput("lecturer_d1_gauge", height = "200px")
                  )
                )
              )
            ),

            # Tab 2: Real-time Indicators
            tabPanel(
              title = "Activity Monitors", icon = icon("clock"),
              fluidRow(
                shinydashboard::box(
                  title = "Emotion Timeline", status = "primary", solidHeader = TRUE, width = 12,
                  plotly::plotlyOutput("lecturer_d2_timeline", height = "350px")
                )
              ),
              fluidRow(
                shinydashboard::box(
                  title = "Cognitive Load", status = "warning", solidHeader = TRUE, width = 4,
                  uiOutput("lecturer_d3_load")
                ),
                shinydashboard::box(
                  title = "Class Valence", status = "info", solidHeader = TRUE, width = 4,
                  plotly::plotlyOutput("lecturer_d4_valence", height = "200px")
                ),
                shinydashboard::box(
                  title = "Peak Confusion", status = "danger", solidHeader = TRUE, width = 4,
                  uiOutput("lecturer_d7_peak")
                )
              )
            ),

            # Tab 3: Behavioral Heatmaps
            tabPanel(
              title = "Heatmaps", icon = icon("th"),
              fluidRow(
                shinydashboard::box(
                  title = "Per-Student Emotion Heatmap", status = "primary", solidHeader = TRUE, width = 12,
                  plotOutput("lecturer_d5_heatmap", height = "400px")
                )
              ),
              fluidRow(
                shinydashboard::box(
                  title = "Course Engagement Heatmap", status = "info", solidHeader = TRUE, width = 12,
                  plotOutput("lecturer_course_heatmap", height = "400px")
                )
              )
            ),

            # Tab 4: Performance Analytics
            tabPanel(
              title = "Insights & Trends", icon = icon("chart-line"),
              fluidRow(
                column(6,
                  shinydashboard::box(
                    title = "Engagement Trend", width = NULL, status = "primary", solidHeader = TRUE,
                    plotly::plotlyOutput("lecturer_class_engagement_trend", height = "350px")
                  )
                ),
                column(6,
                  shinydashboard::box(
                    title = "Student Behavior Clusters", width = NULL, status = "info", solidHeader = TRUE,
                    plotly::plotlyOutput("lecturer_student_clusters", height = "350px")
                  )
                )
              ),
              fluidRow(
                shinydashboard::box(
                  title = "Lecture Effectiveness Score (LES)", status = "success", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("lecturer_les_table")
                )
              )
            ),

            # Tab 5: Attention & Attendance
            tabPanel(
              title = "Student Status", icon = icon("user-check"),
              fluidRow(
                column(6,
                  shinydashboard::box(
                    title = "At-Risk Students", status = "danger", solidHeader = TRUE, width = 12,
                    DT::dataTableOutput("lecturer_at_risk_table")
                  )
                ),
                column(6,
                  shinydashboard::box(
                    title = "Persistent Struggle Alerts", status = "warning", solidHeader = TRUE, width = 12,
                    DT::dataTableOutput("lecturer_d6_struggle")
                  )
                )
              ),
              fluidRow(
                shinydashboard::box(
                  title = "Full Attendance Log", status = "primary", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("lecturer_attendance_log_table")
                )
              )
            ),

            # Tab 6: Exam & Time Analysis
            tabPanel(
              title = "Exam & Time", icon = icon("shield-alt"),
              fluidRow(
                shinydashboard::box(
                  title = "Peak Engagement by Time of Day", status = "primary", solidHeader = TRUE, width = 12,
                  plotOutput("lecturer_tod_heatmap", height = "400px")
                )
              ),
              fluidRow(
                shinydashboard::box(
                  title = "Proctoring Incident Logs", status = "danger", solidHeader = TRUE, width = 12,
                  DT::dataTableOutput("lecturer_incidents_table")
                )
              )
            )
          )
        ),

        # ====================================================================
        # Submodule E: Student Reports
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_reports",
          h2("Student Performance Reports"),
          br(),
          fluidRow(
            column(5,
              selectInput("lecturer_student_select", "Select Student:",
                         choices = c("Loading..." = ""))
            ),
            column(4,
              br(),
              downloadButton("lecturer_student_pdf", "Download PDF",
                            class = "btn-primary")
            )
          ),
          br(),
          tabsetPanel(
            tabPanel(
              "Dashboard",
              br(),
              fluidRow(
                column(6,
                  shinydashboard::box(
                    title = "Engagement Trend",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_trend")
                  )
                ),
                column(6,
                  shinydashboard::box(
                    title = "Emotion Distribution",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_emotions")
                  )
                )
              ),
              fluidRow(
                column(12,
                  shinydashboard::box(
                    title = "Cognitive Load Timeline",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_load")
                  )
                )
              )
            ),
            tabPanel(
              "AI Plan",
              br(),
              shinydashboard::box(
                title = "AI Intervention Plan",
                width = 12,
                uiOutput("lecturer_student_plan_ui")
              )
            )
          )
        )
      )
    )
  )
}
