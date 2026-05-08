# Lecturer UI - 5 Submodules (shinydashboard sidebar layout)

lecturer_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",  # overridden by custom.css
    shinydashboard::dashboardHeader(
      title = tags$span(
        tags$strong("AAST LMS"),
        tags$small(" | المحاضر", style = "font-size:0.8em; margin-right:4px;")
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
        shinydashboard::menuItem(
          "إعداد القائمة / Roster",
          tabName = "lec_roster",
          icon = icon("upload")
        ),
        shinydashboard::menuItem(
          "المواد التعليمية / Materials",
          tabName = "lec_materials",
          icon = icon("book")
        ),
        shinydashboard::menuItem(
          "الحضور / Attendance",
          tabName = "lec_attendance",
          icon = icon("check-square")
        ),
        shinydashboard::menuItem(
          "اللوحة المباشرة / Live Dashboard",
          tabName = "lec_live",
          icon = icon("tv"),
          badgeLabel = "LIVE",
          badgeColor = "green"
        ),
        shinydashboard::menuItem(
          "تقارير الطلاب / Reports",
          tabName = "lec_reports",
          icon = icon("file-alt")
        )
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap"),
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
      ),
      shinydashboard::tabItems(

        # ====================================================================
        # Submodule A: Roster Setup
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_roster",
          h2("Student Roster Setup / إعداد قائمة الطلاب"),
          p("Upload the student roster XLSX file. Face images are fetched automatically from Google Drive links."),
          br(),
          wellPanel(
            fileInput("lecturer_roster_xlsx", "Select Roster XLSX File / اختر ملف القائمة",
                     accept = c(".xlsx")),
            helpText("Expected columns: student_id, name, email, photo_link"),
            br(),
            actionButton("lecturer_roster_upload", "Upload Roster / تحميل القائمة",
                        class = "btn-primary", icon = icon("upload"))
          ),
          br(),
          uiOutput("lecturer_roster_status")
        ),

        # ====================================================================
        # Submodule B: Material Upload
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_materials",
          h2("Lecture Materials / المواد التعليمية"),
          br(),
          wellPanel(
            fluidRow(
              column(6,
                textInput("lecturer_lecture_select", "Lecture ID", placeholder = "e.g. L1")
              ),
              column(6,
                textInput("lecturer_material_title", "Material Title / عنوان المادة")
              )
            ),
            fileInput("lecturer_material_file", "Select File (PDF, PPT, etc.)",
                     accept = c(".pdf", ".pptx", ".xlsx", ".docx")),
            actionButton("lecturer_material_upload", "Upload Material / تحميل المادة",
                        class = "btn-primary", icon = icon("upload"))
          ),
          br(),
          h3("Recent Materials / المواد الأخيرة"),
          DT::dataTableOutput("lecturer_materials_table")
        ),

        # ====================================================================
        # Submodule C: Attendance
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_attendance",
          h2("Class Attendance / الحضور"),
          p("Verify student presence with visual proof from the vision pipeline."),
          br(),
          fluidRow(
            column(4,
              textInput("lecturer_attendance_lecture", "Lecture ID / رقم المحاضرة",
                       placeholder = "e.g. L1")
            ),
            column(4,
              br(),
              actionButton("lecturer_attendance_refresh", "Refresh / تحديث",
                          class = "btn-info", icon = icon("sync"))
            ),
            column(4,
              br(),
              actionButton("lecturer_attendance_save", "Save Changes / حفظ",
                          class = "btn-success", icon = icon("save"))
            )
          ),
          br(),
          tabsetPanel(
            tabPanel(
              "Visual Grid / الشبكة المرئية",
              br(),
              uiOutput("lecturer_attendance_grid")
            ),
            tabPanel(
              "QR Code",
              br(),
              p("Generate QR code for student self-check-in."),
              actionButton("lecturer_qr_generate", "Generate QR / إنشاء رمز QR",
                          class = "btn-primary"),
              br(), br(),
              imageOutput("lecturer_qr_image")
            )
          )
        ),

        # ====================================================================
        # Submodule D: Live Lecture Dashboard (D1–D7)
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_live",
          h2("Live Class Monitoring / المراقبة المباشرة"),
          fluidRow(
            column(4,
              textInput("lecturer_live_lecture", "Lecture ID / رقم المحاضرة",
                       placeholder = "e.g. L1")
            ),
            column(4,
              br(),
              actionButton("lecturer_live_start", "Start Lecture / ابدأ المحاضرة",
                          class = "btn-success", icon = icon("play"))
            ),
            column(4,
              br(),
              actionButton("lecturer_live_end", "End Lecture / أنهِ المحاضرة",
                          class = "btn-danger", icon = icon("stop"))
            )
          ),
          br(),
          # D1 + D2 row
          fluidRow(
            shinydashboard::box(
              title = "D1: Engagement Gauge / مقياس التفاعل",
              status = "primary", solidHeader = TRUE, width = 4,
              plotly::plotlyOutput("lecturer_d1_gauge", height = "250px")
            ),
            shinydashboard::box(
              title = "D2: Emotion Timeline / الجدول الزمني للمشاعر",
              status = "primary", solidHeader = TRUE, width = 8,
              plotly::plotlyOutput("lecturer_d2_timeline", height = "250px")
            )
          ),
          # D3 + D4 + D7 row
          fluidRow(
            shinydashboard::box(
              title = "D3: Cognitive Load / الحمل المعرفي",
              status = "warning", solidHeader = TRUE, width = 4,
              uiOutput("lecturer_d3_load")
            ),
            shinydashboard::box(
              title = "D4: Class Valence / التكافؤ العام",
              status = "info", solidHeader = TRUE, width = 4,
              plotly::plotlyOutput("lecturer_d4_valence", height = "200px")
            ),
            shinydashboard::box(
              title = "D7: Peak Confusion / لحظة الارتباك الأعلى",
              status = "danger", solidHeader = TRUE, width = 4,
              uiOutput("lecturer_d7_peak")
            )
          ),
          # D5: Per-Student Heatmap
          fluidRow(
            shinydashboard::box(
              title = "D5: Per-Student Emotion Heatmap / خريطة المشاعر لكل طالب",
              status = "primary", solidHeader = TRUE, width = 12,
              plotOutput("lecturer_d5_heatmap", height = "400px")
            )
          ),
          # D6: Persistent Struggle Alert
          fluidRow(
            shinydashboard::box(
              title = "D6: Persistent Struggle Alerts / تنبيهات الصعوبة المتواصلة",
              status = "danger", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("lecturer_d6_struggle")
            )
          )
        ),

        # ====================================================================
        # Submodule E: Student Reports
        # ====================================================================
        shinydashboard::tabItem(
          tabName = "lec_reports",
          h2("Student Performance Reports / تقارير أداء الطلاب"),
          br(),
          fluidRow(
            column(5,
              selectInput("lecturer_student_select", "Select Student / اختر الطالب:",
                         choices = c("Loading..." = ""))
            ),
            column(4,
              br(),
              downloadButton("lecturer_student_pdf", "Download PDF / تحميل التقرير",
                            class = "btn-primary")
            )
          ),
          br(),
          tabsetPanel(
            tabPanel(
              "Dashboard / لوحة البيانات",
              br(),
              fluidRow(
                column(6,
                  shinydashboard::box(
                    title = "Engagement Trend / اتجاه التفاعل",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_trend")
                  )
                ),
                column(6,
                  shinydashboard::box(
                    title = "Emotion Distribution / توزيع المشاعر",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_emotions")
                  )
                )
              ),
              fluidRow(
                column(12,
                  shinydashboard::box(
                    title = "Cognitive Load Timeline / الجدول الزمني للحمل المعرفي",
                    width = 12,
                    plotly::plotlyOutput("lecturer_student_load")
                  )
                )
              )
            ),
            tabPanel(
              "AI Plan / خطة التدخل",
              br(),
              shinydashboard::box(
                title = "AI Intervention Plan / خطة التدخل الذكي",
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
