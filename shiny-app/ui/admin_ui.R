# Admin UI - Consolidated User & Course Management

admin_ui <- function() {
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
      id = "admin_sidebar",
      shinydashboard::sidebarMenu(
        id = "admin_menu",
        shinydashboard::menuItem("Overview", tabName = "admin_attendance", icon = icon("chart-bar")),
        
        tags$li(class = "header", "USER MANAGEMENT (ROSTER)"),
        shinydashboard::menuItem("Manage Admins", tabName = "admin_manage_admins", icon = icon("user-shield")),
        shinydashboard::menuItem("Manage Lecturers", tabName = "admin_lecturers", icon = icon("chalkboard-teacher")),
        shinydashboard::menuItem("Manage Students", tabName = "admin_students", icon = icon("user-graduate")),
        
        tags$li(class = "header", "ACADEMIC STRUCTURE"),
        shinydashboard::menuItem("Course Manager", tabName = "admin_courses", icon = icon("book")),
        shinydashboard::menuItem("Class & Sections", tabName = "admin_classes", icon = icon("chalkboard")),
        
        tags$li(class = "header", "ANALYTICS"),
        shinydashboard::menuItem("Engagement Log", tabName = "admin_engagement", icon = icon("chart-line")),
        shinydashboard::menuItem("Emotion Analysis", tabName = "admin_emotions", icon = icon("smile")),
        shinydashboard::menuItem("Incident Audit", tabName = "admin_incidents", icon = icon("shield-alt"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(

        # --- ADMIN MANAGEMENT ---
        shinydashboard::tabItem(tabName = "admin_manage_admins",
          h2("Administrator Roster"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add/Edit Admin"),
                textInput("adm_id_in", "Admin User ID"),
                textInput("adm_name_in", "Full Name"),
                textInput("adm_email_in", "AAST Email"),
                passwordInput("adm_pwd_in", "Password (Default: aast2026)"),
                actionButton("adm_submit", "Save Admin", class="btn-primary btn-block")
              )
            ),
            column(8, 
              shinydashboard::box(title = "System Administrators", width = 12, status = "primary",
                DT::dataTableOutput("admin_list_table")
              )
            )
          )
        ),

        # --- LECTURER MANAGEMENT ---
        shinydashboard::tabItem(tabName = "admin_lecturers",
          h2("Lecturer Roster"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add/Edit Lecturer"),
                textInput("admin_lecturer_id", "Lecturer ID (e.g. abahmed)"),
                textInput("admin_lecturer_name", "Full Name"),
                textInput("admin_lecturer_email", "AAST Email"),
                textInput("admin_lecturer_dept", "Department"),
                passwordInput("admin_lecturer_pwd", "Password"),
                actionButton("admin_lecturer_submit", "Save Lecturer", class="btn-primary btn-block")
              )
            ),
            column(8, 
              shinydashboard::box(title = "Faculty Roster", width = 12, status = "primary",
                DT::dataTableOutput("admin_lecturer_table")
              )
            )
          )
        ),

        # --- STUDENT MANAGEMENT ---
        shinydashboard::tabItem(tabName = "admin_students",
          h2("Student Roster (Master)"),
          fluidRow(
            column(4,
              wellPanel(
                h3("Add/Edit Student"),
                textInput("admin_student_id", "Registration Number"),
                textInput("admin_student_name", "Full Name (English)"),
                textInput("admin_student_email", "Student Email (@aast.com)"),
                selectInput("admin_student_dept", "Department", choices = c("Computing", "Engineering", "Business", "Artificial Intelligence")),
                passwordInput("admin_student_pwd", "Password"),
                fileInput("admin_student_photo", "Face Encoding Photo (v3 Only)", accept = c(".jpg", ".png")),
                actionButton("admin_student_submit", "Save Student", class="btn-primary btn-block"),
                hr(),
                actionButton("admin_student_delete", "Delete Selected", class="btn-danger btn-block")
              )
            ),
            column(8, 
              shinydashboard::box(title = "Full Student Body", width = 12, status = "primary",
                DT::dataTableOutput("admin_student_table")
              )
            )
          )
        ),

        # --- COURSE & CLASS ---
        shinydashboard::tabItem(tabName = "admin_courses",
          h2("Course Catalog"),
          fluidRow(
            column(4,
              wellPanel(
                textInput("course_id_in", "Course Code"),
                textInput("course_title_in", "Title"),
                actionButton("course_submit", "Add Course", class="btn-primary btn-block")
              )
            ),
            column(8, DT::dataTableOutput("admin_courses_table"))
          )
        ),

        shinydashboard::tabItem(tabName = "admin_classes",
          h2("Classroom Assignment"),
          fluidRow(
            column(4,
              wellPanel(
                uiOutput("class_course_selector"),
                uiOutput("class_lecturer_selector"),
                textInput("class_id_in", "Class/Section ID"),
                actionButton("class_submit", "Assign Class", class="btn-primary btn-block")
              )
            ),
            column(8, DT::dataTableOutput("admin_classes_table"))
          )
        ),

        # --- ANALYTICS ---
        shinydashboard::tabItem(tabName = "admin_attendance", h2("Engagement Overview"), DT::dataTableOutput("admin_attendance_table")),
        shinydashboard::tabItem(tabName = "admin_engagement", h2("Global Engagement Trends"), plotly::plotlyOutput("admin_confidence_trend")),
        shinydashboard::tabItem(tabName = "admin_emotions", h2("System-wide Emotion Mix"), plotOutput("admin_emotion_dist")),
        shinydashboard::tabItem(tabName = "admin_incidents", h2("Proctoring & Audit Logs"), DT::dataTableOutput("admin_incidents_table"))
      )
    )
  )
}
