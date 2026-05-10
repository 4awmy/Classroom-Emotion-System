# lecturer_server.R - Server logic for 5 lecturer submodules

lecturer_server <- function(input, output, session, session_state = NULL) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # Reactive data - cached and moderately refreshed for dashboard responsiveness.
  emotions_data <- shiny::reactive({
    shiny::invalidateLater(30000, session)
    query_table("emotions")
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(30000, session)
    query_table("attendance")
  })

  incidents_data <- shiny::reactive({
    shiny::invalidateLater(30000, session)
    query_table("incidents")
  })

  home_pct <- function(value) {
    if (is.null(value) || length(value) == 0 || is.na(value)) return("0%")
    sprintf("%.0f%%", value * 100)
  }

  output$lecturer_home_kpis <- shiny::renderUI({
    attendance <- attendance_data()
    emotions <- emotions_data()
    incidents <- incidents_data()

    total_subjects <- nrow(unique(lecturer_course_rows[c("code", "class")]))
    planned_lectures <- total_subjects * 16
    lecture_count <- length(unique(c(attendance$lecture_id, emotions$lecture_id)))

    attendance_rate <- if (nrow(attendance) > 0 && "status" %in% names(attendance)) {
      mean(tolower(attendance$status) == "present", na.rm = TRUE)
    } else {
      NA_real_
    }

    avg_engagement <- if (nrow(emotions) > 0 && "engagement_score" %in% names(emotions)) {
      mean(emotions$engagement_score, na.rm = TRUE)
    } else {
      NA_real_
    }

    confusion_rate <- if (nrow(emotions) > 0 && "emotion" %in% names(emotions)) {
      mean(emotions$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE)
    } else {
      NA_real_
    }

    exam_ids <- if (nrow(incidents) > 0 && "exam_id" %in% names(incidents)) {
      unique(stats::na.omit(incidents$exam_id))
    } else {
      character(0)
    }

    high_severity <- if (nrow(incidents) > 0 && "severity" %in% names(incidents)) {
      sum(suppressWarnings(as.numeric(incidents$severity)) >= 3, na.rm = TRUE)
    } else {
      0
    }

    shiny::fluidRow(
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Subjects"), shiny::strong(total_subjects), shiny::small("assigned"))),
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Planned Lectures"), shiny::strong(planned_lectures), shiny::small("16 weeks each"))),
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Active Lectures"), shiny::strong(lecture_count), shiny::small("with records"))),
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Attendance"), shiny::strong(home_pct(attendance_rate)), shiny::small("present rate"))),
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Engagement"), shiny::strong(home_pct(avg_engagement)), shiny::small("average score"))),
      shiny::column(2, shiny::div(class = "lecturer-kpi-card", shiny::span("Exam Risk"), shiny::strong(high_severity), shiny::small(sprintf("%d exams tracked", length(exam_ids)))))
    )
  })

  output$lecturer_home_weekly_trend <- plotly::renderPlotly({
    attendance <- attendance_data()
    emotions <- emotions_data()

    att_week <- data.frame()
    if (nrow(attendance) > 0 && all(c("timestamp", "status") %in% names(attendance))) {
      attendance$timestamp <- as.POSIXct(attendance$timestamp)
      att_week <- attendance |>
        dplyr::mutate(week = lubridate::floor_date(.data$timestamp, "week"),
                      present = tolower(.data$status) == "present") |>
        dplyr::group_by(.data$week) |>
        dplyr::summarise(attendance_rate = mean(.data$present, na.rm = TRUE), .groups = "drop")
    }

    eng_week <- data.frame()
    if (nrow(emotions) > 0 && all(c("timestamp", "engagement_score") %in% names(emotions))) {
      emotions$timestamp <- as.POSIXct(emotions$timestamp)
      eng_week <- emotions |>
        dplyr::mutate(week = lubridate::floor_date(.data$timestamp, "week")) |>
        dplyr::group_by(.data$week) |>
        dplyr::summarise(engagement = mean(.data$engagement_score, na.rm = TRUE), .groups = "drop")
    }

    if (nrow(att_week) == 0 && nrow(eng_week) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No weekly attendance or engagement data yet"))
    }

    p <- plotly::plot_ly()
    if (nrow(att_week) > 0) {
      p <- p |> plotly::add_trace(data = att_week, x = ~week, y = ~attendance_rate, name = "Attendance", type = "scatter", mode = "lines+markers")
    }
    if (nrow(eng_week) > 0) {
      p <- p |> plotly::add_trace(data = eng_week, x = ~week, y = ~engagement, name = "Engagement", type = "scatter", mode = "lines+markers")
    }
    p |> plotly::layout(yaxis = list(title = "Rate", range = c(0, 1)), xaxis = list(title = "Week"))
  })

  output$lecturer_home_emotion_mix <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0 || !"emotion" %in% names(emotions)) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No emotion data yet"))
    }
    mix <- emotions |>
      dplyr::group_by(.data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop")

    plotly::plot_ly(mix, labels = ~emotion, values = ~count, type = "pie", hole = 0.45) |>
      plotly::layout(showlegend = TRUE)
  })

  output$lecturer_home_subject_table <- DT::renderDataTable({
    attendance <- attendance_data()
    emotions <- emotions_data()

    subjects <- lecturer_course_rows |>
      dplyr::mutate(subject_key = paste(.data$code, .data$class, sep = "-")) |>
      dplyr::select(Subject = .data$course, Code = .data$code, Class = .data$class, subject_key)

    att <- data.frame()
    if (nrow(attendance) > 0 && all(c("lecture_id", "status") %in% names(attendance))) {
      att <- attendance |>
        dplyr::mutate(subject_key = sub("-W[0-9]{2}$", "", .data$lecture_id),
                      present = tolower(.data$status) == "present") |>
        dplyr::group_by(.data$subject_key) |>
        dplyr::summarise(`Attendance %` = mean(.data$present, na.rm = TRUE), `Attendance Records` = dplyr::n(), .groups = "drop")
    }

    eng <- data.frame()
    if (nrow(emotions) > 0 && all(c("lecture_id", "engagement_score", "emotion") %in% names(emotions))) {
      eng <- emotions |>
        dplyr::mutate(subject_key = sub("-W[0-9]{2}$", "", .data$lecture_id)) |>
        dplyr::group_by(.data$subject_key) |>
        dplyr::summarise(
          `Engagement %` = mean(.data$engagement_score, na.rm = TRUE),
          `Confusion %` = mean(.data$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE),
          .groups = "drop"
        )
    }

    out <- subjects |>
      dplyr::left_join(att, by = "subject_key") |>
      dplyr::left_join(eng, by = "subject_key") |>
      dplyr::mutate(
        `Attendance %` = ifelse(is.na(`Attendance %`), 0, round(`Attendance %` * 100, 1)),
        `Engagement %` = ifelse(is.na(`Engagement %`), 0, round(`Engagement %` * 100, 1)),
        `Confusion %` = ifelse(is.na(`Confusion %`), 0, round(`Confusion %` * 100, 1)),
        `Attendance Records` = ifelse(is.na(`Attendance Records`), 0, `Attendance Records`)
      ) |>
      dplyr::select(-.data$subject_key)

    DT::datatable(out, options = list(pageLength = 6, dom = "tip"), rownames = FALSE)
  })

  output$lecturer_home_assessment_table <- DT::renderDataTable({
    attendance <- attendance_data()
    incidents <- incidents_data()

    exam_summary <- if (nrow(incidents) > 0 && "exam_id" %in% names(incidents)) {
      incidents |>
        dplyr::filter(!is.na(.data$exam_id), .data$exam_id != "") |>
        dplyr::mutate(severity_num = suppressWarnings(as.numeric(.data$severity))) |>
        dplyr::group_by(.data$exam_id) |>
        dplyr::summarise(
          `Exam Incidents` = dplyr::n(),
          `High Severity` = sum(.data$severity_num >= 3, na.rm = TRUE),
          `Students Flagged` = dplyr::n_distinct(.data$student_id),
          .groups = "drop"
        ) |>
        dplyr::rename(`Exam ID` = .data$exam_id)
    } else {
      data.frame(`Exam ID` = character(), `Exam Incidents` = integer(), `High Severity` = integer(), `Students Flagged` = integer())
    }

    if (nrow(exam_summary) == 0) {
      lecture_att <- if (nrow(attendance) > 0 && all(c("lecture_id", "status") %in% names(attendance))) {
        attendance |>
          dplyr::mutate(present = tolower(.data$status) == "present") |>
          dplyr::group_by(.data$lecture_id) |>
          dplyr::summarise(`Attendance %` = round(mean(.data$present, na.rm = TRUE) * 100, 1), `Records` = dplyr::n(), .groups = "drop") |>
          dplyr::rename(`Lecture ID` = .data$lecture_id) |>
          head(8)
      } else {
        data.frame(Message = "No exam incidents or lecture attendance records yet.")
      }
      return(DT::datatable(lecture_att, options = list(dom = "t"), rownames = FALSE))
    }

    DT::datatable(exam_summary, options = list(pageLength = 6, dom = "tip"), rownames = FALSE)
  })

  # ========================================================================
  # Submodule B: Material Upload
  # ========================================================================

  resolve_lecturer_subject <- function(row_index) {
    idx <- suppressWarnings(as.integer(row_index))
    if (is.na(idx) || idx < 1 || idx > nrow(lecturer_course_rows)) {
      idx <- 1
    }
    as.list(lecturer_course_rows[idx, ])
  }

  build_week_lecture_id <- function(subject, week_value) {
    week <- if (is.null(week_value) || nchar(trimws(week_value)) == 0) "W01" else trimws(week_value)
    paste(subject$code, subject$class, week, sep = "-")
  }

  format_subject_label <- function(subject) {
    sprintf("%s (%s) - Class %s", subject$course, subject$code, subject$class)
  }

  get_material_lecture_id <- function() {
    subject <- resolve_lecturer_subject(input$lecturer_material_subject)
    build_week_lecture_id(subject, input$lecturer_week_select)
  }

  output$lecturer_materials_table <- DT::renderDataTable({
    materials <- load_csv("../python-api/data/exports/materials.csv")
    if (nrow(materials) == 0) return(data.frame())
    DT::datatable(
      materials |> dplyr::select(dplyr::any_of(c("title", "lecture_id", "lecturer_id", "uploaded_at"))),
      options = list(pageLength = 10)
    )
  })

  shiny::observeEvent(input$lecturer_material_upload, {
    req(input$lecturer_material_file, input$lecturer_material_subject,
        input$lecturer_week_select, input$lecturer_material_title)

    file_info <- input$lecturer_material_file
    lecture_id <- get_material_lecture_id()

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/upload/material")) |>
        httr2::req_body_multipart(
          lecture_id  = lecture_id,
          lecturer_id = "LECTURER_1",   # TODO: replace with session user_id
          title       = input$lecturer_material_title,
          file        = curl::form_file(file_info$datapath, type = file_info$type)
        ) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      shinyalert::shinyalert("Upload Failed", as.character(e), type = "error")
      NULL
    })

    if (!is.null(result)) {
      shinyalert::shinyalert("Success", "Material uploaded successfully.", type = "success")
    }
  })

  # ========================================================================
  # Submodule C: Attendance (Photo Card Grid)
  # ========================================================================

  attendance_list <- shiny::reactiveVal(list())
  attendance_qr_base64 <- shiny::reactiveVal(NULL)
  attendance_page <- shiny::reactiveVal("index")
  selected_attendance_course <- shiny::reactiveVal(list(
    course = "Big data Analytics",
    code = "CIS4103",
    class = "D",
    day = "Sunday",
    slots = "9 => 10"
  ))

  # Helper: resolve lecture_id from the selected Moodle-style course row.
  get_attendance_lecture_id <- function() {
    selected <- selected_attendance_course()
    if (is.null(selected$code) || is.null(selected$class)) return("")
    build_week_lecture_id(selected, input$lecturer_attendance_week %||% "W01")
  }

  output$lecturer_selected_course_title <- shiny::renderUI({
    selected <- selected_attendance_course()
    week <- input$lecturer_attendance_week %||% "W01"
    shiny::div(
      class = "selected-course-title",
      shiny::span(class = "selected-course-kicker", sprintf("Selected Session - %s", week)),
      shiny::strong(sprintf("%s | %s | Class %s", selected$course, selected$code, selected$class)),
      shiny::span(sprintf("%s, %s", selected$day, selected$slots))
    )
  })

  output$lecturer_mobile_attendance_panel <- shiny::renderUI({
    students <- attendance_list()
    student_names <- if (length(students) > 0) {
      lapply(students, function(s) {
        shiny::li(
          shiny::span(class = "mobile-student-id", s$student_id),
          shiny::span(class = "mobile-student-name", s$name)
        )
      })
    } else {
      list(shiny::li(class = "mobile-empty-roster", "No students loaded for this session."))
    }

    shiny::div(
      class = "mobile-attendance-panel",
      shiny::div(
        class = "mobile-attendance-roster",
        shiny::strong("Students"),
        shiny::tags$ul(student_names)
      ),
      shiny::div(
        class = "mobile-attendance-qr",
        shiny::strong("Mobile Attendance QR"),
        shiny::span("Scan to check in for the selected session."),
        imageOutput("lecturer_qr_image")
      )
    )
  })

  render_attendance_index <- function() {
    selected <- selected_attendance_course()
    shiny::div(
      class = "reference-page-card reference-attendance-page",
      shiny::div(class = "semester-eyebrow", "The First Semester 2025/2026"),
      shiny::div(
        class = "attendance-title-row",
        shiny::h2("Attendance"),
        shiny::div(
          class = "attendance-filters",
          shiny::div(
            class = "department-filter",
            shiny::tags$label("Department"),
            shiny::selectInput(
              "lecturer_reference_department",
              NULL,
              choices = c("All", "Computing", "Business", "Engineering"),
              selected = "All",
              width = "100%"
            )
          ),
          shiny::div(
            class = "department-filter",
            shiny::tags$label("Lecture Week"),
            shiny::selectInput(
              "lecturer_attendance_week",
              NULL,
              choices = lecturer_week_choices(),
              selected = input$lecturer_attendance_week %||% "W01",
              width = "100%"
            )
          )
        )
      ),
      shiny::div(
        class = "reference-attendance-table-wrap",
        lecturer_attendance_course_table(
          selected_code = selected$code,
          selected_class = selected$class
        )
      )
    )
  }

  render_student_attendance_page <- function() {
    shiny::div(
      class = "course-attendance-detail",
      shiny::div(
        class = "attendance-destination-heading",
        shiny::h2("Student Attendance"),
        shiny::p("Manage attendance for the selected subject and lecture week.")
      ),
      shiny::div(
        class = "course-attendance-detail-header",
        shiny::uiOutput("lecturer_selected_course_title"),
        shiny::div(
          class = "course-attendance-actions",
          shiny::actionButton("lecturer_back_to_attendance_index", "Back", class = "btn-info", icon = shiny::icon("arrow-left")),
          shiny::actionButton("lecturer_attendance_refresh", "Refresh", class = "btn-info", icon = shiny::icon("sync")),
          shiny::actionButton("lecturer_attendance_save", "Save Changes", class = "btn-success", icon = shiny::icon("save"))
        )
      ),
      shiny::uiOutput("lecturer_attendance_grid")
    )
  }

  render_qr_attendance_page <- function() {
    shiny::div(
      class = "course-attendance-detail",
      shiny::div(
        class = "attendance-destination-heading",
        shiny::h2("Mobile Attendance QR"),
        shiny::p("Show the QR page for students to check in to the selected lecture.")
      ),
      shiny::div(
        class = "course-attendance-detail-header",
        shiny::uiOutput("lecturer_selected_course_title"),
        shiny::div(
          class = "course-attendance-actions",
          shiny::actionButton("lecturer_back_to_attendance_index", "Back", class = "btn-info", icon = shiny::icon("arrow-left")),
          shiny::actionButton("lecturer_qr_generate", "Regenerate QR", class = "btn-primary", icon = shiny::icon("qrcode"))
        )
      ),
      shiny::uiOutput("lecturer_mobile_attendance_panel")
    )
  }

  output$lecturer_attendance_page <- shiny::renderUI({
    page <- attendance_page()
    if (identical(page, "students")) return(render_student_attendance_page())
    if (identical(page, "qr")) return(render_qr_attendance_page())
    render_attendance_index()
  })

  shiny::observeEvent(input$lecturer_course_nav, {
    nav <- input$lecturer_course_nav
    row_index <- suppressWarnings(as.integer(nav$row))
    destination <- nav$dest

    if (is.na(row_index) || row_index < 1 || row_index > nrow(lecturer_course_rows)) {
      return()
    }

    selected_attendance_course(as.list(lecturer_course_rows[row_index, ]))

    if (identical(destination, "students")) {
      attendance_page("students")
      refresh_attendance()
    } else {
      attendance_page("qr")
      refresh_attendance()
      generate_attendance_qr()
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$lecturer_back_to_attendance_index, {
    attendance_page("index")
  })

  generate_attendance_qr <- function() {
    lecture_id <- get_attendance_lecture_id()
    attendance_qr_base64(NULL)
    if (nchar(lecture_id) == 0) {
      shinyalert::shinyalert("Error", "Select a course first.", type = "error")
      return()
    }

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/attendance/qr/", lecture_id)) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (!is.null(result) && !is.null(result$qr_image_base64)) {
      attendance_qr_base64(result$qr_image_base64)
    } else {
      shinyalert::shinyalert("QR Failed", "Could not generate QR code for this session.", type = "error")
    }
  }

  refresh_attendance <- function() {
    students <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/roster/students")) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (is.null(students)) return()

    att_df   <- attendance_data()
    lecture_id <- get_attendance_lecture_id()

    for (i in seq_along(students)) {
      sid <- students[[i]]$student_id
      if (nrow(att_df) > 0 && nchar(lecture_id) > 0) {
        student_att <- att_df |>
          dplyr::filter(.data$student_id == sid, .data$lecture_id == lecture_id) |>
          dplyr::arrange(dplyr::desc(.data$timestamp)) |>
          dplyr::slice(1)
        students[[i]]$status <- if (nrow(student_att) > 0) student_att$status else "Absent"
      } else {
        students[[i]]$status <- "Absent"
      }
    }
    attendance_list(students)
  }

  output$lecturer_attendance_grid <- shiny::renderUI({
    students  <- attendance_list()
    emotions  <- emotions_data()
    lecture_id <- get_attendance_lecture_id()

    if (length(students) == 0) {
      return(shiny::div(class = "alert alert-info",
                        "No students found. Upload a roster first."))
    }

    shiny::div(class = "attendance-grid",
      lapply(students, function(s) {
        status_class <- if (s$status == "Present") "present" else "absent"

        # Photo: use snapshot if present, else enrolled Drive photo or placeholder
        snapshot_url <- if (nchar(lecture_id) > 0) {
          paste0(FASTAPI_BASE, "/attendance/snapshot/", lecture_id, "/", s$student_id)
        } else {
          ""
        }

        # Latest engagement score for this student
        latest_eng <- if (nrow(emotions) > 0) {
          emotions |>
            dplyr::filter(.data$student_id == s$student_id) |>
            dplyr::arrange(dplyr::desc(.data$timestamp)) |>
            dplyr::slice(1) |>
            dplyr::pull(.data$engagement_score)
        } else {
          numeric(0)
        }

        eng_display <- if (length(latest_eng) > 0 && !is.na(latest_eng)) {
          sprintf("%.0f%%", latest_eng * 100)
        } else {
          "N/A"
        }

        eng_class <- if (length(latest_eng) > 0 && !is.na(latest_eng)) {
          if (latest_eng >= 0.75) "confidence-high"
          else if (latest_eng >= 0.45) "confidence-med"
          else "confidence-low"
        } else ""

        shiny::div(class = paste("student-card", status_class),
          # Photo with fallback — onerror hides broken image gracefully
          if (nchar(snapshot_url) > 0) {
            shiny::tags$img(
              src = snapshot_url, class = "student-photo",
              onerror = "this.style.display='none'"
            )
          } else {
            shiny::div(
              style = "width:110px;height:110px;border-radius:50%;background:#e0e0e0;margin:0 auto 15px;display:flex;align-items:center;justify-content:center;",
              shiny::icon("user", style = "font-size:3rem;color:#aaa;")
            )
          },
          shiny::div(class = "student-id", s$student_id),
          shiny::div(class = "student-name", s$name),
          shiny::div(class = "confidence-rate-label",
            "Engagement: ", shiny::span(class = eng_class, eng_display)
          ),
          shiny::div(class = "card-actions",
            shinyWidgets::materialSwitch(
              inputId = paste0("att_", s$student_id),
              label   = "Attendance",
              value   = (s$status == "Present"),
              status  = "success"
            )
          )
        )
      })
    )
  })

  shiny::observeEvent(input$lecturer_attendance_refresh, {
    refresh_attendance()
  })

  shiny::observeEvent(input$lecturer_attendance_save, {
    students   <- attendance_list()
    lecture_id <- get_attendance_lecture_id()
    if (length(students) == 0 || nchar(lecture_id) == 0) return()

    payload <- lapply(students, function(s) {
      list(
        student_id = s$student_id,
        lecture_id = lecture_id,
        status     = if (isTRUE(input[[paste0("att_", s$student_id)]])) "Present" else "Absent"
      )
    })

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/attendance/manual")) |>
        httr2::req_url_query(lecture_id = lecture_id) |>
        httr2::req_body_json(payload) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (!is.null(result)) {
      shinyalert::shinyalert("Success", "Attendance records updated.", type = "success")
    }
  })

  # QR code
  shiny::observeEvent(input$lecturer_qr_generate, {
    generate_attendance_qr()
  })

  output$lecturer_qr_image <- shiny::renderImage({
    qr <- attendance_qr_base64()
    req(qr)
    tmp <- tempfile(fileext = ".png")
    writeBin(base64enc::base64decode(qr), tmp)
    list(src = tmp, contentType = "image/png", width = 300, height = 300)
  }, deleteFile = TRUE)

  # ========================================================================
  # Submodule D: Live Dashboard (D1-D7)
  # Uses assigned subject + 16-week lecture selection for lecture_id
  # ========================================================================

  live_reactive <- shiny::reactiveTimer(5000)

  # Cloud Health & Vision Status
  output$lecturer_cloud_health_ui <- shiny::renderUI({
    live_reactive()
    res <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/health")) |> httr2::req_perform()
      TRUE
    }, error = function(e) FALSE)
    
    if (res) {
      shiny::div(class = "label label-success", "Cloud Online")
    } else {
      shiny::div(class = "label label-danger", "Cloud Unreachable")
    }
  })

  output$lecturer_vision_status_text <- shiny::renderText({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) return("Ready")
    
    # Check if we got any data in the last 10 seconds
    recent <- emotions |> 
      dplyr::filter(.data$lecture_id == lecture_id) |>
      dplyr::filter(.data$timestamp >= (lubridate::now() - lubridate::seconds(10)))
    
    if (nrow(recent) > 0) "Vision Node Streaming" else "Waiting for Local Node..."
  })

  # Vision Launcher Generator
  output$lecturer_download_launcher <- shiny::downloadHandler(
    filename = function() {
      paste0("run_classroom_ai_", get_live_lecture_id() %||% "W01", ".ps1")
    },
    content = function(file) {
      lecture_id <- get_live_lecture_id() %||% "W01"
      source_val <- input$lecturer_vision_source
      video_src <- if (source_val == "ip") {
        paste0("http://", input$lecturer_vision_ip, "/video")
      } else {
        source_val
      }
      
      # Build the PowerShell script
      script <- c(
        "# AAST Classroom Emotion System - Auto Launcher",
        paste0("$env:API_URL = '", FASTAPI_BASE, "'"),
        paste0("$env:VIDEO_SOURCE = '", video_src, "'"),
        paste0("$env:LECTURE_ID = '", lecture_id, "'"),
        "",
        "Write-Host '-----------------------------------------' -ForegroundColor Cyan",
        "Write-Host '   AAST VISION NODE STARTING...' -ForegroundColor Cyan",
        "Write-Host '-----------------------------------------' -ForegroundColor Cyan",
        "Write-Host 'Cloud API: ' -NoNewline; Write-Host $env:API_URL -ForegroundColor Green",
        "Write-Host 'Lecture:   ' -NoNewline; Write-Host $env:LECTURE_ID -ForegroundColor Green",
        "Write-Host 'Camera:    ' -NoNewline; Write-Host $env:VIDEO_SOURCE -ForegroundColor Green",
        "",
        "if (Get-Command python -ErrorAction SilentlyContinue) {",
        "    python vision/main.py",
        "} else {",
        "    Write-Host 'ERROR: Python not found in PATH.' -ForegroundColor Red",
        "    Read-Host 'Press Enter to exit'",
        "}"
      )
      writeLines(script, file)
    }
  )

  get_live_lecture_id <- function() {
    if (is.null(input$lecturer_live_subject) || is.null(input$lecturer_live_week)) return(NULL)
    subject <- resolve_lecturer_subject(input$lecturer_live_subject)
    build_week_lecture_id(subject, input$lecturer_live_week)
  }

  get_live_subject_label <- function() {
    subject <- resolve_lecturer_subject(input$lecturer_live_subject)
    sprintf("%s, %s", format_subject_label(subject), input$lecturer_live_week %||% "W01")
  }

  output$lecturer_live_custom_cam_ui <- shiny::renderUI({
    if (input$lecturer_live_camera == "custom") {
      textInput("lecturer_live_custom_cam", "Custom URL (RTSP/HTTP)", placeholder = "rtsp://...")
    }
  })

  output$lecturer_live_stream_ui <- shiny::renderUI({
    # Static render of stream URL - browser handles the MJPEG flow
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) {
      return(shiny::div(
        style = "color:#fff;padding:170px 20px;",
        "Select a subject and week, then start the lecture."
      ))
    }

    shiny::tags$img(
      src = paste0(FASTAPI_BASE, "/session/video_feed/", lecture_id),
      style = "max-width:100%;width:100%;height:auto;display:block;",
      onerror = "this.style.display='none';"
    )
  })

  output$lecturer_live_sentiment_ticker <- shiny::renderUI({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) {
      return(shiny::div("No live sentiment yet."))
    }

    recent <- emotions |>
      dplyr::filter(.data$lecture_id == lecture_id) |>
      dplyr::arrange(dplyr::desc(.data$timestamp)) |>
      head(5)

    if (nrow(recent) == 0) {
      return(shiny::div("No live sentiment yet."))
    }

    shiny::tags$ul(
      class = "list-unstyled",
      lapply(seq_len(nrow(recent)), function(i) {
        shiny::tags$li(
          shiny::strong(recent$student_id[i]),
          paste("-", recent$emotion[i], sprintf("(%.0f%%)", recent$engagement_score[i] * 100))
        )
      })
    )
  })

  shiny::observeEvent(input$lecturer_live_start, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) {
      shinyalert::shinyalert("Error", "Select a subject and lecture week first.", type = "error")
      return()
    }

    cam_url <- if (identical(input$lecturer_vision_source, "ip")) {
      paste0("http://", input$lecturer_vision_ip, "/video")
    } else {
      input$lecturer_vision_source
    }

    if (is.null(cam_url) || nchar(trimws(cam_url)) == 0) cam_url <- "0"

    result <- api_call("/session/start", method = "POST", body = list(
      lecture_id  = lecture_id,
      lecturer_id = "LECTURER_1",
      camera_url  = trimws(cam_url)
    ))

    if (!is.null(result)) {
      shinyalert::shinyalert("Lecture Started",
                             paste(get_live_subject_label(), "is now live using camera:", cam_url), type = "success")
    }
  })

  shiny::observeEvent(input$lecturer_live_end, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) return()
    tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/session/end")) |>
        httr2::req_body_json(list(lecture_id = lecture_id)) |>
        httr2::req_perform()
    }, error = function(e) NULL)
    shinyalert::shinyalert("Lecture Ended", "", type = "info")
  })

  # D1: Engagement Gauge
  output$lecturer_d1_gauge <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()

    if (nrow(emotions) == 0 || is.null(lecture_id)) return(plotly::plot_ly())

    recent <- emotions |>
      dplyr::filter(.data$lecture_id == lecture_id) |>
      tail(60)
    if (nrow(recent) == 0) return(plotly::plot_ly())

    avg_eng <- mean(recent$engagement_score, na.rm = TRUE)
    plotly::plot_ly(
      type = "indicator", mode = "gauge+number",
      value = round(avg_eng, 2),
      domain = list(x = c(0, 1), y = c(0, 1)),
      gauge = list(
        axis = list(range = list(0, 1)),
        bar  = list(color = "#002147"),
        steps = list(
          list(range = c(0, 0.25),   color = "#f8d7da"),
          list(range = c(0.25, 0.45), color = "#fff3cd"),
          list(range = c(0.45, 0.75), color = "#d4edda"),
          list(range = c(0.75, 1),    color = "#155724")
        )
      )
    ) |>
      plotly::layout(margin = list(t = 20, b = 20))
  })

  # D2: Emotion Timeline
  output$lecturer_d2_timeline <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(plotly::plot_ly())

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id)
    if (nrow(recent) == 0) return(plotly::plot_ly())

    timeline_data <- recent |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "2 minutes")) |>
      dplyr::group_by(.data$time_bucket, .data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::group_by(.data$time_bucket) |>
      dplyr::mutate(pct = .data$count / sum(.data$count))

    plotly::plot_ly(timeline_data, x = ~time_bucket) |>
      plotly::add_trace(y = ~pct, color = ~emotion, type = "scatter",
                        mode = "lines", stackgroup = "one") |>
      plotly::layout(yaxis = list(title = "% of class"),
                     xaxis = list(title = "Time"))
  })

  # D3: Cognitive Load
  output$lecturer_d3_load <- shiny::renderUI({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(shiny::div("No data"))

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id) |> tail(120)
    if (nrow(recent) == 0) return(shiny::div("No data"))

    cog_load <- mean(
      (recent$emotion == "Confused") + (recent$emotion == "Frustrated"),
      na.rm = TRUE
    )
    status_color <- if (cog_load > 0.5) "danger" else if (cog_load > 0.3) "warning" else "success"

    shiny::div(
      class = paste0("alert alert-", status_color),
      shiny::strong(sprintf("%.1f%%", cog_load * 100)),
      if (cog_load > 0.5) shiny::p("⚠ Overloaded — consider slowing down") else NULL
    )
  })

  # D4: Class Valence
  output$lecturer_d4_valence <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(plotly::plot_ly())

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id) |> tail(120)
    if (nrow(recent) == 0) return(plotly::plot_ly())

    valence <- mean(
      (recent$emotion %in% c("Focused", "Engaged")) -
        (recent$emotion %in% c("Frustrated", "Disengaged", "Anxious")),
      na.rm = TRUE
    )
    plotly::plot_ly(
      type = "indicator", mode = "gauge+number",
      value = round(valence, 2),
      domain = list(x = c(0, 1), y = c(0, 1)),
      gauge = list(
        axis  = list(range = list(-1, 1)),
        bar   = list(color = if (valence >= 0) "#28a745" else "#dc3545"),
        steps = list(
          list(range = c(-1, 0), color = "#fff3cd"),
          list(range = c(0, 1),  color = "#d4edda")
        )
      )
    )
  })

  # D5: Per-Student Heatmap
  output$lecturer_d5_heatmap <- shiny::renderPlot({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(NULL)

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id)
    if (nrow(recent) == 0) return(NULL)

    heatmap_data <- recent |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "5 minutes")) |>
      dplyr::group_by(.data$student_id, .data$time_bucket) |>
      dplyr::slice(1) |>
      dplyr::ungroup()

    ggplot2::ggplot(heatmap_data, ggplot2::aes(x = .data$time_bucket,
                                                y = .data$student_id,
                                                fill = .data$emotion)) +
      ggplot2::geom_tile() +
      ggplot2::scale_fill_manual(values = c(
        "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
        "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
      )) +
      ggplot2::theme_minimal() +
      ggplot2::theme(axis.text.y = ggplot2::element_blank()) +
      ggplot2::labs(x = "Time", y = "Students", fill = "Emotion")
  })

  # D6: Persistent Struggle Alert
  output$lecturer_d6_struggle <- DT::renderDataTable({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(data.frame())

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id)
    if (nrow(recent) == 0) return(data.frame())

    struggle <- recent |>
      dplyr::arrange(.data$student_id, .data$timestamp) |>
      dplyr::group_by(.data$student_id) |>
      dplyr::mutate(
        is_struggling = .data$emotion %in% c("Confused", "Frustrated"),
        streak        = cumsum(!.data$is_struggling),
        consecutive   = ave(as.numeric(.data$is_struggling),
                            .data$student_id, .data$streak, FUN = cumsum)
      ) |>
      dplyr::filter(.data$consecutive >= 3) |>
      dplyr::slice_tail(n = 1) |>
      dplyr::ungroup() |>
      dplyr::select(.data$student_id, .data$emotion, .data$consecutive) |>
      dplyr::arrange(dplyr::desc(.data$consecutive))

    DT::datatable(struggle, options = list(pageLength = 10))
  })

  # D7: Peak Confusion Moment
  output$lecturer_d7_peak <- shiny::renderUI({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(shiny::div("No data"))

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id)
    if (nrow(recent) == 0) return(shiny::div("No data"))

    peak <- recent |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "2 minutes")) |>
      dplyr::group_by(.data$time_bucket) |>
      dplyr::summarise(
        confused_pct = mean(.data$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::slice_max(.data$confused_pct, n = 1)

    if (nrow(peak) == 0) return(shiny::div("No data"))

    shiny::div(
      class = "alert alert-info",
      shiny::strong("Peak confusion at:"),
      format(peak$time_bucket[1], "%I:%M %p"),
      shiny::br(),
      sprintf("%.0f%% Confused/Frustrated", peak$confused_pct[1] * 100)
    )
  })

  # Confusion Spike Observer — Gemini alert
  confusion_alerted <- shiny::reactiveVal(FALSE)

  shiny::observe({
    live_reactive()
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return()

    recent <- emotions |>
      dplyr::filter(.data$lecture_id == lecture_id) |>
      tail(120)
    confusion_rate <- mean(
      recent$emotion %in% c("Confused", "Frustrated"),
      na.rm = TRUE
    )

    if (confusion_rate < 0.40) {
      confusion_alerted(FALSE)
      return()
    }
    if (isTRUE(confusion_alerted())) return()
    confusion_alerted(TRUE)

    question <- tryCatch({
      result <- httr2::request(paste0(FASTAPI_BASE, "/gemini/question")) |>
        httr2::req_url_query(lecture_id = lecture_id) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
      result$question %||% "Can you clarify the key concept we just covered?"
    }, error = function(e) {
      "Can you clarify the key concept we just covered?"
    })

    shinyalert::shinyalert(
      title    = sprintf("\u26a0 Class Confused (%.0f%%)", confusion_rate * 100),
      text     = paste0("Suggested question:\n\n", question),
      type     = "warning",
      showCancelButton  = TRUE,
      confirmButtonText = "Ask It",
      cancelButtonText  = "Dismiss",
      callbackR = function(confirmed) {
        if (!isTRUE(confirmed)) return()
        tryCatch({
          httr2::request(paste0(FASTAPI_BASE, "/session/broadcast")) |>
            httr2::req_body_json(list(
              type       = "freshbrainer",
              question   = question,
              lecture_id = lecture_id
            )) |>
            httr2::req_perform()
        }, error = function(e) NULL)
      }
    )
  })

  # ========================================================================
  # Submodule E: Student Reports
  # ========================================================================

  shiny::observe({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return()

    # Build choices from students that appear in emotion data
    name_col <- if ("name" %in% names(emotions)) "name" else "student_id"
    students <- emotions |>
      dplyr::select(dplyr::all_of(c("student_id", name_col))) |>
      dplyr::distinct() |>
      dplyr::arrange(.data[[name_col]])

    choices <- students$student_id
    names(choices) <- paste0(students[[name_col]], " (", students$student_id, ")")

    shiny::updateSelectInput(session, "lecturer_student_select", choices = choices)
  })

  output$lecturer_student_trend <- plotly::renderPlotly({
    req(input$lecturer_student_select)
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly())

    student_data <- emotions |>
      dplyr::filter(.data$student_id == input$lecturer_student_select) |>
      dplyr::arrange(.data$timestamp)
    if (nrow(student_data) == 0) return(plotly::plot_ly())

    plotly::plot_ly(student_data, x = ~timestamp, y = ~engagement_score,
                   type = "scatter", mode = "lines+markers",
                   line   = list(color = AAST_NAVY),
                   marker = list(color = AAST_GOLD)) |>
      plotly::layout(yaxis = list(range = c(0, 1), title = "Engagement Score"))
  })

  output$lecturer_student_emotions <- plotly::renderPlotly({
    req(input$lecturer_student_select)
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly())

    emotion_counts <- emotions |>
      dplyr::filter(.data$student_id == input$lecturer_student_select) |>
      dplyr::group_by(.data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop")

    plotly::plot_ly(emotion_counts, x = ~emotion, y = ~count, type = "bar",
                   marker = list(color = AAST_NAVY))
  })

  output$lecturer_student_load <- plotly::renderPlotly({
    req(input$lecturer_student_select)
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly())

    load_data <- emotions |>
      dplyr::filter(.data$student_id == input$lecturer_student_select) |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "5 minutes")) |>
      dplyr::group_by(.data$time_bucket) |>
      dplyr::summarise(
        cognitive_load = mean(.data$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE),
        .groups = "drop"
      )

    if (nrow(load_data) == 0) return(plotly::plot_ly())

    plotly::plot_ly(load_data, x = ~time_bucket, y = ~cognitive_load,
                   type = "scatter", mode = "lines+markers",
                   line = list(color = "orange")) |>
      plotly::layout(yaxis = list(range = c(0, 1), title = "Cognitive Load"))
  })

  output$lecturer_student_plan_ui <- shiny::renderUI({
    req(input$lecturer_student_select)
    result <- tryCatch({
      api_call(paste0("/notes/", input$lecturer_student_select, "/plan"))
    }, error = function(e) NULL)

    if (is.null(result) || is.null(result$plan)) {
      return(shiny::div(class = "alert alert-info",
                        "No AI plan available yet for this student."))
    }
    shiny::div(class = "card p-3", shiny::markdown(result$plan))
  })

  output$lecturer_student_pdf <- shiny::downloadHandler(
    filename = function() {
      paste0("student_report_", input$lecturer_student_select, "_", Sys.Date(), ".pdf")
    },
    content = function(file) {
      rmarkdown::render(
        "reports/student_report.Rmd",
        output_file = file,
        params = list(student_id = input$lecturer_student_select),
        quiet  = TRUE
      )
    }
  )

  # ========================================================================
  # Class Insights: Server Logic (Ported from Admin)
  # ========================================================================

  # 0. Attendance Log
  output$lecturer_attendance_log_table <- DT::renderDataTable({
    data <- attendance_data()
    if (nrow(data) == 0) return(data.frame())
    data |>
      dplyr::select(.data$student_id, .data$lecture_id, .data$status, .data$method, .data$timestamp) |>
      DT::datatable(options = list(pageLength = 25))
  })

  # 1. Engagement Trend
  output$lecturer_class_engagement_trend <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly() |> plotly::add_text(text = "No data"))

    trend_data <- emotions |>
      dplyr::mutate(week = lubridate::floor_date(.data$timestamp, "week")) |>
      dplyr::group_by(.data$week) |>
      dplyr::summarise(avg_engagement = mean(.data$engagement_score, na.rm = TRUE), .groups = "drop")

    plotly::plot_ly(trend_data, x = ~week, y = ~avg_engagement, type = "scatter", mode = "lines+markers") |>
      plotly::layout(
        xaxis = list(title = "Week"),
        yaxis = list(title = "Avg Engagement Score", range = c(0, 1))
      )
  })

  # 1.5 Course Heatmap
  output$lecturer_course_heatmap <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(NULL)

    heatmap_data <- emotions |>
      dplyr::mutate(
        week          = lubridate::floor_date(.data$timestamp, "week"),
        lecture_group = substr(.data$lecture_id, 1, 2)
      ) |>
      dplyr::group_by(.data$lecture_group, .data$week) |>
      dplyr::summarise(avg_eng = mean(.data$engagement_score, na.rm = TRUE), .groups = "drop")

    ggplot2::ggplot(heatmap_data, ggplot2::aes(x = .data$week, y = .data$lecture_group, fill = .data$avg_eng)) +
      ggplot2::geom_tile() +
      ggplot2::scale_fill_gradient(low = "red", high = "green", limits = c(0, 1)) +
      ggplot2::theme_minimal() +
      ggplot2::labs(y = "Course Group", fill = "Avg Engagement")
  })

  # 2. Emotion Analysis
  output$lecturer_class_emotion_mix <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(NULL)

    emotion_dist <- emotions |>
      dplyr::group_by(.data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::mutate(pct = .data$count / sum(.data$count))

    ggplot2::ggplot(emotion_dist, ggplot2::aes(x = "", y = .data$pct, fill = .data$emotion)) +
      ggplot2::geom_col(width = 1) +
      ggplot2::coord_polar("y", start = 0) +
      ggplot2::scale_fill_manual(values = c(
        "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
        "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
      )) +
      ggplot2::theme_void() +
      ggplot2::labs(title = "Overall Emotion Mix", fill = "Emotion")
  })

  output$lecturer_class_emotion_trend <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly() |> plotly::add_text(text = "No data"))

    emotion_trend <- emotions |>
      dplyr::mutate(week = lubridate::floor_date(.data$timestamp, "week")) |>
      dplyr::group_by(.data$week, .data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::group_by(.data$week) |>
      dplyr::mutate(pct = .data$count / sum(.data$count))

    plotly::plot_ly(emotion_trend, x = ~week, y = ~pct, color = ~emotion,
                    type = 'scatter', mode = 'lines', stackgroup = 'one',
                    colors = c(
                      "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
                      "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
                    )) |>
      plotly::layout(
        xaxis = list(title = "Week"),
        yaxis = list(title = "Proportion", range = c(0, 1))
      )
  })

  # 3. Performance Clusters
  output$lecturer_student_clusters <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly() |> plotly::add_text(text = "No data"))

    clustered <- cluster_student_behavior(emotions, k = min(3, length(unique(emotions$student_id))))
    if (nrow(clustered) == 0) return(plotly::plot_ly() |> plotly::add_text(text = "Insufficient data"))

    plotly::plot_ly(clustered, x = ~avg_engagement_score, y = ~avg_confused, color = ~cluster_label,
                    text = ~paste("Student:", student_id),
                    mode = "markers", marker = list(size = 12)) |>
      plotly::layout(
        xaxis = list(title = "Avg Engagement Score"),
        yaxis = list(title = "Avg Confusion Rate")
      )
  })

  # 4. At-Risk Students
  output$lecturer_at_risk_table <- DT::renderDataTable({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(data.frame())

    eng_metrics <- compute_engagement(emotions)$by_lecture |>
      dplyr::arrange(.data$student_id, .data$lecture_id)

    at_risk <- eng_metrics |>
      dplyr::group_by(.data$student_id) |>
      dplyr::mutate(
        lag_score  = dplyr::lag(.data$engagement_score),
        drop       = .data$lag_score - .data$engagement_score,
        is_drop    = !is.na(.data$drop) & .data$drop > 0.20,
        streak_id  = cumsum(!.data$is_drop),
        consec_run = ave(as.integer(.data$is_drop), .data$student_id, .data$streak_id, FUN = cumsum)
      ) |>
      dplyr::filter(.data$consec_run >= 3) |>
      dplyr::slice_tail(n = 1) |>
      dplyr::ungroup() |>
      dplyr::select(
        `Student ID` = .data$student_id,
        `Engagement Score` = .data$engagement_score,
        Drop = .data$drop,
        `Latest Lecture` = .data$lecture_id,
        Streak = .data$consec_run
      )

    DT::datatable(at_risk, options = list(pageLength = 10))
  })

  # 5. Effectiveness (LES)
  output$lecturer_les_table <- DT::renderDataTable({
    emotions <- emotions_data()
    attendance <- attendance_data()
    if (nrow(emotions) == 0 || nrow(attendance) == 0) return(data.frame())

    eng_metrics <- compute_engagement(emotions)$by_lecture
    att_metrics <- attendance |>
      dplyr::mutate(present = .data$status == "Present") |>
      dplyr::group_by(.data$lecture_id) |>
      dplyr::summarise(attendance_rate = mean(.data$present, na.rm = TRUE), .groups = "drop")

    les_data <- eng_metrics |>
      dplyr::left_join(att_metrics, by = "lecture_id") |>
      dplyr::mutate(
        LES = 0.5 * .data$engagement_score + 0.3 * (1 - .data$confusion_rate) + 0.2 * .data$attendance_rate,
        Category = dplyr::if_else(.data$LES >= 0.7, "Excellent", dplyr::if_else(.data$LES >= 0.5, "Good", "Needs Improvement"))
      ) |>
      dplyr::arrange(dplyr::desc(.data$LES)) |>
      dplyr::select(`Lecture ID` = .data$lecture_id, `Engagement` = .data$engagement_score, 
                    `Confusion` = .data$confusion_rate, `Attendance` = .data$attendance_rate, LES, Category)

    DT::datatable(les_data, options = list(pageLength = 10))
  })

  # 6. Time-of-Day Heatmap
  output$lecturer_tod_heatmap <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(NULL)

    tod_data <- emotions |>
      dplyr::mutate(
        hour = lubridate::hour(.data$timestamp),
        weekday = lubridate::wday(.data$timestamp, label = TRUE)
      ) |>
      dplyr::group_by(.data$weekday, .data$hour) |>
      dplyr::summarise(avg_eng = mean(.data$engagement_score, na.rm = TRUE), .groups = "drop")

    ggplot2::ggplot(tod_data, ggplot2::aes(x = .data$hour, y = .data$weekday, fill = .data$avg_eng)) +
      ggplot2::geom_tile() +
      ggplot2::scale_fill_gradient(low = "red", high = "green", limits = c(0, 1)) +
      ggplot2::theme_minimal() +
      ggplot2::labs(x = "Hour", y = "Weekday", fill = "Avg Engagement")
  })

  # 7. Exam Incidents
  output$lecturer_incidents_table <- DT::renderDataTable({
    data <- incidents_data()
    if (nrow(data) == 0) return(data.frame())

    data <- data |>
      dplyr::mutate(
        evidence = ifelse(is.na(.data$evidence_path) | .data$evidence_path == "",
                         "No Photo",
                         sprintf('<a href="%s/attendance/evidence/%s" target="_blank">View Photo</a>',
                                 FASTAPI_BASE, basename(.data$evidence_path)))
      ) |>
      dplyr::select(`Student ID` = .data$student_id, `Exam ID` = .data$exam_id, 
                    `Type` = .data$flag_type, Severity = .data$severity, Timestamp = .data$timestamp, evidence)

    DT::datatable(data, escape = FALSE, options = list(pageLength = 25))
  })
}
