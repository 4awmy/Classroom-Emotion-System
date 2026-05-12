# Lecturer UI - Overhauled v3.6.0 (Dashboard Focused)

# Helper: Navigation Actions
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

# Main Course Table
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
        tags$th("Attendance History"),
        tags$th("Live Dashboard")
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
          tags$td(lecturer_course_click_button(i, "reports", "chart-bar")),
          tags$td(lecturer_course_click_button(i, "live", "play-circle"))
        )
      })
    )
  )
}

lecturer_ui <- function() {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(
      title = tags$a(
        href = "#",
        tags$img(
          src    = "aast-logo-wide.png",
          height = "38px",
          style  = "margin-top: -2px; filter: brightness(0) invert(1);"
        )
      ),
      titleWidth = 280,
      tags$li(
        class = "dropdown",
        actionLink(
          "logout_btn",
          label = tagList(icon("sign-out-alt"), " Logout"),
          style = "color: #C9A84C; padding: 15px 20px; font-weight: 500;"
        )
      )
    ),

    shinydashboard::dashboardSidebar(
      width = 260,
      shinydashboard::sidebarMenu(
        id = "lecturer_menu",
        shinydashboard::menuItem("My Classes",        tabName = "lec_roster",   icon = icon("house")),
        shinydashboard::menuItem("Live Dashboard",    tabName = "lec_live",     icon = icon("play-circle")),
        shinydashboard::menuItem("Exam Proctoring",   tabName = "lec_exam",     icon = icon("shield-alt")),
        shinydashboard::menuItem("Reports & Analytics", tabName = "lec_reports", icon = icon("chart-bar")),
        shinydashboard::menuItem("LMS Materials",     tabName = "lec_materials", icon = icon("file-upload"))
      )
    ),
    shinydashboard::dashboardBody(
      tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
        tags$style("
          .student-card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 15px; padding: 10px; }
          .student-card { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); overflow: hidden; text-align: center; border-bottom: 4px solid #ccc; transition: all 0.3s; }
          .student-card.present { border-bottom-color: #28a745; }
          .student-card.absent { border-bottom-color: #dc3545; }
          .student-img { width: 100%; height: 150px; object-fit: cover; background: #eee; }
          .student-name { font-size: 0.9em; font-weight: bold; padding: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
          .student-status { font-size: 0.7em; color: #666; padding-bottom: 5px; }
          .live-2-col { display: flex; gap: 20px; }
          .live-left { flex: 2; }
          .live-right { flex: 1; }
        "),
        tags$script(HTML("
          // Tab navigation for dynamically rendered shinydashboard
          Shiny.addCustomMessageHandler('setTab', function(tab) {
            var el = document.querySelector('[data-value=\"' + tab + '\"]');
            if (el) el.click();
          });

          // Camera state — defined once at page load, never re-initialised by renderUI
          var _liveCamStream = null;
          var _liveCamTimer  = null;
          var _liveCamActive = false;

          function startLiveCam() {
            if (_liveCamStream) return;
            navigator.mediaDevices.getUserMedia({ video: { width:640, height:480 } })
              .then(function(s) {
                _liveCamStream = s;
                var v = document.getElementById('liveDashCam');
                if (v) v.srcObject = s;
              })
              .catch(function(e) { alert('Camera error: ' + e.message); });
          }

          function toggleLiveCamAuto() {
            _liveCamActive = !_liveCamActive;
            var btn = document.getElementById('liveCamAutoBtn');
            if (_liveCamActive) {
              if (btn) { btn.className = 'btn btn-success btn-sm'; btn.innerHTML = '<i class=\"fa fa-stop\"></i> Stop Capture'; }
              captureLiveFrame();
              _liveCamTimer = setInterval(captureLiveFrame, 5000);
            } else {
              if (btn) { btn.className = 'btn btn-danger btn-sm'; btn.innerHTML = '<i class=\"fa fa-circle\"></i> Auto-Capture (every 5s)'; }
              clearInterval(_liveCamTimer);
              var ov = document.getElementById('liveDashOverlay');
              if (ov) ov.getContext('2d').clearRect(0, 0, ov.width, ov.height);
            }
          }

          function captureLiveFrame() {
            var v = document.getElementById('liveDashCam');
            if (!v || !v.srcObject || !v.videoWidth) return;
            var c = document.getElementById('liveDashCanvas');
            if (!c) return;
            c.width  = v.videoWidth;
            c.height = v.videoHeight;
            c.getContext('2d').drawImage(v, 0, 0);
            Shiny.setInputValue('live_cam_frame', c.toDataURL('image/jpeg', 0.85), { priority:'event' });
          }

          window.drawFaceBoxes = function(data) {
            var ov = document.getElementById('liveDashOverlay');
            if (!ov) return;
            var fw = data.frame_width  || 640;
            var fh = data.frame_height || 480;
            ov.width  = fw; ov.height = fh;
            var ctx = ov.getContext('2d');
            ctx.clearRect(0, 0, fw, fh);
            (data.detected || []).forEach(function(d) {
              if (!d.bbox) return;
              var b = d.bbox;
              var col = d.enrolled === true ? '#00e676' : d.enrolled === false ? '#ff9100' : '#ffff00';
              ctx.strokeStyle = col; ctx.lineWidth = 3;
              ctx.strokeRect(b.x, b.y, b.w, b.h);
              var lbl = (d.name || 'Unknown') + (d.emotion ? ' [' + d.emotion + ']' : '');
              ctx.font = 'bold 13px Arial';
              var tw = ctx.measureText(lbl).width;
              ctx.fillStyle = 'rgba(0,0,0,0.65)';
              ctx.fillRect(b.x, b.y - 22, tw + 8, 22);
              ctx.fillStyle = col;
              ctx.fillText(lbl, b.x + 4, b.y - 6);
            });
          };

          if (!window._faceBoxHandlerOK) {
            window._faceBoxHandlerOK = true;
            Shiny.addCustomMessageHandler('drawFaceBoxes', function(data) {
              window.drawFaceBoxes(data);
            });
          }
        "))
      ),
      shinydashboard::tabItems(

        # --- HOME: MY CLASSES ---
        shinydashboard::tabItem(tabName = "lec_roster",
          div(
            class = "reference-page-card",
            h2("My Active Courses"),
            uiOutput("lecturer_course_table"),
            hr(),

            # DEBUG PANEL
            shinydashboard::box(title = "System Debug Info", width = 12, collapsible = TRUE, collapsed = TRUE, status = "danger",
              verbatimTextOutput("lecturer_debug_out")
            )
          )
        ),

        # --- LIVE LECTURE DASHBOARD (2-COLUMN) ---
        shinydashboard::tabItem(tabName = "lec_live",
          h2("Live Session Command Center"),

          # Step 1: Selector Bar
          wellPanel(
            fluidRow(
              column(3, uiOutput("lec_live_course_selector")),
              column(3, uiOutput("lec_live_class_selector")),
              column(3, uiOutput("lec_live_week_selector")),
              column(3, uiOutput("lec_live_session_info"))
            )
          ),

          div(class = "live-2-col",
            # Column 1: Video & Student Grid
            div(class = "live-left",
              shinydashboard::box(title = "Live AI Video Stream", width = 12, status = "primary", solidHeader = TRUE,
                uiOutput("lecturer_live_stream_ui"),
                footer = uiOutput("lecturer_live_session_actions")
              ),
              shinydashboard::box(title = "Live Attendance Grid (Snapshot Sync)", width = 12, status = "info",
                uiOutput("lecturer_attendance_grid")
              )
            ),

            # Column 2: Analytics & Ticker
            div(class = "live-right",
              shinydashboard::box(title = "Class Engagement", width = 12, status = "warning", solidHeader = TRUE,
                plotly::plotlyOutput("lecturer_d1_gauge", height = "250px")
              ),
              uiOutput("lecturer_live_qr_panel"),
              shinydashboard::box(title = "Live Sentiment Ticker", width = 12, status = "primary",
                uiOutput("lecturer_live_sentiment_ticker")
              ),
              shinydashboard::box(title = "AI Interventions", width = 12, status = "danger",
                actionButton("lecturer_trigger_refresher",
                             tagList(icon("robot"), " Ask AI (from materials)"),
                             class = "btn-info btn-block"),
                hr(),
                uiOutput("lecturer_confusion_alert_ui")
              )
            )
          )
        ),

        # --- EXAM PROCTORING (dedicated tab) ---
        shinydashboard::tabItem(tabName = "lec_exam",
          div(class = "exam-page-header",
            tags$div(class = "exam-header-inner",
              tags$div(
                icon("shield-alt", class = "exam-header-icon"),
                h2("Exam Proctoring Center")
              ),
              uiOutput("exam_status_badge")
            )
          ),

          # ── Setup Panel ──
          shinydashboard::box(
            title = tagList(icon("cog"), " Exam Setup"),
            width = 12, status = "primary",
            fluidRow(
              column(4, uiOutput("lec_exam_course_selector")),
              column(4, uiOutput("lec_exam_class_selector")),
              column(4,
                textInput("exam_title_input", "Exam Title", placeholder = "e.g. Midterm Exam")
              )
            ),
            fluidRow(
              column(4, br(), uiOutput("exam_start_stop_btn")),
              column(8,
                br(),
                tags$p(class = "help-block",
                  icon("info-circle"), " Start the exam to activate live proctoring. The AI will flag suspicious behaviour automatically."
                )
              )
            )
          ),

          # ── Incident Summary Cards ──
          fluidRow(
            column(3, shinydashboard::valueBoxOutput("exam_box_total",  width = 12)),
            column(3, shinydashboard::valueBoxOutput("exam_box_high",   width = 12)),
            column(3, shinydashboard::valueBoxOutput("exam_box_medium", width = 12)),
            column(3, shinydashboard::valueBoxOutput("exam_box_low",    width = 12))
          ),

          # ── Live Incident Log ──
          shinydashboard::box(
            title = tagList(icon("list-alt"), " Live Incident Log"),
            width = 12, status = "danger",
            DT::dataTableOutput("exam_incidents_table")
          )
        ),

        # --- REPORTS & ANALYTICS (2X2 GRID) ---
        shinydashboard::tabItem(tabName = "lec_reports",
          h2("Lecture Insights & Session History"),
          wellPanel(
            fluidRow(
              column(4, uiOutput("lec_report_course_selector")),
              column(4, uiOutput("lec_report_class_selector")),
              column(4, uiOutput("lec_report_session_selector"))
            )
          ),

          fluidRow(
            column(6, shinydashboard::box(title = "Emotion Frequency", width = 12, status = "primary", solidHeader = TRUE, plotly::plotlyOutput("lec_report_emotion_pie"))),
            column(6, shinydashboard::box(title = "Engagement Timeline", width = 12, status = "info", solidHeader = TRUE, plotly::plotlyOutput("lec_report_engagement_line")))
          ),
          fluidRow(
            column(6, shinydashboard::box(title = "Attendance Summary", width = 12, status = "success", solidHeader = TRUE, DT::dataTableOutput("lec_report_attendance_table"))),
            column(6, shinydashboard::box(title = "Student Performance Clusters", width = 12, status = "warning", solidHeader = TRUE, plotly::plotlyOutput("lec_report_student_clusters")))
          ),

          tags$hr(),
          h4("Cross-Session Analytics (All Sessions for Selected Class)"),

          fluidRow(
            shinydashboard::box(
              title = "Engagement Trend Across Sessions", width = 12,
              status = "primary", solidHeader = TRUE,
              plotly::plotlyOutput("lec_report_cross_session_trend", height = "280px")
            )
          ),
          fluidRow(
            column(6, shinydashboard::box(
              title = "Emotion Variation Across Sessions", width = 12,
              status = "warning", solidHeader = TRUE,
              plotly::plotlyOutput("lec_report_emotion_variation_sessions", height = "300px")
            )),
            column(6, shinydashboard::box(
              title = "Per-Student Summary (All Sessions)", width = 12,
              status = "success", solidHeader = TRUE,
              DT::dataTableOutput("lec_report_student_summary")
            ))
          )
        ),

        # --- MATERIALS ---
        shinydashboard::tabItem(tabName = "lec_materials",
          h2("LMS Content Management"),
          wellPanel(
            fluidRow(
              column(4, uiOutput("lec_mat_course_selector")),
              column(4, uiOutput("lec_mat_class_selector")),
              column(4, selectInput("lecturer_material_week", "Academic Week",
                                    choices = setNames(1:16, paste("Week", 1:16)), selected = 1))
            ),
            fluidRow(
              column(8, fileInput("lecturer_material_file", "Upload Slides (PDF)",
                                  accept = c(".pdf"))),
              column(4, br(), actionButton("lecturer_material_upload", "Upload & Process",
                                           class = "btn-primary btn-block"))
            )
          ),
          shinydashboard::box(title = "Weekly Content", width = 12, status = "primary",
            DT::dataTableOutput("lecturer_materials_table")
          )
        )
      )
    )
  )
}
