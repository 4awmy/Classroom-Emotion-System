# ui/lecturer_ui.R — Lecturer role: 5 submodules
#
# Submodules follow CLAUDE.md §12.2:
#   A — Roster Setup
#   B — Material Upload
#   C — Attendance
#   D — Live Lecture Dashboard (7 live panels)
#   E — Student Reports

lecturer_ui <- function() {
  tagList(
    useShinyjs(),
    useShinyalert(),

    navbarPage(
      title       = NULL,
      id          = "lecturer_tabs",
      windowTitle = "AAST — Lecturer Portal",

      # ── Submodule A: Roster Setup ────────────────────────────────────────────
      tabPanel(
        title = tagList(icon("users-cog"), "Roster Setup"),
        value = "lec_roster",
        div(class = "aast-card",
          div(class = "aast-card-header", "A — Roster Setup"),
          div(class = "aast-card-body",
            p("Upload the", strong("StudentPicsDataset.xlsx"), "file. The system will:",
              tags$ul(
                tags$li("Create student records (student_id, name, email)"),
                tags$li("Download each student's photo from Google Drive"),
                tags$li("Generate a 128-dim face encoding and store it in the database")
              )
            ),
            fileInput("roster_xlsx", "Choose XLSX File:",
                      accept = c(".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")),
            withSpinner(
              actionButton("roster_upload_btn", "Upload & Encode",
                           class = "btn-aast-primary", icon = icon("upload")),
              type = 4, color = "#002147"
            ),
            hr(),
            uiOutput("roster_result_ui")
          )
        )
      ),

      # ── Submodule B: Material Upload ─────────────────────────────────────────
      tabPanel(
        title = tagList(icon("file-upload"), "Materials"),
        value = "lec_materials",
        div(class = "aast-card",
          div(class = "aast-card-header", "B — Lecture Material Upload"),
          div(class = "aast-card-body",
            fluidRow(
              column(4, selectInput("mat_lecture_id", "Lecture:", choices = NULL)),
              column(4, textInput("mat_title", "Title:", placeholder = "e.g. Week 3 Slides"))
            ),
            fileInput("mat_file", "Choose File (PDF / PPTX):",
                      accept = c(".pdf", ".pptx")),
            actionButton("mat_upload_btn", "Upload to Drive",
                         class = "btn-aast-primary", icon = icon("cloud-upload-alt")),
            hr(),
            h5("Uploaded Materials"),
            DT::dataTableOutput("materials_dt")
          )
        )
      ),

      # ── Submodule C: Attendance ──────────────────────────────────────────────
      tabPanel(
        title = tagList(icon("clipboard-check"), "Attendance"),
        value = "lec_attendance",
        div(class = "aast-card",
          div(class = "aast-card-header", "C — Attendance"),
          div(class = "aast-card-body",
            tabsetPanel(
              id = "att_mode_tabs",

              # Manual entry
              tabPanel("Manual Entry",
                br(),
                selectInput("att_lecture_id", "Lecture:", choices = NULL),
                p(em("Edit the Status column directly in the table below, then click Save.")),
                DT::dataTableOutput("manual_attendance_dt"),
                br(),
                actionButton("save_manual_att", "Save Changes",
                             class = "btn-aast-primary", icon = icon("save"))
              ),

              # AI auto-attendance
              tabPanel("AI Auto-Detect",
                br(),
                selectInput("ai_att_lecture_id", "Lecture:", choices = NULL),
                actionButton("start_ai_att", "Start AI Attendance",
                             class = "btn-aast-gold", icon = icon("camera")),
                verbatimTextOutput("ai_att_status")
              ),

              # QR code fallback
              tabPanel("QR Code",
                br(),
                selectInput("qr_lecture_id", "Lecture:", choices = NULL),
                actionButton("gen_qr_btn", "Generate QR Code",
                             class = "btn-aast-primary", icon = icon("qrcode")),
                imageOutput("qr_image", height = "250px")
              )
            )
          )
        )
      ),

      # ── Submodule D: Live Lecture Dashboard ──────────────────────────────────
      tabPanel(
        title = tagList(icon("broadcast-tower"), "Live Dashboard"),
        value = "lec_live",
        div(class = "aast-card",
          div(class = "aast-card-header",
            fluidRow(
              column(6, "D — Live Lecture Dashboard"),
              column(3, selectInput("live_lecture_id", NULL, choices = NULL)),
              column(3, align = "right",
                actionButton("start_session_btn", "Start Lecture",
                             class = "btn-aast-gold btn-sm", icon = icon("play")),
                actionButton("end_session_btn",   "End Lecture",
                             class = "btn btn-danger btn-sm", icon = icon("stop"))
              )
            )
          ),
          div(class = "aast-card-body",
            # D1: Engagement Gauge
            fluidRow(
              column(4,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D1 — Engagement Gauge"),
                  div(class = "aast-card-body",
                    plotly::plotlyOutput("live_gauge", height = "250px")
                  )
                )
              ),
              # D3: Cognitive Load
              column(4,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D3 — Cognitive Load"),
                  div(class = "aast-card-body",
                    valueBoxOutput("live_cog_load_box", width = 12)
                  )
                )
              ),
              # D4: Class Valence
              column(4,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D4 — Class Valence"),
                  div(class = "aast-card-body",
                    plotly::plotlyOutput("live_valence_gauge", height = "250px")
                  )
                )
              )
            ),

            # D2: Real-Time Emotion Timeline
            fluidRow(
              column(12,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D2 — Real-Time Emotion Timeline (last 30 min)"),
                  div(class = "aast-card-body",
                    plotly::plotlyOutput("live_timeline_plot", height = "300px")
                  )
                )
              )
            ),

            # D5: Per-Student Heatmap + D6: Struggle Alert
            fluidRow(
              column(6,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D5 — Per-Student Emotion Heatmap"),
                  div(class = "aast-card-body",
                    plotOutput("live_student_heatmap", height = "350px")
                  )
                )
              ),
              column(6,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D6 — Persistent Struggle Alerts"),
                  div(class = "aast-card-body",
                    DT::dataTableOutput("live_struggle_dt")
                  )
                )
              )
            ),

            # D7: Peak Confusion Moment
            fluidRow(
              column(12,
                div(class = "aast-card",
                  div(class = "aast-card-header", "D7 — Peak Confusion Moment"),
                  div(class = "aast-card-body",
                    valueBoxOutput("live_peak_confusion_box", width = 12)
                  )
                )
              )
            )
          )
        )
      ),

      # ── Submodule E: Student Reports ─────────────────────────────────────────
      tabPanel(
        title = tagList(icon("file-alt"), "Reports"),
        value = "lec_reports",
        div(class = "aast-card",
          div(class = "aast-card-header", "E — Per-Student Reports"),
          div(class = "aast-card-body",
            fluidRow(
              column(4, selectInput("report_student_id", "Select Student:", choices = NULL)),
              column(3, br(),
                downloadButton("download_report_pdf", "Download PDF",
                               class = "btn-aast-primary")
              )
            ),
            hr(),
            fluidRow(
              column(6, plotly::plotlyOutput("report_engagement_trend", height = "250px")),
              column(6, plotly::plotlyOutput("report_cog_load_trend",   height = "250px"))
            ),
            fluidRow(
              column(12,
                h5("AI Intervention Plan"),
                uiOutput("report_plan_md")
              )
            )
          )
        )
      )
    )
  )
}

# ── Spinner helper (wraps actionButton while upload is in progress) ───────────
# Falls back gracefully if shinycssloaders is not installed.
withSpinner <- function(ui, ...) {
  if (requireNamespace("shinycssloaders", quietly = TRUE)) {
    shinycssloaders::withSpinner(ui, ...)
  } else {
    ui
  }
}
