# lecturer_server.R - v3.6.0 Production State Machine

lecturer_server <- function(input, output, session, session_state) {
  # Load R modules
  source("modules/engagement_score.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # STATE & REACTIVES
  # ========================================================================
  
  safe_db_get <- function(query) {
    db_url <- get_db_url()
    if (db_url == "") {
      global_db_error("DATABASE_URL MISSING in safe_db_get")
      return(data.frame())
    }
    
    params <- parse_postgres_url(db_url)

    tryCatch({
      if (is.null(params)) {
        con <- dbConnect(RPostgres::Postgres(), dbname = db_url)
      } else {
        con <- dbConnect(RPostgres::Postgres(), 
                         host = params$host,
                         port = params$port,
                         user = params$user,
                         password = params$password,
                         dbname = params$dbname,
                         sslmode = "require")
      }
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      global_db_error("") # Success
      return(res)
    }, error = function(e) { 
      err_msg <- paste("[DB] Query failed:", e$message)
      global_db_error(err_msg)
      return(data.frame()) 
    })
  }

  # Navigation State
  selected_course_id <- reactiveVal(NULL)
  selected_class_id <- reactiveVal(NULL)
  
  # Session State Machine
  # not_started, live, ended
  current_session_status <- reactiveVal("not_started")
  current_lecture_id <- reactiveVal("")
  session_summary_data <- reactiveVal(NULL)

  # 1. Fetch real classes for THIS lecturer
  lecturer_courses_data <- shiny::reactive({
    uid <- session_state$user_id
    if (is.null(uid)) return(data.frame())
    query <- sprintf("SELECT co.title as course, co.course_id as code, cl.class_id as class 
                      FROM classes cl 
                      JOIN courses co ON cl.course_id = co.course_id 
                      WHERE cl.lecturer_id = '%s'", uid)
    safe_db_get(query)
  })

  # Polling Session Status
  shiny::observe({
    req(current_lecture_id() != "")
    shiny::invalidateLater(3000, session)
    
    status_data <- api_call(paste0("/session/status/", current_lecture_id()), auth_token = session_state$token)
    if (!is.null(status_data)) {
      current_session_status(status_data$status)
      if (status_data$status == "ended") {
        session_summary_data(status_data)
      }
    }
  })

  # Live Data Refreshers (Only active when status is 'live')
  live_emotions <- reactive({
    req(current_lecture_id() != "")
    if (current_session_status() == "live") {
      invalidateLater(2000, session)
    }
    safe_db_get(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp DESC", current_lecture_id()))
  })

  live_attendance <- reactive({
    req(current_lecture_id() != "")
    if (current_session_status() == "live") {
      invalidateLater(2000, session)
    }
    query <- sprintf("
      SELECT s.student_id, s.name, s.photo_url, al.status, al.timestamp, al.snapshot_url
      FROM enrollments e
      JOIN students s ON e.student_id = s.student_id
      LEFT JOIN attendance_log al ON s.student_id = al.student_id AND al.lecture_id = '%s'
      WHERE e.class_id = (SELECT class_id FROM lectures WHERE lecture_id = '%s' LIMIT 1)
    ", current_lecture_id(), current_lecture_id())
    safe_db_get(query)
  })

  # ========================================================================
  # ROSTER UPLOAD (Submodule A) — XLSX → Google Drive photos → HOG encodings
  # ========================================================================

  observeEvent(input$roster_upload_btn, {
    req(input$roster_xlsx_file)

    output$roster_upload_result <- renderUI(
      div(class="alert alert-info", style="margin-top:8px;",
          icon("spinner"), " Uploading and encoding... this may take several minutes (downloading photos from Google Drive).")
    )

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/roster/upload")) |>
        httr2::req_body_multipart(
          roster_xlsx = curl::form_file(
            input$roster_xlsx_file$datapath,
            type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          )
        ) |>
        httr2::req_timeout(300) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      list(error = e$message)
    })

    if (!is.null(result$error)) {
      output$roster_upload_result <- renderUI(
        div(class="alert alert-danger", style="margin-top:8px;",
            strong("Upload failed: "), result$error)
      )
      return()
    }

    if (!is.null(result$detail)) {
      output$roster_upload_result <- renderUI(
        div(class="alert alert-warning", style="margin-top:8px;",
            strong("Error: "), as.character(result$detail))
      )
      return()
    }

    created <- if (!is.null(result$students_created)) result$students_created else 0
    encoded <- if (!is.null(result$encodings_saved))  result$encodings_saved  else 0

    output$roster_upload_result <- renderUI(
      div(class="alert alert-success", style="margin-top:8px;",
          icon("check-circle"), " ",
          strong("Upload complete! "),
          sprintf("Students created/updated: %d | Face encodings saved: %d", created, encoded))
    )
  })

  observeEvent(input$roster_check_btn, {
    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/roster/students")) |>
        httr2::req_timeout(15) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (is.null(result)) {
      output$roster_status_panel <- renderUI(
        div(class="alert alert-warning", "Could not reach API.")
      )
      return()
    }

    total   <- length(result)
    encoded <- sum(sapply(result, function(s) isTRUE(s$has_encoding)))
    missing <- total - encoded

    pct <- if (total > 0) round(encoded / total * 100) else 0

    output$roster_status_panel <- renderUI(
      div(
        div(class="alert alert-info", style="margin-top:8px;",
            sprintf("Total students: %d | With encoding: %d (%d%%) | Missing: %d",
                    total, encoded, pct, missing)),
        if (missing > 0)
          div(class="alert alert-warning",
              icon("exclamation-triangle"), " ",
              sprintf("%d students have no face encoding — they cannot be identified by camera. Upload the roster XLSX to fix this.", missing))
        else
          div(class="alert alert-success",
              icon("check-circle"), " All students have face encodings. Camera is ready.")
      )
    )
  })

  # ========================================================================
  # UI OUTPUTS: NAVIGATION
  # ========================================================================
  output$lecturer_course_table <- shiny::renderUI({
    lecturer_attendance_course_table(courses_df = lecturer_courses_data())
  })

  shiny::observeEvent(input$lecturer_course_nav, {
    nav <- input$lecturer_course_nav
    df <- lecturer_courses_data()
    row <- df[nav$row, ]
    
    selected_course_id(row$code)
    selected_class_id(row$class)
    
    # Auto-generate Lecture ID for this week/class
    lec_id <- sprintf("LEC_%s_%s", row$class, format(Sys.Date(), "%Y%W"))
    current_lecture_id(lec_id)
    
    if (nav$dest == "live") {
      updateTabItems(session, "lecturer_menu", "lec_live")
    } else {
      updateTabItems(session, "lecturer_menu", "lec_reports")
    }
  })

  # ========================================================================
  # UI OUTPUTS: LIVE DASHBOARD (STATE MACHINE RENDERING)
  # ========================================================================
  
  output$lec_live_course_selector <- renderUI({
    df <- lecturer_courses_data()
    selectInput("live_course_id", "1. Select Course", choices = setNames(df$code, df$course), selected = selected_course_id())
  })

  output$lec_live_class_selector <- renderUI({
    req(input$live_course_id)
    uid <- session_state$user_id
    df <- safe_db_get(sprintf("SELECT class_id FROM classes WHERE course_id = '%s' AND lecturer_id = '%s'", input$live_course_id, uid))
    selectInput("live_class_id", "2. Select Section", choices = df$class_id, selected = selected_class_id())
  })

  output$lec_live_session_info <- renderUI({
    req(input$live_class_id)
    status <- current_session_status()
    
    if (status == "not_started") {
      tags$div(class="alert alert-info", "Waiting for lecturer to start camera.")
    } else if (status == "live") {
      tags$div(class="alert alert-success", "Session is LIVE. AI is monitoring.")
    } else {
      tags$div(class="alert alert-warning", "Session ENDED. Reviewing results.")
    }
  })

  output$lecturer_live_stream_ui <- renderUI({
    status <- current_session_status()

    cam_ui <- tags$div(
      # Video + overlay canvas container
      tags$div(
        style = "position:relative; width:100%; background:#000; border-radius:8px; overflow:hidden;",
        tags$video(
          id = "liveDashCam", autoplay = NA, playsinline = NA, muted = NA,
          style = "width:100%; display:block; min-height:200px;"
        ),
        # Transparent canvas overlay for bounding boxes
        tags$canvas(
          id = "liveDashOverlay",
          style = "position:absolute; top:0; left:0; width:100%; height:100%; pointer-events:none;"
        )
      ),
      # Hidden capture canvas
      tags$canvas(id = "liveDashCanvas", style = "display:none;"),
      # Controls
      tags$div(
        style = "display:flex; gap:8px; margin-top:10px; flex-wrap:wrap;",
        tags$button(type="button", class="btn btn-info btn-sm",
          onclick="startLiveCam()", icon("video"), " Start Camera"),
        tags$button(type="button", id="liveCamAutoBtn", class="btn btn-danger btn-sm",
          onclick="toggleLiveCamAuto()", icon("circle"), " Start Auto-Capture (5s)")
      ),
      # Detection result panel
      uiOutput("live_cam_result"),
      # JS
      tags$script(HTML("
        var _liveCamStream = null;
        var _liveCamTimer  = null;
        var _liveCamActive = false;

        function startLiveCam() {
          if (_liveCamStream) return;
          navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480 } })
            .then(function(s) {
              _liveCamStream = s;
              document.getElementById('liveDashCam').srcObject = s;
            })
            .catch(function(e) { alert('Camera error: ' + e.message); });
        }

        function toggleLiveCamAuto() {
          _liveCamActive = !_liveCamActive;
          var btn = document.getElementById('liveCamAutoBtn');
          if (_liveCamActive) {
            btn.className = 'btn btn-success btn-sm';
            btn.innerHTML = '<i class=\"fa fa-stop\"></i> Stop Capture';
            captureLiveFrame();
            _liveCamTimer = setInterval(captureLiveFrame, 5000);
          } else {
            btn.className = 'btn btn-danger btn-sm';
            btn.innerHTML = '<i class=\"fa fa-circle\"></i> Start Auto-Capture (5s)';
            clearInterval(_liveCamTimer);
            var ov = document.getElementById('liveDashOverlay');
            if (ov) ov.getContext('2d').clearRect(0, 0, ov.width, ov.height);
          }
        }

        function captureLiveFrame() {
          var v = document.getElementById('liveDashCam');
          if (!v || !v.srcObject || !v.videoWidth) return;
          var c = document.getElementById('liveDashCanvas');
          c.width  = v.videoWidth;
          c.height = v.videoHeight;
          c.getContext('2d').drawImage(v, 0, 0);
          Shiny.setInputValue('live_cam_frame',
            c.toDataURL('image/jpeg', 0.8), { priority: 'event' });
        }

        // Draw bounding boxes — set canvas buffer = frame dims, CSS scales visually
        window.drawFaceBoxes = function(data) {
          var ov = document.getElementById('liveDashOverlay');
          if (!ov) return;
          var fw = data.frame_width  || 640;
          var fh = data.frame_height || 480;
          ov.width  = fw;
          ov.height = fh;
          var ctx = ov.getContext('2d');
          ctx.clearRect(0, 0, fw, fh);
          (data.detected || []).forEach(function(d) {
            if (!d.bbox) return;
            var b   = d.bbox;
            var col = (d.enrolled === true)  ? '#00e676' :
                      (d.enrolled === false) ? '#ff9100' : '#ffff00';
            ctx.strokeStyle = col;
            ctx.lineWidth   = 3;
            ctx.strokeRect(b.x, b.y, b.w, b.h);
            var lbl = d.name + (d.emotion ? ' [' + d.emotion + ']' : '');
            ctx.font = 'bold 13px Arial';
            var tw = ctx.measureText(lbl).width;
            ctx.fillStyle = 'rgba(0,0,0,0.65)';
            ctx.fillRect(b.x, b.y - 22, tw + 8, 22);
            ctx.fillStyle = col;
            ctx.fillText(lbl, b.x + 4, b.y - 6);
          });
        };

        // Guard against double-registration when renderUI re-renders
        if (!window._faceBoxHandlerOK) {
          window._faceBoxHandlerOK = true;
          Shiny.addCustomMessageHandler('drawFaceBoxes', function(data) {
            window.drawFaceBoxes(data);
          });
        }
      "))
    )

    if (status == "ended") {
      summary <- session_summary_data()
      tags$div(style = "padding:20px; color:white;",
        h3("Session Summary"), hr(),
        p(strong("Attendance: "), if (!is.null(summary)) summary$attendance_count else "N/A"),
        p(strong("Emotion readings: "), if (!is.null(summary)) summary$emotion_count else "N/A"),
        br(),
        actionButton("view_attendance_review", "ATTENDANCE REVIEW", class = "btn-primary"),
        actionButton("hard_reset_session", "HARD RESET", class = "btn-warning")
      )
    } else {
      cam_ui
    }
  })

  # Camera frame handler — POST to DO vision endpoint, draw boxes, update panel
  output$live_cam_result <- renderUI({ div() })

  observeEvent(input$live_cam_frame, {
    lecture_id <- current_lecture_id()
    if (nchar(lecture_id) == 0) return()

    b64     <- sub("^data:image/[^;]+;base64,", "", input$live_cam_frame)
    tmp_jpg <- tempfile(fileext = ".jpg")
    writeBin(base64enc::base64decode(b64), tmp_jpg)
    on.exit(unlink(tmp_jpg), add = TRUE)

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/vision/process-frame")) |>
        httr2::req_body_multipart(
          image      = curl::form_file(tmp_jpg, type = "image/jpeg"),
          lecture_id = lecture_id
        ) |>
        httr2::req_timeout(25) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (is.null(result)) {
      output$live_cam_result <- renderUI(
        div(class="alert alert-warning", style="margin-top:8px; font-size:12px;", "Vision API unreachable.")
      )
      return()
    }

    if (!is.null(result$detail)) {
      output$live_cam_result <- renderUI(
        div(class="alert alert-warning", style="margin-top:8px; font-size:12px;", as.character(result$detail))
      )
      return()
    }

    # Push bbox data to JS for drawing
    session$sendCustomMessage("drawFaceBoxes", list(
      detected     = if (length(result$detected) > 0) result$detected else list(),
      frame_width  = if (!is.null(result$frame_width))  result$frame_width  else 640,
      frame_height = if (!is.null(result$frame_height)) result$frame_height else 480
    ))

    # Build result summary panel
    detected <- result$detected
    n_total    <- if (!is.null(result$faces_found)) result$faces_found else 0
    n_enrolled <- sum(sapply(detected, function(d) isTRUE(d$enrolled)))
    n_not_enrolled <- sum(sapply(detected, function(d) identical(d$enrolled, FALSE)))
    n_unknown  <- sum(sapply(detected, function(d) is.null(d$enrolled)))

    header_text <- sprintf(
      "Faces detected: %d | Present (enrolled): %d | Not in class: %d | Unknown: %d",
      n_total, n_enrolled, n_not_enrolled, n_unknown
    )

    rows <- lapply(detected, function(d) {
      if (isTRUE(d$enrolled)) {
        col   <- "#00e676"
        mark  <- "✓"
        label <- paste0(d$name, if (!is.null(d$emotion) && !identical(d$emotion, "")) paste0(" — ", d$emotion) else "")
      } else if (identical(d$enrolled, FALSE)) {
        col   <- "#ff9100"
        mark  <- "⚠"
        label <- paste0(d$name, " — not enrolled in this class")
      } else {
        col   <- "#f0c040"
        mark  <- "?"
        label <- "Unknown face — not in database"
      }
      tags$div(
        style = paste0("color:", col, "; font-size:12px; padding:2px 0;"),
        paste(mark, label)
      )
    })

    output$live_cam_result <- renderUI(
      tags$div(
        tags$div(class="alert alert-info", style="margin-top:8px; font-size:12px; padding:6px 10px;", header_text),
        if (length(rows) > 0) tags$div(style="padding:4px 10px;", rows) else NULL
      )
    )
  })

  output$lecturer_attendance_grid <- renderUI({
    data <- live_attendance()
    if (nrow(data) == 0) return(tags$div("No students enrolled.", style="color: #999;"))

    tags$div(class = "student-card-grid",
      lapply(seq_len(nrow(data)), function(i) {
        row <- data[i, ]
        is_present <- !is.na(row$status) && (toupper(row$status) == "PRESENT")
        
        img_src <- if (!is.na(row$snapshot_url) && nchar(row$snapshot_url) > 0) {
            sprintf("%s/api/attendance/snapshot/%s/%s", Sys.getenv("FASTAPI_BASE_URL", ""), current_lecture_id(), row$student_id)
        } else {
            row$photo_url
        }

        tags$div(class = paste("student-card", if(is_present) "present" else "absent"),
          tags$img(src = img_src, class = "student-img"),
          tags$div(class = "student-name", row$name),
          tags$div(class = "student-status", if(is_present) "IDENTIFIED" else "WAITING...")
        )
      })
    )
  })

  output$lecturer_live_session_actions <- renderUI({
    status <- current_session_status()
    if (status == "not_started") {
      actionButton("start_session_btn", "START SESSION", class="btn-success btn-lg btn-block")
    } else if (status == "live") {
      actionButton("stop_session_btn", "END SESSION", class="btn-danger btn-lg btn-block")
    } else {
      NULL
    }
  })

  # --- ACTION HANDLERS ---
  shiny::observeEvent(input$start_session_btn, {
    req(input$live_class_id)
    body <- list(
      lecture_id = current_lecture_id(),
      class_id = input$live_class_id,
      lecturer_id = session_state$user_id,
      title = sprintf("Session %s", current_lecture_id())
    )
    api_call("/session/start", method="POST", body=body, auth_token=session_state$token)
    current_session_status("live")
  })

  shiny::observeEvent(input$stop_session_btn, {
    api_call("/session/end", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
    current_session_status("ended")
  })

  shiny::observeEvent(input$hard_reset_session, {
    api_call("/session/reset", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
    current_session_status("not_started")
    session_summary_data(NULL)
  })

  # ========================================================================
  # ANALYTICS & REPORTS (2X2 GRID)
  # ========================================================================
  output$lec_report_course_selector <- renderUI({
    df <- lecturer_courses_data()
    selectInput("rep_course_id", "Select Course", choices = setNames(df$code, df$course), selected = selected_course_id())
  })

  output$lec_report_class_selector <- renderUI({
    req(input$rep_course_id)
    df <- safe_db_get(sprintf("SELECT class_id FROM classes WHERE course_id = '%s'", input$rep_course_id))
    selectInput("rep_class_id", "Select Class", choices = df$class_id, selected = selected_class_id())
  })

  output$lec_report_session_selector <- renderUI({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf("SELECT lecture_id, title FROM lectures WHERE class_id = '%s' ORDER BY created_at DESC", input$rep_class_id))
    selectInput("rep_lecture_id", "Select Session", choices = setNames(df$lecture_id, df$title))
  })

  output$lec_report_emotion_pie <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT emotion, count(*) as count FROM emotion_log WHERE lecture_id = '%s' GROUP BY emotion", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, labels = ~emotion, values = ~count, type = 'pie')
  })

  output$lec_report_engagement_line <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT timestamp, engagement_score FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score, type = 'scatter', mode = 'lines')
  })

  output$lec_report_attendance_table <- DT::renderDataTable({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT s.name, al.status, al.timestamp FROM students s JOIN attendance_log al ON s.student_id = al.student_id WHERE al.lecture_id = '%s'", input$rep_lecture_id))
    DT::datatable(df)
  })

  output$lec_report_student_clusters <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT student_id, avg(engagement_score) as avg_score FROM emotion_log WHERE lecture_id = '%s' GROUP BY student_id", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, x = ~student_id, y = ~avg_score, type = 'bar')
  })

  # --- LIVE GAUGE ---
  output$lecturer_d1_gauge <- plotly::renderPlotly({
    df <- live_emotions()
    val <- if (nrow(df) > 0) mean(df$engagement_score, na.rm=TRUE) else 0
    plotly::plot_ly(type = "indicator", mode = "gauge+number", value = val,
                   gauge = list(axis = list(range = list(0, 1)), bar = list(color = "#002147")))
  })

  output$lecturer_live_sentiment_ticker <- renderUI({
    df <- live_emotions()
    if (nrow(df) == 0) return(p("No data yet..."))
    latest <- head(df, 5)
    lapply(seq_len(nrow(latest)), function(i) {
      p(tags$span(style="color:#28a745", "[Live] "), 
        sprintf("Student detected with %s emotion.", latest$emotion[i]))
    })
  })

  # ========================================================================
  # LMS MATERIALS
  # ========================================================================
  output$lecturer_materials_table <- DT::renderDataTable({
    req(selected_course_id())
    df <- safe_db_get(sprintf("SELECT title, uploaded_at, drive_link FROM materials WHERE material_id LIKE 'MAT_%s%%'", selected_course_id()))
    DT::datatable(df)
  })

  # ========================================================================
  # DEBUG INFO
  # ========================================================================
  output$lecturer_debug_out <- renderText({
    url <- get_db_url()
    db_status <- if(!is.null(url) && nchar(url) > 0) "DATABASE_URL Present" else "DATABASE_URL MISSING"
    err <- global_db_error()
    
    # Filter out sensitive or irrelevant keys
    all_keys <- names(Sys.getenv())
    clean_keys <- all_keys[!grepl("SUPABASE|PASSWORD|SECRET|KEY|TOKEN", all_keys, ignore.case = TRUE)]
    
    paste0(
      "--- System Diagnostic (v4.0.0) ---\n",

      "Login User: ", if(!is.null(session_state$user_id)) session_state$user_id else "NONE", "\n",
      "Login Role: ", if(!is.null(session_state$role)) session_state$role else "NONE", "\n",
      "Env Status: ", db_status, "\n",
      "Last DB Error: ", if(nchar(err) > 0) err else "None", "\n",
      "Classes Found: ", if(!is.null(lecturer_courses_data())) nrow(lecturer_courses_data()) else "0", "\n",
      "Active Lec: ", current_lecture_id(), "\n",
      "State: ", current_session_status(), "\n",
      "Env Keys (Public): ", paste(clean_keys, collapse=", ")
    )
  })
}
