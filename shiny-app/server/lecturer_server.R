# lecturer_server.R

lecturer_server <- function(input, output, session, session_state) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/attendance.R",       local = TRUE)

  # ── DB helper ────────────────────────────────────────────────────────────────
  safe_db_get <- function(query) {
    db_url <- get_db_url()
    if (db_url == "") return(data.frame())
    params <- parse_postgres_url(db_url)
    tryCatch({
      con <- if (is.null(params)) {
        dbConnect(RPostgres::Postgres(), dbname = db_url)
      } else {
        dbConnect(RPostgres::Postgres(),
                  host = params$host, port = params$port,
                  user = params$user, password = params$password,
                  dbname = params$dbname, sslmode = "require")
      }
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      res
    }, error = function(e) {
      global_db_error(paste("[DB]", e$message))
      data.frame()
    })
  }

  # ── State ────────────────────────────────────────────────────────────────────
  selected_course_id     <- reactiveVal(NULL)
  selected_class_id      <- reactiveVal(NULL)
  current_session_status <- reactiveVal("not_started")
  current_lecture_id     <- reactiveVal("")
  session_summary_data   <- reactiveVal(NULL)

  # ── Courses for this lecturer ─────────────────────────────────────────────
  lecturer_courses_data <- reactive({
    uid <- session_state$user_id
    if (is.null(uid) || uid == "") return(data.frame())
    safe_db_get(sprintf(
      "SELECT co.title AS course, co.course_id AS code, cl.class_id AS class
       FROM classes cl
       JOIN courses co ON cl.course_id = co.course_id
       WHERE cl.lecturer_id = '%s'
       ORDER BY co.title", uid
    ))
  })

  # ── Poll session status every 3 s ────────────────────────────────────────
  # IMPORTANT: only write to current_session_status when the value actually changes.
  # reactiveVal always invalidates dependents on every write (even same value),
  # so writing "live" every 3s would destroy+recreate action buttons, losing clicks.
  observe({
    lid <- current_lecture_id()
    req(nchar(lid) > 0)
    invalidateLater(3000, session)
    d <- api_call(paste0("/session/status/", lid), auth_token = session_state$token)
    if (!is.null(d) && !is.null(d$status)) {
      new_status <- d$status
      old_status <- isolate(current_session_status())
      if (!identical(new_status, old_status)) {
        current_session_status(new_status)
        if (new_status == "ended") session_summary_data(d)
      }
    }
  })

  # ── Live DB polls (only when live) ───────────────────────────────────────
  live_emotions <- reactive({
    lid <- current_lecture_id()
    req(nchar(lid) > 0)
    if (current_session_status() == "live") invalidateLater(3000, session)
    safe_db_get(sprintf(
      "SELECT * FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp DESC LIMIT 200", lid
    ))
  })

  live_attendance <- reactive({
    lid <- current_lecture_id()
    req(nchar(lid) > 0)
    if (current_session_status() == "live") invalidateLater(2000, session)
    safe_db_get(sprintf(
      "SELECT s.student_id, s.name, al.status, al.timestamp
       FROM enrollments e
       JOIN students s ON e.student_id = s.student_id
       LEFT JOIN attendance_log al
         ON s.student_id = al.student_id AND al.lecture_id = '%s'
       WHERE e.class_id = (
         SELECT class_id FROM lectures WHERE lecture_id = '%s' LIMIT 1
       )", lid, lid
    ))
  })

  # ════════════════════════════════════════════════════════════════════════════
  # HOME TAB — My Courses
  # ════════════════════════════════════════════════════════════════════════════
  output$lecturer_course_table <- renderUI({
    df <- lecturer_courses_data()
    if (is.null(df) || nrow(df) == 0)
      return(div(class = "alert alert-warning",
                 icon("exclamation-triangle"), " No classes assigned to your account yet.",
                 br(), "Ask the admin to assign you a class."))
    lecturer_attendance_course_table(courses_df = df,
                                     selected_code  = selected_course_id(),
                                     selected_class = selected_class_id())
  })

  observeEvent(input$lecturer_course_nav, {
    nav <- input$lecturer_course_nav
    df  <- lecturer_courses_data()
    if (is.null(nav) || nav$row > nrow(df)) return()
    row <- df[nav$row, ]
    selected_course_id(row$code)
    selected_class_id(row$class)
    week_num <- if (!is.null(input$live_week_num)) input$live_week_num else 1
    lec_id   <- build_lecture_id(row$class, week_num)
    current_lecture_id(lec_id)
    dest_tab <- if (nav$dest == "live") "lec_live" else "lec_reports"
    session$sendCustomMessage("setTab", dest_tab)
  })

  # ════════════════════════════════════════════════════════════════════════════
  # LIVE TAB — Selectors
  # ════════════════════════════════════════════════════════════════════════════
  output$lec_live_course_selector <- renderUI({
    df <- lecturer_courses_data()
    if (nrow(df) == 0) return(p("No courses found.", style = "color:red;"))
    selectInput("live_course_id", "1. Course",
                choices  = setNames(df$code, df$course),
                selected = selected_course_id())
  })

  output$lec_live_class_selector <- renderUI({
    req(input$live_course_id)
    df <- safe_db_get(sprintf(
      "SELECT class_id FROM classes WHERE course_id = '%s' AND lecturer_id = '%s'",
      input$live_course_id, session_state$user_id
    ))
    selectInput("live_class_id", "2. Section",
                choices  = df$class_id,
                selected = selected_class_id())
  })

  output$lec_live_week_selector <- renderUI({
    selectInput("live_week_num", "3. Academic Week",
                choices  = setNames(1:16, paste("Week", 1:16)),
                selected = 1)
  })

  # Build lecture ID from class + week
  build_lecture_id <- function(class_id, week_num) {
    sprintf("LEC_%s_WEEK%02d", class_id, as.integer(week_num))
  }

  # Reload session status for a given lecture ID
  reload_session_status <- function(lec_id) {
    d <- api_call(paste0("/session/status/", lec_id), auth_token = session_state$token)
    if (!is.null(d) && !is.null(d$status)) {
      current_session_status(d$status)
      if (d$status == "ended") session_summary_data(d)
    } else {
      current_session_status("not_started")
      session_summary_data(NULL)
    }
  }

  # Auto-update lecture_id when class selector changes
  observeEvent(input$live_class_id, {
    req(input$live_class_id)
    week_num <- if (!is.null(input$live_week_num)) input$live_week_num else 1
    lec_id   <- build_lecture_id(input$live_class_id, week_num)
    current_lecture_id(lec_id)
    selected_class_id(input$live_class_id)
    reload_session_status(lec_id)
  })

  # Auto-update lecture_id when week selector changes
  observeEvent(input$live_week_num, {
    req(input$live_class_id, input$live_week_num)
    lec_id <- build_lecture_id(input$live_class_id, input$live_week_num)
    current_lecture_id(lec_id)
    reload_session_status(lec_id)
  })

  output$lec_live_session_info <- renderUI({
    status <- current_session_status()
    lid    <- current_lecture_id()
    if (status == "not_started")
      div(class = "alert alert-info",    style = "margin:0;", icon("info-circle"),
          " Ready. Press START SESSION to begin.")
    else if (status == "live")
      div(class = "alert alert-success", style = "margin:0;", icon("circle"),
          " Session LIVE — AI camera active.")
    else
      div(class = "alert alert-secondary", style = "margin:0;", icon("check-circle"),
          " Session ended. Check the summary below.")
  })

  # ════════════════════════════════════════════════════════════════════════════
  # LIVE TAB — Session action buttons (footer of the camera box)
  # ════════════════════════════════════════════════════════════════════════════
  output$lecturer_live_session_actions <- renderUI({
    status <- current_session_status()
    if (status == "not_started")
      actionButton("start_session_btn",
                   tagList(icon("play"), " START SESSION"),
                   class = "btn-success btn-lg btn-block",
                   style = "margin-top:10px;")
    else if (status == "live")
      actionButton("stop_session_btn",
                   tagList(icon("stop"), " END SESSION"),
                   class = "btn-danger btn-lg btn-block",
                   style = "margin-top:10px;")
    else
      NULL
  })

  # ════════════════════════════════════════════════════════════════════════════
  # LIVE TAB — Main camera area  (3 states)
  # ════════════════════════════════════════════════════════════════════════════
  output$lecturer_live_stream_ui <- renderUI({
    status <- current_session_status()

    # ── STATE 1: not started — camera is locked ──────────────────────────────
    if (status == "not_started") {
      return(
        div(style = "padding:40px; text-align:center; background:#f8f9fa; border-radius:8px; border:2px dashed #ccc;",
            tags$i(class = "fa fa-lock fa-3x", style = "color:#aaa; display:block; margin-bottom:15px;"),
            h4("Camera is locked", style = "color:#555;"),
            p("Select your course and section, then click", strong("START SESSION"), "below."),
            p(style = "font-size:11px; color:#aaa;",
              "Session ID: ", code(current_lecture_id()))
        )
      )
    }

    # ── STATE 2: ended — session summary ────────────────────────────────────
    if (status == "ended") {
      s <- session_summary_data()
      att <- if (!is.null(s) && !is.null(s$attendance_count)) s$attendance_count else 0
      emo <- if (!is.null(s) && !is.null(s$emotion_count))    s$emotion_count    else 0
      return(
        div(style = "padding:20px;",
            h3(icon("check-circle", style="color:#28a745;"), " Session Complete"),
            hr(),
            fluidRow(
              column(4,
                div(style = "background:#e8f5e9; border-radius:8px; padding:20px; text-align:center;",
                    div(style = "font-size:40px; font-weight:bold; color:#2e7d32;", att),
                    div("Students Present", style = "color:#555; margin-top:5px;"))
              ),
              column(4,
                div(style = "background:#e3f2fd; border-radius:8px; padding:20px; text-align:center;",
                    div(style = "font-size:40px; font-weight:bold; color:#1565c0;", emo),
                    div("Emotion Readings", style = "color:#555; margin-top:5px;"))
              ),
              column(4,
                div(style = "background:#fff8e1; border-radius:8px; padding:20px; text-align:center;",
                    div(style = "font-size:40px; font-weight:bold; color:#f57f17;",
                        if (!is.null(s) && !is.null(s$frames_captured)) s$frames_captured else 0),
                    div("Frames Captured", style = "color:#555; margin-top:5px;"))
              )
            ),
            br(),
            actionButton("hard_reset_session", tagList(icon("redo"), " Start New Session"),
                         class = "btn-warning btn-block")
        )
      )
    }

    # ── STATE 3: live — camera is active ────────────────────────────────────
    # JS (startLiveCam, toggleLiveCamAuto, captureLiveFrame, drawFaceBoxes)
    # is defined once in the static UI (lecturer_ui.R tags$script) so it
    # never re-initialises on renderUI refresh.
    tagList(
      div(
        style = "position:relative; width:100%; background:#000; border-radius:8px; overflow:hidden;",
        tags$video(id = "liveDashCam", autoplay = NA, playsinline = NA, muted = NA,
                   style = "width:100%; display:block; min-height:220px;"),
        tags$canvas(id = "liveDashOverlay",
                    style = "position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;")
      ),
      tags$canvas(id = "liveDashCanvas", style = "display:none;"),
      div(style = "display:flex; gap:8px; margin-top:10px; flex-wrap:wrap; align-items:center;",
          tags$button(type = "button", class = "btn btn-primary btn-sm",
                      onclick = "startLiveCam()",
                      tagList(icon("video"), " Start Camera")),
          tags$button(type = "button", id = "liveCamAutoBtn", class = "btn btn-danger btn-sm",
                      onclick = "toggleLiveCamAuto()",
                      tagList(icon("circle"), " Auto-Capture (every 5s)"))
      ),
      uiOutput("live_cam_result")
    )
  })

  # ── QR Code panel — shown when session is live ───────────────────────────
  output$lecturer_live_qr_panel <- renderUI({
    status <- current_session_status()
    lid    <- current_lecture_id()
    if (status != "live" || nchar(lid) == 0) return(NULL)

    qr_data <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/attendance/qr/", lid)) |>
        httr2::req_headers("Authorization" = paste("Bearer", session_state$token)) |>
        httr2::req_timeout(10) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (is.null(qr_data) || is.null(qr_data$qr_image_base64)) return(NULL)

    shinydashboard::box(
      title = tagList(icon("qrcode"), " Attendance QR Code"),
      width = 12, status = "success", solidHeader = TRUE,
      div(style = "text-align:center; padding:8px;",
        tags$img(
          src   = paste0("data:image/png;base64,", qr_data$qr_image_base64),
          style = "width:180px; height:180px; border:3px solid #28a745; border-radius:8px;"
        ),
        tags$p(
          "Students scan this with the mobile app",
          style = "font-size:0.78em; color:#666; margin-top:6px; margin-bottom:2px;"
        ),
        tags$code(lid, style = "font-size:0.75em; color:#888;")
      )
    )
  })

  # ── Camera frame handler ──────────────────────────────────────────────────
  output$live_cam_result <- renderUI({ div() })

  observeEvent(input$live_cam_frame, {
    lid <- current_lecture_id()
    if (nchar(lid) == 0 || current_session_status() != "live") return()

    b64     <- sub("^data:image/[^;]+;base64,", "", input$live_cam_frame)
    tmp_jpg <- tempfile(fileext = ".jpg")
    writeBin(base64enc::base64decode(b64), tmp_jpg)
    on.exit(unlink(tmp_jpg), add = TRUE)

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/vision/process-frame")) |>
        httr2::req_body_multipart(
          image      = curl::form_file(tmp_jpg, type = "image/jpeg"),
          lecture_id = lid
        ) |>
        httr2::req_timeout(25) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (is.null(result)) {
      output$live_cam_result <- renderUI(
        div(class = "alert alert-warning", style = "margin-top:8px;",
            icon("exclamation-triangle"), " Vision API unreachable.")
      )
      return()
    }
    if (!is.null(result$detail)) {
      output$live_cam_result <- renderUI(
        div(class = "alert alert-danger", style = "margin-top:8px;",
            icon("times-circle"), " ", as.character(result$detail))
      )
      return()
    }

    session$sendCustomMessage("drawFaceBoxes", list(
      detected     = if (length(result$detected) > 0) result$detected else list(),
      frame_width  = if (!is.null(result$frame_width))  result$frame_width  else 640,
      frame_height = if (!is.null(result$frame_height)) result$frame_height else 480
    ))

    detected   <- result$detected
    n_total    <- if (!is.null(result$faces_found)) result$faces_found else 0
    n_enrolled <- sum(sapply(detected, function(d) isTRUE(d$enrolled)))
    n_other    <- n_total - n_enrolled

    rows <- lapply(detected, function(d) {
      if (isTRUE(d$enrolled)) {
        col  <- "#1b5e20"; mark <- "✓"
        lbl  <- paste0(d$name, if (!is.null(d$emotion) && nchar(d$emotion) > 0)
                                 paste0(" — ", d$emotion) else "")
      } else if (identical(d$enrolled, FALSE)) {
        col  <- "#e65100"; mark <- "⚠"
        lbl  <- paste0(d$name, " — not enrolled in this class")
      } else {
        col  <- "#827717"; mark <- "?"
        lbl  <- "Unknown face"
      }
      div(style = paste0("color:", col, "; font-size:12px; padding:2px 0;"),
          paste(mark, lbl))
    })

    output$live_cam_result <- renderUI(
      div(
        div(class = "alert alert-info", style = "margin-top:8px; font-size:12px; padding:6px 10px;",
            sprintf("Faces: %d | Enrolled present: %d | Other: %d", n_total, n_enrolled, n_other)),
        if (length(rows) > 0) div(style = "padding:4px 10px;", rows) else NULL
      )
    )
  })

  # ── Attendance grid ───────────────────────────────────────────────────────
  output$lecturer_attendance_grid <- renderUI({
    df <- live_attendance()
    if (nrow(df) == 0)
      return(p("No enrolled students found for this session.", style = "color:#999;"))
    div(class = "student-card-grid",
      lapply(seq_len(nrow(df)), function(i) {
        row        <- df[i, ]
        is_present <- !is.na(row$status) && toupper(row$status) == "PRESENT"
        div(class = paste("student-card", if (is_present) "present" else "absent"),
            div(class = "student-name",   row$name),
            div(class = "student-status", if (is_present) "✓ PRESENT" else "Waiting…"))
      })
    )
  })

  # ── Session action handlers ───────────────────────────────────────────────
  observeEvent(input$start_session_btn, {
    req(input$live_class_id)
    week_num <- if (!is.null(input$live_week_num)) input$live_week_num else 1
    lid  <- build_lecture_id(input$live_class_id, week_num)
    current_lecture_id(lid)
    body <- list(
      lecture_id  = lid,
      class_id    = input$live_class_id,
      lecturer_id = session_state$user_id,
      title       = sprintf("Week %s — %s", week_num, input$live_class_id)
    )
    res <- api_call("/session/start", method = "POST", body = body,
                    auth_token = session_state$token)
    if (!is.null(res)) current_session_status("live")
  })

  observeEvent(input$stop_session_btn, {
    lid <- current_lecture_id()
    api_call("/session/end", method = "POST", body = list(lecture_id = lid),
             auth_token = session_state$token)
    # Immediately fetch final counts so summary doesn't show N/A
    Sys.sleep(0.4)
    final <- api_call(paste0("/session/status/", lid), auth_token = session_state$token)
    if (!is.null(final)) session_summary_data(final)
    current_session_status("ended")
  })

  observeEvent(input$hard_reset_session, {
    lid <- current_lecture_id()
    api_call("/session/reset", method = "POST", body = list(lecture_id = lid),
             auth_token = session_state$token)
    session_summary_data(NULL)
    current_session_status("not_started")
  })

  # ════════════════════════════════════════════════════════════════════════════
  # EXAM PROCTORING
  # ════════════════════════════════════════════════════════════════════════════
  active_exam_id     <- reactiveVal(NULL)
  exam_active        <- reactiveVal(FALSE)

  # ── Exam tab selectors ────────────────────────────────────────────────────
  output$lec_exam_course_selector <- renderUI({
    df <- lecturer_courses_data()
    if (nrow(df) == 0) return(p("No courses found.", style = "color:red;"))
    selectInput("exam_course_id", "Course",
                choices  = setNames(df$code, df$course),
                selected = selected_course_id())
  })

  output$lec_exam_class_selector <- renderUI({
    req(input$exam_course_id)
    df <- safe_db_get(sprintf(
      "SELECT class_id FROM classes WHERE course_id = '%s' AND lecturer_id = '%s'",
      input$exam_course_id, session_state$user_id
    ))
    selectInput("exam_class_id", "Section",
                choices  = df$class_id,
                selected = selected_class_id())
  })

  live_incidents <- reactive({
    req(exam_active(), !is.null(active_exam_id()))
    invalidateLater(3000, session)
    safe_db_get(sprintf(
      "SELECT i.timestamp, s.name AS student, i.flag_type, i.severity, i.evidence_path
       FROM incidents i
       LEFT JOIN students s ON i.student_id = s.student_id
       WHERE i.exam_id = '%s'
       ORDER BY i.timestamp DESC
       LIMIT 100", active_exam_id()
    ))
  })

  output$exam_start_stop_btn <- renderUI({
    if (!exam_active()) {
      actionButton("exam_start_btn", tagList(icon("play"), " Start Exam"),
                   class = "btn-danger btn-block")
    } else {
      actionButton("exam_stop_btn", tagList(icon("stop"), " End Exam"),
                   class = "btn-dark btn-block")
    }
  })

  output$exam_status_badge <- renderUI({
    if (exam_active()) {
      tags$span(class = "label label-danger", style = "font-size:14px; padding:6px 12px;",
                icon("circle"), " EXAM LIVE")
    } else {
      tags$span(class = "label label-default", style = "font-size:14px; padding:6px 12px;",
                "No active exam")
    }
  })

  observeEvent(input$exam_start_btn, {
    # Use exam tab selector; fall back to live dashboard selector
    class_id_to_use <- if (!is.null(input$exam_class_id) && nchar(input$exam_class_id) > 0)
      input$exam_class_id else input$live_class_id
    req(class_id_to_use, nchar(trimws(input$exam_title_input)) > 0)
    title <- trimws(input$exam_title_input)
    # Create exam
    res <- api_call("/exam", method = "POST",
                    body = list(class_id = class_id_to_use,
                                title    = title,
                                scheduled_start = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")),
                    auth_token = session_state$token)
    if (is.null(res) || is.null(res$exam_id)) {
      shinyalert::shinyalert("Error", "Could not create exam.", type = "error")
      return()
    }
    eid <- res$exam_id
    active_exam_id(eid)
    # Start vision pipeline in exam context
    lid <- paste0("EXAM_", gsub("[^A-Za-z0-9]", "", title), "_", format(Sys.Date(), "%Y%m%d"))
    current_lecture_id(lid)
    api_call("/session/start", method = "POST",
             body = list(lecture_id  = lid,
                         class_id    = class_id_to_use,
                         lecturer_id = session_state$user_id,
                         title       = title,
                         context     = "exam",
                         exam_id     = eid),
             auth_token = session_state$token)
    exam_active(TRUE)
    shinyalert::shinyalert("Exam Started", paste("Proctoring active for:", title), type = "success")
  })

  observeEvent(input$exam_stop_btn, {
    eid <- active_exam_id()
    lid <- current_lecture_id()
    if (!is.null(eid)) api_call(paste0("/exam/", eid, "/end"), method = "POST",
                                auth_token = session_state$token)
    if (nchar(lid) > 0)  api_call("/session/end", method = "POST",
                                  body = list(lecture_id = lid),
                                  auth_token = session_state$token)
    exam_active(FALSE)
    active_exam_id(NULL)
    shinyalert::shinyalert("Exam Ended", "Proctoring session closed.", type = "info")
  })

  sev_color <- function(s) switch(as.character(s), "3"="#dc3545","2"="#fd7e14","1"="#ffc107","#6c757d")

  output$exam_incidents_table <- DT::renderDataTable({
    df <- if (exam_active()) live_incidents() else data.frame()
    if (is.null(df) || nrow(df) == 0)
      return(DT::datatable(data.frame(Message = "No incidents yet."), options = list(dom = "t"), rownames = FALSE))
    df$severity <- as.integer(df$severity)
    DT::datatable(df[, c("timestamp","student","flag_type","severity")],
                  rownames = FALSE, options = list(pageLength = 10, dom = "tp")) |>
      DT::formatStyle("severity",
        backgroundColor = DT::styleEqual(c(1,2,3), c("#fff3cd","#ffe0b2","#ffcdd2")),
        fontWeight = "bold")
  })

  output$exam_box_total  <- shinydashboard::renderValueBox({
    n <- if (exam_active() && nrow(live_incidents()) > 0) nrow(live_incidents()) else 0
    shinydashboard::valueBox(n, "Total Incidents", icon = icon("flag"), color = "red")
  })
  output$exam_box_high   <- shinydashboard::renderValueBox({
    n <- if (exam_active() && nrow(live_incidents()) > 0) sum(live_incidents()$severity == 3, na.rm=TRUE) else 0
    shinydashboard::valueBox(n, "High (Sev 3)", icon = icon("exclamation-triangle"), color = "red")
  })
  output$exam_box_medium <- shinydashboard::renderValueBox({
    n <- if (exam_active() && nrow(live_incidents()) > 0) sum(live_incidents()$severity == 2, na.rm=TRUE) else 0
    shinydashboard::valueBox(n, "Medium (Sev 2)", icon = icon("eye"), color = "orange")
  })
  output$exam_box_low    <- shinydashboard::renderValueBox({
    n <- if (exam_active() && nrow(live_incidents()) > 0) sum(live_incidents()$severity == 1, na.rm=TRUE) else 0
    shinydashboard::valueBox(n, "Low (Sev 1)", icon = icon("info-circle"), color = "yellow")
  })

  # ── Live gauge ────────────────────────────────────────────────────────────
  output$lecturer_d1_gauge <- plotly::renderPlotly({
    df  <- live_emotions()
    val <- if (nrow(df) > 0) mean(df$engagement_score, na.rm = TRUE) else 0
    plotly::plot_ly(
      type = "indicator", mode = "gauge+number", value = round(val, 2),
      gauge = list(
        axis  = list(range = list(0, 1)),
        bar   = list(color = "#002147"),
        steps = list(
          list(range = list(0, 0.45),  color = "#ffcdd2"),
          list(range = list(0.45, 0.75), color = "#fff9c4"),
          list(range = list(0.75, 1),   color = "#c8e6c9")
        )
      ),
      title = list(text = "Class Engagement Score")
    ) |> plotly::layout(margin = list(t = 40, b = 20))
  })

  # ── Sentiment ticker ─────────────────────────────────────────────────────
  output$lecturer_live_sentiment_ticker <- renderUI({
    df <- live_emotions()
    if (nrow(df) == 0) return(p("No emotion readings yet…", style = "color:#999;"))
    latest <- head(df, 8)
    lapply(seq_len(nrow(latest)), function(i) {
      p(tags$span(style = "color:#28a745;", "[Live] "),
        sprintf("Student — %s", latest$emotion[i]))
    })
  })

  # ── Auto confusion detection ─────────────────────────────────────────────
  observe({
    req(current_session_status() == "live")
    invalidateLater(15000, session)
    df <- live_emotions()
    if (nrow(df) < 10) {
      output$lecturer_confusion_alert_ui <- renderUI({ div() })
      return()
    }
    recent        <- head(df, 40)
    confusion_rate <- mean(recent$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE)
    if (confusion_rate >= 0.40) {
      output$lecturer_confusion_alert_ui <- renderUI({
        div(class = "alert alert-warning", style = "margin-top:8px; padding:10px;",
            icon("exclamation-triangle"), " ",
            strong(sprintf("%.0f%% of class is confused or frustrated.", confusion_rate * 100)),
            br(),
            small("Click ", strong("Ask AI"), " to get a clarifying question from your materials."))
      })
    } else {
      output$lecturer_confusion_alert_ui <- renderUI({ div() })
    }
  })

  # ── AI intervention button ────────────────────────────────────────────────
  observeEvent(input$lecturer_trigger_refresher, {
    # Determine the best lecture_id to use:
    # prefer the live session; fall back to any lecture for the selected class.
    lid <- current_lecture_id()

    if (nchar(lid) == 0) {
      # Try to derive from the live-tab class selector
      if (!is.null(input$live_class_id) && nchar(input$live_class_id) > 0) {
        week_num <- if (!is.null(input$live_week_num)) input$live_week_num else 1
        lid <- build_lecture_id(input$live_class_id, week_num)
      }
    }

    if (nchar(lid) == 0) {
      shinyalert::shinyalert("No Class Selected",
        "Please select a course and section in the Live Dashboard first.",
        type = "warning")
      return()
    }

    shinyalert::shinyalert(
      title = "Generating...",
      text  = "Asking Gemini AI — this may take up to 15 seconds.",
      type  = "info", showConfirmButton = FALSE, timer = 15000
    )

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/gemini/question")) |>
        httr2::req_url_query(lecture_id = lid) |>
        httr2::req_method("POST") |>
        httr2::req_headers("Authorization" = paste("Bearer", session_state$token)) |>
        httr2::req_timeout(30) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (!is.null(result) && !is.null(result$question)) {
      mat <- if (!is.null(result$material_title) && nchar(result$material_title) > 0)
               paste0("<small>Source: <em>", result$material_title, "</em></small><br><br>")
             else ""
      shinyalert::shinyalert(
        title             = "AI Clarifying Question",
        text              = paste0(mat, "<strong>", result$question, "</strong>"),
        html              = TRUE,
        type              = "info",
        confirmButtonText = "Got it"
      )
    } else {
      detail <- if (!is.null(result$detail)) as.character(result$detail) else
                "Could not generate question. Ensure materials are uploaded for this course."
      shinyalert::shinyalert("AI Unavailable", detail, type = "warning")
    }
  })

  # ════════════════════════════════════════════════════════════════════════════
  # REPORTS TAB
  # ════════════════════════════════════════════════════════════════════════════
  output$lec_report_course_selector <- renderUI({
    df <- lecturer_courses_data()
    if (nrow(df) == 0) return(p("No courses.", style = "color:red;"))
    selectInput("rep_course_id", "Course",
                choices  = setNames(df$code, df$course),
                selected = selected_course_id())
  })

  output$lec_report_class_selector <- renderUI({
    req(input$rep_course_id)
    df <- safe_db_get(sprintf(
      "SELECT class_id FROM classes WHERE course_id = '%s'", input$rep_course_id
    ))
    selectInput("rep_class_id", "Section", choices = df$class_id,
                selected = selected_class_id())
  })

  output$lec_report_session_selector <- renderUI({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf(
      "SELECT lecture_id, COALESCE(title, lecture_id) AS title
       FROM lectures WHERE class_id = '%s' ORDER BY created_at DESC",
      input$rep_class_id
    ))
    if (nrow(df) == 0)
      return(p("No sessions recorded for this class yet.", style = "color:#888;"))
    selectInput("rep_lecture_id", "Session",
                choices = setNames(df$lecture_id, df$title))
  })

  output$lec_report_emotion_pie <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf(
      "SELECT emotion, COUNT(*) AS cnt FROM emotion_log
       WHERE lecture_id = '%s' GROUP BY emotion", input$rep_lecture_id
    ))
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No emotion data for this session"))
    }
    plotly::plot_ly(df, labels = ~emotion, values = ~cnt, type = "pie",
                    marker = list(colors = c(
                      "#1B5E20","#4CAF50","#FFC107","#FF9800","#9C27B0","#F44336"
                    ))) |>
      plotly::layout(title = "Emotion Distribution")
  })

  output$lec_report_engagement_line <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf(
      "SELECT timestamp, engagement_score FROM emotion_log
       WHERE lecture_id = '%s' ORDER BY timestamp", input$rep_lecture_id
    ))
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No engagement data for this session"))
    }
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score,
                    type = "scatter", mode = "lines",
                    line = list(color = "#002147")) |>
      plotly::layout(title  = "Engagement Over Time",
                     xaxis  = list(title = "Time"),
                     yaxis  = list(title = "Score", range = c(0, 1)))
  })

  output$lec_report_attendance_table <- DT::renderDataTable({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf(
      "SELECT s.name AS student, al.status, al.timestamp
       FROM students s
       JOIN attendance_log al ON s.student_id = al.student_id
       WHERE al.lecture_id = '%s'
       ORDER BY s.name", input$rep_lecture_id
    ))
    if (nrow(df) == 0) return(data.frame(Message = "No attendance recorded yet."))
    DT::datatable(df, options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
  })

  output$lec_report_student_clusters <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf(
      "SELECT s.name AS student, AVG(el.engagement_score) AS avg_score
       FROM students s
       JOIN emotion_log el ON s.student_id = el.student_id
       WHERE el.lecture_id = '%s'
       GROUP BY s.name
       ORDER BY avg_score DESC", input$rep_lecture_id
    ))
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No data yet"))
    }
    plotly::plot_ly(df, x = ~student, y = ~avg_score, type = "bar",
                    marker = list(color = "#002147")) |>
      plotly::layout(title  = "Engagement per Student",
                     xaxis  = list(title = "", tickangle = -45),
                     yaxis  = list(title = "Avg Score", range = c(0, 1)))
  })

  # ── CROSS-SESSION: engagement trend across all sessions for selected class ──
  output$lec_report_cross_session_trend <- plotly::renderPlotly({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf(
      "SELECT l.lecture_id,
              COALESCE(l.title, l.lecture_id) AS label,
              ROUND(AVG(el.engagement_score)::numeric, 3) AS avg_score,
              COUNT(DISTINCT el.student_id) AS students,
              l.created_at
       FROM emotion_log el
       JOIN lectures l ON el.lecture_id = l.lecture_id
       WHERE l.class_id = '%s'
       GROUP BY l.lecture_id, l.title, l.created_at
       HAVING COUNT(*) >= 3
       ORDER BY l.created_at",
      input$rep_class_id
    ))
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No cross-session data yet — run and end at least one session"))
    }
    df$color <- ifelse(df$avg_score >= 0.75, "#1B5E20",
                       ifelse(df$avg_score >= 0.45, "#FFC107", "#F44336"))
    plotly::plot_ly(df,
      x    = ~label, y = ~avg_score, type = "scatter", mode = "lines+markers",
      line   = list(color = "#002147", width = 2),
      marker = list(color = ~color, size = 10),
      hovertext = ~paste0(label, "<br>Avg Engagement: ", avg_score,
                          "<br>Students: ", students),
      hoverinfo = "text") |>
      plotly::layout(
        title = "Session Engagement Trend",
        xaxis = list(title = "Session", tickangle = -30),
        yaxis = list(title = "Avg Engagement Score", range = c(0, 1)),
        shapes = list(
          list(type = "line", x0 = 0, x1 = 1, xref = "paper",
               y0 = 0.75, y1 = 0.75, line = list(color = "#4CAF50", dash = "dot")),
          list(type = "line", x0 = 0, x1 = 1, xref = "paper",
               y0 = 0.45, y1 = 0.45, line = list(color = "#FF9800", dash = "dot"))
        )
      )
  })

  # ── CROSS-SESSION: emotion variation (stacked bar per session) ─────────────
  output$lec_report_emotion_variation_sessions <- plotly::renderPlotly({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf(
      "SELECT COALESCE(l.title, l.lecture_id) AS session_label,
              el.emotion,
              COUNT(*) AS cnt
       FROM emotion_log el
       JOIN lectures l ON el.lecture_id = l.lecture_id
       WHERE l.class_id = '%s'
       GROUP BY l.lecture_id, l.title, el.emotion
       ORDER BY l.created_at",
      input$rep_class_id
    ))
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No emotion data across sessions yet"))
    }
    emotion_colors <- c(
      Focused     = "#1B5E20",
      Engaged     = "#4CAF50",
      Confused    = "#FFC107",
      Frustrated  = "#FF9800",
      Anxious     = "#9C27B0",
      Disengaged  = "#F44336"
    )
    emotions_order <- c("Focused", "Engaged", "Confused", "Frustrated", "Anxious", "Disengaged")
    traces <- lapply(emotions_order, function(em) {
      sub_df <- df[df$emotion == em, ]
      if (nrow(sub_df) == 0) return(NULL)
      plotly::add_trace(
        plotly::plot_ly(),
        x    = sub_df$session_label,
        y    = sub_df$cnt,
        type = "bar",
        name = em,
        marker = list(color = emotion_colors[[em]])
      )
    })
    p <- plotly::plot_ly()
    for (em in emotions_order) {
      sub_df <- df[df$emotion == em, ]
      if (nrow(sub_df) == 0) next
      p <- plotly::add_trace(p,
        x      = sub_df$session_label, y = sub_df$cnt,
        type   = "bar", name = em,
        marker = list(color = emotion_colors[[em]])
      )
    }
    p |> plotly::layout(
      barmode = "stack",
      title   = "Emotion Mix per Session",
      xaxis   = list(title = "Session", tickangle = -30),
      yaxis   = list(title = "Count"),
      legend  = list(traceorder = "normal")
    )
  })

  # ── CROSS-SESSION: per-student summary table across all sessions ────────────
  output$lec_report_student_summary <- DT::renderDataTable({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf(
      "SELECT s.name                                                        AS Student,
              COUNT(DISTINCT el.lecture_id)                                AS Sessions,
              ROUND(AVG(el.engagement_score)::numeric, 3)                  AS Avg_Engagement,
              MODE() WITHIN GROUP (ORDER BY el.emotion)                    AS Top_Emotion,
              ROUND(AVG(CASE WHEN el.emotion IN ('Confused','Frustrated')
                             THEN 1.0 ELSE 0.0 END)::numeric, 3)           AS Confusion_Rate,
              ROUND(AVG(CASE WHEN el.emotion = 'Disengaged'
                             THEN 1.0 ELSE 0.0 END)::numeric, 3)           AS Disengaged_Rate
       FROM emotion_log el
       JOIN lectures l  ON el.lecture_id  = l.lecture_id
       JOIN students s  ON el.student_id  = s.student_id
       WHERE l.class_id = '%s'
       GROUP BY s.student_id, s.name
       ORDER BY Avg_Engagement DESC",
      input$rep_class_id
    ))
    if (nrow(df) == 0) return(data.frame(Message = "No cross-session data yet."))
    DT::datatable(df,
      options  = list(pageLength = 15, scrollX = TRUE, order = list(list(2, "desc"))),
      rownames = FALSE
    ) |>
      DT::formatStyle("Avg_Engagement",
        background = DT::styleInterval(c(0.45, 0.75),
                                        c("#FFCDD2", "#FFF9C4", "#C8E6C9"))) |>
      DT::formatStyle("Confusion_Rate",
        background = DT::styleInterval(c(0.3, 0.5),
                                        c("#C8E6C9", "#FFF9C4", "#FFCDD2")))
  })

  # ════════════════════════════════════════════════════════════════════════════
  # MATERIALS TAB — selectors
  # ════════════════════════════════════════════════════════════════════════════
  output$lec_mat_course_selector <- renderUI({
    df <- lecturer_courses_data()
    if (nrow(df) == 0) return(p("No courses assigned.", style = "color:red;"))
    selectInput("mat_course_id", "Course",
                choices = setNames(df$code, df$course))
  })

  output$lec_mat_class_selector <- renderUI({
    # Use selected course or fall back to the first course so the selector
    # renders immediately without waiting for a user interaction.
    course_id <- if (!is.null(input$mat_course_id) && nchar(input$mat_course_id) > 0) {
      input$mat_course_id
    } else {
      all_courses <- lecturer_courses_data()
      if (nrow(all_courses) == 0) return(p("No sections found.", style = "color:#888;"))
      all_courses$code[1]
    }
    df <- safe_db_get(sprintf(
      "SELECT class_id FROM classes WHERE course_id = '%s' AND lecturer_id = '%s'",
      course_id, session_state$user_id
    ))
    if (nrow(df) == 0) return(p("No sections found for this course.", style = "color:#888;"))
    selectInput("mat_class_id", "Section", choices = df$class_id)
  })

  # ════════════════════════════════════════════════════════════════════════════
  # MATERIALS TAB — table
  # ════════════════════════════════════════════════════════════════════════════
  output$lecturer_materials_table <- DT::renderDataTable({
    uid <- session_state$user_id
    if (is.null(uid)) return(data.frame())
    df <- safe_db_get(sprintf(
      "SELECT m.title, m.uploaded_at, m.drive_link,
              l.title AS session, co.title AS course
       FROM materials m
       JOIN lectures l  ON m.lecture_id  = l.lecture_id
       JOIN classes  cl ON l.class_id    = cl.class_id
       JOIN courses  co ON cl.course_id  = co.course_id
       WHERE m.lecturer_id = '%s'
       ORDER BY m.uploaded_at DESC", uid
    ))
    if (nrow(df) == 0) return(data.frame(Message = "No materials uploaded yet."))
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  observeEvent(input$lecturer_material_upload, {
    if (is.null(input$mat_class_id) || nchar(input$mat_class_id) == 0) {
      shinyalert::shinyalert("No Section",
        "Please select a course and section before uploading.", type = "warning")
      return()
    }
    if (is.null(input$lecturer_material_file)) {
      shinyalert::shinyalert("No File",
        "Please choose a PDF file to upload.", type = "warning")
      return()
    }

    week_num  <- if (!is.null(input$lecturer_material_week)) input$lecturer_material_week else 1
    lec_id    <- build_lecture_id(input$mat_class_id, week_num)
    file_info <- input$lecturer_material_file
    title_str <- sub("\\.[^.]+$", "", file_info$name)  # strip extension

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/upload/material")) |>
        httr2::req_method("POST") |>
        httr2::req_headers("Authorization" = paste("Bearer", session_state$token)) |>
        httr2::req_body_multipart(
          file        = curl::form_file(file_info$datapath, type = "application/pdf",
                                        name = file_info$name),
          lecture_id  = lec_id,
          class_id    = input$mat_class_id,
          lecturer_id = session_state$user_id,
          title       = title_str,
          week        = as.character(week_num)
        ) |>
        httr2::req_timeout(60) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) list(detail = e$message))

    if (!is.null(result$material_id) || identical(result$status, "uploaded")) {
      shinyalert::shinyalert("Uploaded",
        sprintf("'%s' saved for Week %s — AI can now use this material.", file_info$name, week_num),
        type = "success")
    } else {
      msg <- if (!is.null(result$detail)) as.character(result$detail) else
               "Upload failed — check the file and try again."
      shinyalert::shinyalert("Upload Error", msg, type = "error")
    }
  })

  # ════════════════════════════════════════════════════════════════════════════
  # DEBUG
  # ════════════════════════════════════════════════════════════════════════════
  output$lecturer_debug_out <- renderText({
    paste0(
      "User: ",      session_state$user_id, "\n",
      "Role: ",      session_state$role,    "\n",
      "Lecture ID: ", current_lecture_id(),  "\n",
      "Status: ",    current_session_status(), "\n",
      "DB error: ",  global_db_error(),     "\n",
      "Classes: ",   if (!is.null(lecturer_courses_data())) nrow(lecturer_courses_data()) else 0
    )
  })
}
