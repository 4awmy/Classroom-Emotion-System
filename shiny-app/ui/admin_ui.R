# Admin UI - AAST LMS Portal - Consolidated User, Course & Enrollment Management

admin_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",

    # ── HEADER ────────────────────────────────────────────────────────────────
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
          style = "color: #C9A84C; padding: 15px 20px; font-weight: 600;"
        )
      )
    ),

    # ── SIDEBAR ───────────────────────────────────────────────────────────────
    shinydashboard::dashboardSidebar(
      width = 260,
      shinydashboard::sidebarMenu(
        id = "admin_menu",

        shinydashboard::menuItem(
          "Overview",
          tabName = "admin_overview",
          icon    = icon("tachometer-alt")
        ),

        tags$li(class = "header", "USER MANAGEMENT"),

        shinydashboard::menuItem(
          "Manage Admins",
          tabName = "admin_manage_admins",
          icon    = icon("user-shield")
        ),
        shinydashboard::menuItem(
          "Manage Lecturers",
          tabName = "admin_lecturers",
          icon    = icon("chalkboard-teacher")
        ),
        shinydashboard::menuItem(
          "Manage Students",
          tabName = "admin_students",
          icon    = icon("user-graduate")
        ),

        tags$li(class = "header", "ACADEMIC STRUCTURE"),

        shinydashboard::menuItem(
          "Course Manager",
          tabName = "admin_courses",
          icon    = icon("book")
        ),
        shinydashboard::menuItem(
          "Class & Sections",
          tabName = "admin_classes",
          icon    = icon("chalkboard")
        ),
        shinydashboard::menuItem(
          "Enrollment",
          tabName = "admin_enrollment",
          icon    = icon("users")
        ),

        tags$li(class = "header", "ANALYTICS"),

        shinydashboard::menuItem(
          "Engagement Log",
          tabName = "admin_engagement",
          icon    = icon("chart-line")
        ),
        shinydashboard::menuItem(
          "Emotion Analysis",
          tabName = "admin_emotions",
          icon    = icon("smile")
        ),
        shinydashboard::menuItem(
          "Incident Audit",
          tabName = "admin_incidents",
          icon    = icon("shield-alt")
        )
      )
    ),

    # ── BODY ──────────────────────────────────────────────────────────────────
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),

      shinydashboard::tabItems(

        # ── OVERVIEW ──────────────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_overview",
          h2("System Overview"),
          fluidRow(
            shinydashboard::valueBoxOutput("stat_students", width = 4),
            shinydashboard::valueBoxOutput("stat_lecturers", width = 4),
            shinydashboard::valueBoxOutput("stat_courses", width = 4)
          ),
          fluidRow(
            shinydashboard::box(
              title      = "Recent Attendance",
              width      = 6,
              status     = "primary",
              solidHeader = TRUE,
              DT::dataTableOutput("admin_attendance_table")
            ),
            shinydashboard::box(
              title      = "Global Emotion Mix",
              width      = 6,
              status     = "info",
              solidHeader = TRUE,
              plotOutput("admin_emotion_dist", height = "300px")
            )
          )
        ),

        # ── MANAGE ADMINS ─────────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_manage_admins",
          h2("Administrator Roster"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add / Edit Admin"),
                textInput("adm_id_in",    "Admin User ID"),
                textInput("adm_name_in",  "Full Name"),
                textInput("adm_email_in", "AAST Email"),
                passwordInput("adm_pwd_in", "Password"),
                actionButton(
                  "adm_submit", "Save Admin",
                  class = "btn-primary btn-block",
                  icon  = icon("save")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title  = "System Administrators",
                width  = 12,
                status = "primary",
                solidHeader = TRUE,
                DT::dataTableOutput("admin_list_table")
              )
            )
          )
        ),

        # ── MANAGE LECTURERS ──────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_lecturers",
          h2("Lecturer Roster"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add / Edit Lecturer"),
                textInput("admin_lecturer_id",    "Lecturer ID (e.g. abahmed)"),
                textInput("admin_lecturer_name",  "Full Name"),
                textInput("admin_lecturer_email", "AAST Email"),
                textInput("admin_lecturer_dept",  "Department"),
                passwordInput("admin_lecturer_pwd", "Password"),
                actionButton(
                  "admin_lecturer_submit", "Save Lecturer",
                  class = "btn-primary btn-block",
                  icon  = icon("save")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title  = "Faculty Roster",
                width  = 12,
                status = "primary",
                solidHeader = TRUE,
                DT::dataTableOutput("admin_lecturer_table")
              )
            )
          )
        ),

        # ── MANAGE STUDENTS ───────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_students",
          h2("Student Roster (Master)"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add / Edit Student"),
                textInput("admin_student_id",    "Registration Number"),
                textInput("admin_student_name",  "Full Name"),
                textInput("admin_student_email", "Email"),
                selectInput(
                  "admin_student_dept", "Department",
                  choices = c(
                    "Computing",
                    "Engineering",
                    "Business",
                    "Artificial Intelligence"
                  )
                ),
                passwordInput("admin_student_pwd", "Password"),
                fileInput(
                  "admin_student_photo", "Face Photo",
                  accept = c(".jpg", ".jpeg", ".png")
                ),
                actionButton(
                  "admin_student_submit", "Save Student",
                  class = "btn-primary btn-block",
                  icon  = icon("save")
                ),
                hr(),
                actionButton(
                  "admin_student_delete", "Delete Selected",
                  class = "btn-danger btn-block",
                  icon  = icon("trash")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title  = "Full Student Body",
                width  = 12,
                status = "primary",
                solidHeader = TRUE,
                DT::dataTableOutput("admin_student_table")
              )
            )
          )
        ),

        # ── COURSE MANAGER ────────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_courses",
          h2("Course Catalog"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add Course"),
                textInput("course_id_in",    "Course Code"),
                textInput("course_title_in", "Title"),
                actionButton(
                  "course_submit", "Add Course",
                  class = "btn-primary btn-block",
                  icon  = icon("plus")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title  = "Course Catalog",
                width  = 12,
                status = "primary",
                solidHeader = TRUE,
                DT::dataTableOutput("admin_courses_table")
              )
            )
          )
        ),

        # ── CLASS & SECTIONS ──────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_classes",
          h2("Classroom Assignment"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Assign Class"),
                uiOutput("class_course_selector"),
                uiOutput("class_lecturer_selector"),
                textInput("class_id_in", "Class / Section ID"),
                actionButton(
                  "class_submit", "Assign Class",
                  class = "btn-primary btn-block",
                  icon  = icon("chalkboard")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title  = "Class & Section Assignments",
                width  = 12,
                status = "primary",
                solidHeader = TRUE,
                DT::dataTableOutput("admin_classes_table")
              )
            )
          )
        ),

        # ── ENROLLMENT MANAGEMENT (NEW) ───────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_enrollment",
          h2("Enrollment Management"),
          p(
            "Enroll students into class sections.",
            tags$strong("Only enrolled students are tracked by the AI camera.")
          ),
          fluidRow(
            column(4,
              wellPanel(
                h4("Enroll Student"),
                uiOutput("enroll_class_selector"),
                uiOutput("enroll_student_selector"),
                actionButton(
                  "enroll_submit", "Enroll Student",
                  class = "btn-success btn-block",
                  icon  = icon("plus")
                ),
                hr(),
                h4("Bulk Enroll"),
                p("Paste comma-separated student IDs:"),
                textAreaInput(
                  "bulk_enroll_ids", label = NULL,
                  rows        = 4,
                  placeholder = "231006367, 231006368..."
                ),
                uiOutput("bulk_enroll_class_selector"),
                actionButton(
                  "bulk_enroll_submit", "Bulk Enroll",
                  class = "btn-primary btn-block",
                  icon  = icon("users")
                )
              )
            ),
            column(8,
              shinydashboard::box(
                title      = "Current Enrollments",
                width      = 12,
                status     = "primary",
                solidHeader = TRUE,
                actionButton(
                  "enroll_refresh_btn", "Refresh",
                  class = "btn-sm btn-default",
                  icon  = icon("refresh")
                ),
                br(), br(),
                DT::dataTableOutput("admin_enrollment_table"),
                br(),
                actionButton(
                  "enroll_delete_btn", "Remove Selected",
                  class = "btn-danger btn-sm",
                  icon  = icon("trash")
                )
              )
            )
          )
        ),

        # ── ENGAGEMENT LOG ────────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_engagement",
          h2("Global Engagement Trends"),
          plotly::plotlyOutput("admin_confidence_trend")
        ),

        # ── EMOTION ANALYSIS ──────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_emotions",
          h2("System-wide Emotion Mix"),
          plotOutput("admin_emotion_dist")
        ),

        # ── INCIDENT AUDIT ────────────────────────────────────────────────────
        shinydashboard::tabItem(
          tabName = "admin_incidents",
          h2("Proctoring & Audit Logs"),
          DT::dataTableOutput("admin_incidents_table")
        )

      ) # end tabItems
    )   # end dashboardBody
  )     # end dashboardPage
}
