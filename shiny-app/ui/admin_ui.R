# ui/admin_ui.R — Admin role: 8 analytics panels
#
# Called by app.R inside htmlTemplate() slot rendering.
# Reads data exclusively from nightly CSV exports (see global.R).
# Panel ordering follows CLAUDE.md §12.1.

admin_ui <- function() {
  tagList(
    useShinyjs(),
    useShinyalert(),

    navbarPage(
      title    = NULL,   # title is rendered in the HTML template's <nav>
      id       = "admin_tabs",
      windowTitle = "AAST — Admin Analytics",

      # ── Panel 1: Attendance Overview ────────────────────────────────────────
      tabPanel(
        title = tagList(icon("check-circle"), "Attendance"),
        value = "admin_attendance",
        div(class = "aast-card",
          div(class = "aast-card-header", "Attendance Overview"),
          div(class = "aast-card-body",
            fluidRow(
              column(3, selectInput("att_dept",  "Department:", choices = NULL)),
              column(3, dateRangeInput("att_dates", "Date Range:",
                                       start = Sys.Date() - 30, end = Sys.Date())),
              column(2, br(), downloadButton("att_xlsx", "Export .xlsx",
                                              class = "btn-aast-primary"))
            ),
            DT::dataTableOutput("admin_attendance_dt")
          )
        )
      ),

      # ── Panel 2: Engagement Trend ────────────────────────────────────────────
      tabPanel(
        title = tagList(icon("chart-line"), "Engagement Trend"),
        value = "admin_trend",
        div(class = "aast-card",
          div(class = "aast-card-header", "Weekly Engagement Trend by Department"),
          div(class = "aast-card-body",
            plotly::plotlyOutput("admin_trend_plot", height = "400px")
          )
        )
      ),

      # ── Panel 3: Dept Engagement Heatmap ────────────────────────────────────
      tabPanel(
        title = tagList(icon("th"), "Heatmap"),
        value = "admin_heatmap",
        div(class = "aast-card",
          div(class = "aast-card-header", "Department × Week Engagement Heatmap"),
          div(class = "aast-card-body",
            plotOutput("admin_heatmap_plot", height = "400px")
          )
        )
      ),

      # ── Panel 4: At-Risk Cohort ──────────────────────────────────────────────
      tabPanel(
        title = tagList(icon("exclamation-triangle"), "At-Risk"),
        value = "admin_atrisk",
        div(class = "aast-card",
          div(class = "aast-card-header",
              "At-Risk Students (>20% engagement drop over 3 consecutive lectures)"),
          div(class = "aast-card-body",
            DT::dataTableOutput("admin_atrisk_dt")
          )
        )
      ),

      # ── Panel 5: Lecture Effectiveness Score (LES) ──────────────────────────
      tabPanel(
        title = tagList(icon("star"), "LES"),
        value = "admin_les",
        div(class = "aast-card",
          div(class = "aast-card-header",
              "Lecture Effectiveness Score  (LES = 0.5×engagement + 0.3×(1−confusion) + 0.2×attendance)"),
          div(class = "aast-card-body",
            DT::dataTableOutput("admin_les_dt")
          )
        )
      ),

      # ── Panel 6: Emotion Distribution ───────────────────────────────────────
      tabPanel(
        title = tagList(icon("smile"), "Emotions"),
        value = "admin_emotions",
        div(class = "aast-card",
          div(class = "aast-card-header", "Emotion Distribution by Department (normalised)"),
          div(class = "aast-card-body",
            plotOutput("admin_emotion_dist_plot", height = "450px")
          )
        )
      ),

      # ── Panel 7: Lecturer Cluster Map ───────────────────────────────────────
      tabPanel(
        title = tagList(icon("users"), "Cluster Map"),
        value = "admin_clusters",
        div(class = "aast-card",
          div(class = "aast-card-header", "Lecturer Cluster Map (K-means, k=3)"),
          div(class = "aast-card-body",
            plotly::plotlyOutput("admin_cluster_plot", height = "450px")
          )
        )
      ),

      # ── Panel 8: Time-of-Day Heatmap ────────────────────────────────────────
      tabPanel(
        title = tagList(icon("clock"), "Time of Day"),
        value = "admin_timeofday",
        div(class = "aast-card",
          div(class = "aast-card-header", "Time-of-Day Engagement Heatmap (weekday × hour slot)"),
          div(class = "aast-card-body",
            plotOutput("admin_tod_plot", height = "450px")
          )
        )
      )
    )
  )
}
