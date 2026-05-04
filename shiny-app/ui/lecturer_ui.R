# Lecturer UI - 5 Submodules
# Submodules: Roster, Materials, Attendance, Live Dashboard, Reports

lecturer_ui <- function() {
  navbarPage(
    title = "AAST LMS - Lecturer Portal",
    theme = bslib::bs_theme(
      version = 5,
      primary = AAST_NAVY,
      secondary = AAST_GOLD
    ),
    # ========================================================================
    # Submodule A: Roster Setup
    # ========================================================================
    tabPanel(
      "Roster Setup",
      br(),
      h2("Student Roster & Face Encoding"),
      p("Upload student roster (CSV) and face images (ZIP) for identity recognition"),
      br(),
      fluidRow(
        column(
          6,
          h3("Upload Roster"),
          fileInput("lecturer_roster_csv", "Select CSV File",
                   accept = c(".csv")),
          helpText("CSV columns: student_id, name, email")
        ),
        column(
          6,
          h3("Upload Face Images"),
          fileInput("lecturer_images_zip", "Select ZIP File",
                   accept = c(".zip")),
          helpText("ZIP contains images named: {student_id}.jpg")
        )
      ),
      br(),
      actionButton("lecturer_roster_upload", "Upload Roster", class = "btn-primary"),
      br(), br(),
      uiOutput("lecturer_roster_status"),
      br(),
      h3("Upload Progress"),
      progressBar("lecturer_roster_progress", 0, "0%")
    ),
    # ========================================================================
    # Submodule B: Material Upload
    # ========================================================================
    tabPanel(
      "Material Upload",
      br(),
      h2("Lecture Materials Management"),
      br(),
      fluidRow(
        column(
          4,
          selectInput("lecturer_lecture_select", "Select Lecture:",
                     choices = c("Loading..." = ""))
        ),
        column(
          8,
          textInput("lecturer_material_title", "Material Title")
        )
      ),
      br(),
      fileInput("lecturer_material_file", "Select File (PDF, PPT, etc.)",
               accept = c(".pdf", ".pptx", ".xlsx", ".docx")),
      br(),
      actionButton("lecturer_material_upload", "Upload Material", class = "btn-primary"),
      br(), br(),
      h3("Recent Materials"),
      DT::dataTableOutput("lecturer_materials_table")
    ),
    # ========================================================================
    # Submodule C: Attendance
    # ========================================================================
    tabPanel(
      "Attendance",
      br(),
      h2("Class Attendance Management"),
      br(),
      tabsetPanel(
        tabPanel(
          "Manual Entry",
          br(),
          actionButton("lecturer_attendance_edit", "Edit Attendance", class = "btn-warning"),
          br(), br(),
          DT::dataTableOutput("lecturer_attendance_table"),
          br(),
          actionButton("lecturer_attendance_save", "Save Changes", class = "btn-success")
        ),
        tabPanel(
          "AI Mode",
          br(),
          p("Automatically detect attendance using vision pipeline"),
          actionButton("lecturer_attendance_start", "Start AI Detection", class = "btn-primary"),
          br(), br(),
          uiOutput("lecturer_ai_attendance_status")
        ),
        tabPanel(
          "QR Code",
          br(),
          p("Generate QR code for students to scan"),
          actionButton("lecturer_qr_generate", "Generate QR Code", class = "btn-primary"),
          br(), br(),
          imageOutput("lecturer_qr_image")
        )
      )
    ),
    # ========================================================================
    # Submodule D: Live Lecture Dashboard (D1-D7 panels)
    # ========================================================================
    tabPanel(
      "Live Dashboard",
      br(),
      h2("Live Class Monitoring"),
      actionButton("lecturer_live_start", "Start Lecture", class = "btn-success"),
      actionButton("lecturer_live_end", "End Lecture", class = "btn-danger"),
      br(), br(),
      # D1: Engagement Gauge
      fluidRow(
        column(
          3,
          h3("D1: Engagement Gauge"),
          plotly::plotlyOutput("lecturer_d1_gauge")
        ),
        # D2: Emotion Timeline
        column(
          9,
          h3("D2: Emotion Timeline"),
          plotly::plotlyOutput("lecturer_d2_timeline")
        )
      ),
      hr(),
      # D3: Cognitive Load
      fluidRow(
        column(
          4,
          h3("D3: Cognitive Load"),
          uiOutput("lecturer_d3_load")
        ),
        # D4: Class Valence
        column(
          4,
          h3("D4: Class Valence"),
          plotly::plotlyOutput("lecturer_d4_valence")
        ),
        # D7: Peak Confusion
        column(
          4,
          h3("D7: Peak Confusion"),
          uiOutput("lecturer_d7_peak")
        )
      ),
      hr(),
      # D5: Per-Student Heatmap
      fluidRow(
        column(
          12,
          h3("D5: Per-Student Emotion Heatmap"),
          plotly::plotlyOutput("lecturer_d5_heatmap", height = "400px")
        )
      ),
      hr(),
      # D6: Persistent Struggle Alert
      fluidRow(
        column(
          12,
          h3("D6: Persistent Struggle Alerts"),
          DT::dataTableOutput("lecturer_d6_struggle")
        )
      )
    ),
    # ========================================================================
    # Submodule E: Student Reports
    # ========================================================================
    tabPanel(
      "Student Reports",
      br(),
      h2("Individual Student Performance Reports"),
      br(),
      fluidRow(
        column(
          4,
          selectInput("lecturer_student_select", "Select Student:",
                     choices = c("Loading..." = ""))
        ),
        column(
          4,
          downloadButton("lecturer_student_pdf", "Download PDF Report")
        )
      ),
      br(),
      tabsetPanel(
        tabPanel(
          "Dashboard",
          br(),
          fluidRow(
            column(
              6,
              h3("Engagement Trend"),
              plotly::plotlyOutput("lecturer_student_trend")
            ),
            column(
              6,
              h3("Emotion Distribution"),
              plotly::plotlyOutput("lecturer_student_emotions")
            )
          ),
          br(),
          fluidRow(
            column(
              12,
              h3("Cognitive Load Timeline"),
              plotly::plotlyOutput("lecturer_student_load")
            )
          )
        ),
        tabPanel(
          "AI Plan",
          br(),
          h3("AI Intervention Plan"),
          uiOutput("lecturer_student_plan_ui")
        )
      )
    )
  )
}
