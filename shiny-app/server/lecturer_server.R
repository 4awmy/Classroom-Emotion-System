# lecturer_server.R - Server logic for 5 lecturer submodules

lecturer_server <- function(input, output, session, session_state) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # Reactive data: Fetch real classes for this lecturer from DB
  lecturer_courses_data <- shiny::reactive({
    uid <- session_state$user_id
    if (is.null(uid)) return(data.frame())
    
    query <- sprintf("SELECT co.title as course, co.course_id as code, cl.class_id as class, 'N/A' as day, 'N/A' as slots 
                      FROM classes cl 
                      JOIN courses co ON cl.course_id = co.course_id 
                      WHERE cl.lecturer_id = '%s'", uid)
    
    db_url <- Sys.getenv("DATABASE_URL", "")
    if (db_url == "") return(data.frame())
    
    tryCatch({
      con <- dbConnect(RPostgres::Postgres(), url = db_url)
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      return(res)
    }, error = function(e) {
      return(data.frame())
    })
  })

  # Reactive data - accelerated for Live Dashboard
  emotions_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    query_table("emotions")
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    query_table("attendance")
  })

  incidents_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    query_table("incidents")
  })

  # ========================================================================
  # Submodule A: Roster Setup
  # ========================================================================

  shiny::observeEvent(input$lecturer_roster_upload, {
    req(input$lecturer_roster_xlsx)

    file_info <- input$lecturer_roster_xlsx

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/roster/upload")) |>
        httr2::req_body_multipart(
          roster_xlsx = curl::form_file(
            file_info$datapath,
            type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          )
        ) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      shinyalert::shinyalert("Upload Failed", as.character(e), type = "error")
      NULL
    })

    if (!is.null(result)) {
      output$lecturer_roster_status <- shiny::renderUI({
        shiny::div(
          class = "alert alert-success",
          sprintf("✓ Upload complete: %d students created, %d face encodings saved",
                  result$students_created %||% 0, result$encodings_saved %||% 0)
        )
      })
    }
  })

  # ========================================================================
  # Submodule B: Material Upload
  # ========================================================================

  output$lecturer_materials_table <- DT::renderDataTable({
    materials <- load_csv("../python-api/data/exports/materials.csv")
    if (nrow(materials) == 0) return(data.frame())
    DT::datatable(
      materials |> dplyr::select(dplyr::any_of(c("title", "lecture_id", "lecturer_id", "uploaded_at"))),
      options = list(pageLength = 10)
    )
  })

  shiny::observeEvent(input$lecturer_material_upload, {
    req(input$lecturer_material_file, input$lecturer_lecture_select,
        input$lecturer_material_title)

    file_info <- input$lecturer_material_file

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/upload/material")) |>
        httr2::req_body_multipart(
          lecture_id  = input$lecturer_lecture_select,
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
  selected_attendance_course <- shiny::reactiveVal(list(
    course = "Big data Analytics",
    code = "CIS4103",
    class = "D",
    day = "Sunday",
    slots = "9 => 10"
  ))

  format_week_lecture_id <- function(week, class_key) {
    week_num <- suppressWarnings(as.integer(week))
    if (is.na(week_num) || week_num < 1) week_num <- 1
    safe_class_key <- gsub("[^A-Za-z0-9_-]+", "-", trimws(as.character(class_key)))
    paste0(sprintf("W%02d", week_num), "-", safe_class_key)
  }

  course_class_key <- function(row) {
    if (is.null(row$code) || is.null(row$class)) return("")
    paste(row$code, row$class, sep = "-")
  }

  # Helper: resolve lecture_id from selected course/class and academic week.
  get_attendance_lecture_id <- function() {
    selected <- selected_attendance_course()
    class_key <- course_class_key(selected)
    if (nchar(class_key) == 0) return("")
    format_week_lecture_id(input$lecturer_attendance_week %||% 1, class_key)
  }

  output$lecturer_selected_course_title <- shiny::renderUI({
    selected <- selected_attendance_course()
    shiny::div(
      class = "selected-course-title",
      shiny::span(class = "selected-course-kicker", "Selected Session"),
      shiny::strong(sprintf("%s | %s | Class %s", selected$course, selected$code, selected$class)),
      shiny::span(sprintf("Week %s | %s, %s | %s",
                          input$lecturer_attendance_week %||% 1,
                          selected$day,
                          selected$slots,
                          get_attendance_lecture_id()))
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

  output$lecturer_course_table <- shiny::renderUI({
    selected <- selected_attendance_course()
    lecturer_attendance_course_table(
      courses_df = lecturer_courses_data(),
      selected_code = selected$code,
      selected_class = selected$class
    )
  })

  shiny::observeEvent(input$lecturer_course_nav, {
    nav <- input$lecturer_course_nav
    row_index <- suppressWarnings(as.integer(nav$row))
    destination <- nav$dest
    
    courses_df <- lecturer_courses_data()

    if (is.na(row_index) || row_index < 1 || row_index > nrow(courses_df)) {
      return()
    }

    selected_attendance_course(as.list(courses_df[row_index, ]))

    if (identical(destination, "students")) {
      refresh_attendance()
      shinydashboard::updateTabItems(session, "lecturer_menu", selected = "lec_attendance_students")
    } else {
      refresh_attendance()
      generate_attendance_qr()
      shinydashboard::updateTabItems(session, "lecturer_menu", selected = "lec_attendance_qr")
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$lecturer_back_to_courses_from_students, {
    shinydashboard::updateTabItems(session, "lecturer_menu", selected = "lec_attendance")
  })

  shiny::observeEvent(input$lecturer_back_to_courses_from_qr, {
    shinydashboard::updateTabItems(session, "lecturer_menu", selected = "lec_attendance")
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

    camera_section <- shiny::div(
      class = "camera-attendance-section",
      style = "background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:16px; margin-bottom:20px;",
      shiny::h4(shiny::icon("camera"), " AI Camera Attendance",
                style = "margin-top:0; color:#002147;"),
      shiny::p("Point your webcam at the class then click Capture — all recognised students are marked Present automatically.",
               style = "color:#555; margin-bottom:12px;"),
      shiny::div(
        style = "display:flex; gap:16px; align-items:flex-start; flex-wrap:wrap;",
        shiny::tags$video(
          id = "attendanceCam", autoplay = NA, playsinline = NA,
          style = "width:320px; height:240px; background:#000; border-radius:6px; object-fit:cover;"
        ),
        shiny::div(
          style = "display:flex; flex-direction:column; gap:8px; min-width:160px;",
          shiny::tags$button(type = "button", class = "btn btn-info btn-block",
            onclick = "startAttendanceCam()", shiny::icon("video"), " Start Camera"),
          shiny::tags$button(type = "button", class = "btn btn-primary btn-block",
            onclick = "captureAttendanceFrame()", shiny::icon("camera"), " Capture & Process"),
          shiny::uiOutput("cam_attendance_result")
        )
      ),
      shiny::tags$canvas(id = "attendanceCanvas", style = "display:none;"),
      shiny::tags$script(shiny::HTML("
        var _camStream = null;
        function startAttendanceCam() {
          if (_camStream) return;
          navigator.mediaDevices.getUserMedia({video: true})
            .then(function(s){ _camStream = s; document.getElementById('attendanceCam').srcObject = s; })
            .catch(function(e){ alert('Camera: ' + e.message); });
        }
        function captureAttendanceFrame() {
          var v = document.getElementById('attendanceCam');
          if (!v.srcObject) { alert('Start camera first.'); return; }
          var c = document.getElementById('attendanceCanvas');
          c.width = v.videoWidth || 640; c.height = v.videoHeight || 480;
          c.getContext('2d').drawImage(v, 0, 0);
          Shiny.setInputValue('cam_frame', c.toDataURL('image/jpeg', 0.85), {priority:'event'});
        }
      "))
    )

    if (length(students) == 0) {
      return(shiny::tagList(
        camera_section,
        shiny::div(class = "alert alert-info", "No students found. Upload a roster first.")
      ))
    }

    shiny::tagList(
      camera_section,
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
    )   # closes shiny::div(class = "attendance-grid",
  )     # closes shiny::tagList(
  })

  shiny::observe({
    attendance_data()
    refresh_attendance()
  })

  shiny::observeEvent(input$lecturer_attendance_week, {
    attendance_qr_base64(NULL)
    refresh_attendance()
  }, ignoreInit = TRUE)

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

  # ── Camera frame: send to DO backend for face recognition ─────────────────
  output$cam_attendance_result <- shiny::renderUI({ shiny::div() })

  shiny::observeEvent(input$cam_frame, {
    frame_data  <- input$cam_frame
    lecture_id  <- get_attendance_lecture_id()

    if (nchar(lecture_id) == 0) {
      shinyalert::shinyalert("No Lecture", "Select a course and week first.", type = "warning")
      return()
    }

    # Decode base64 image and write to temp JPEG
    b64      <- sub("^data:image/[^;]+;base64,", "", frame_data)
    img_raw  <- base64enc::base64decode(b64)
    tmp_jpg  <- tempfile(fileext = ".jpg")
    writeBin(img_raw, tmp_jpg)
    on.exit(unlink(tmp_jpg), add = TRUE)

    # POST to cloud vision endpoint
    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/vision/process-frame")) |>
        httr2::req_body_multipart(
          image      = curl::form_file(tmp_jpg, type = "image/jpeg"),
          lecture_id = lecture_id
        ) |>
        httr2::req_timeout(30) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      shinyalert::shinyalert("Error", as.character(e$message), type = "error")
      NULL
    })

    if (is.null(result)) return()

    if (!is.null(result$detail)) {
      shinyalert::shinyalert("Backend Error", as.character(result$detail), type = "error")
      return()
    }

    detected <- result$detected
    n        <- length(detected)

    if (n == 0) {
      output$cam_attendance_result <- shiny::renderUI({
        shiny::div(class = "alert alert-info", style = "margin-top:8px;",
                   "No enrolled students recognised.")
      })
      return()
    }

    # Flip the manual toggles for recognised students
    for (s in detected) {
      shinyWidgets::updateMaterialSwitch(session, paste0("att_", s$student_id), value = TRUE)
    }

    names_str <- paste(sapply(detected, `[[`, "name"), collapse = ", ")
    output$cam_attendance_result <- shiny::renderUI({
      shiny::div(
        class = "alert alert-success", style = "margin-top:8px;",
        shiny::strong(sprintf("%d student(s) detected:", n)), shiny::br(),
        names_str
      )
    })
  })

  # QR code
  shiny::observeEvent(input$lecturer_qr_generate, {
    generate_attendance_qr()
  })

  # ── Camera frame → cloud vision ────────────────────────────────────────────
  output$cam_attendance_result <- shiny::renderUI({ shiny::div() })

  shiny::observeEvent(input$cam_frame, {
    lecture_id <- get_attendance_lecture_id()
    if (nchar(lecture_id) == 0) {
      shinyalert::shinyalert("No Lecture", "Select a course first.", type = "warning")
      return()
    }

    b64     <- sub("^data:image/[^;]+;base64,", "", input$cam_frame)
    tmp_jpg <- tempfile(fileext = ".jpg")
    writeBin(base64enc::base64decode(b64), tmp_jpg)
    on.exit(unlink(tmp_jpg), add = TRUE)

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/vision/process-frame")) |>
        httr2::req_body_multipart(
          image      = curl::form_file(tmp_jpg, type = "image/jpeg"),
          lecture_id = lecture_id
        ) |>
        httr2::req_timeout(30) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      shinyalert::shinyalert("Error", as.character(e$message), type = "error")
      NULL
    })

    if (is.null(result)) return()
    if (!is.null(result$detail)) {
      shinyalert::shinyalert("Backend Error", as.character(result$detail), type = "error")
      return()
    }

    detected <- result$detected
    n        <- length(detected)

    if (n == 0) {
      output$cam_attendance_result <- shiny::renderUI(
        shiny::div(class = "alert alert-info", style = "margin-top:8px;",
                   "No enrolled students recognised.")
      )
      return()
    }

    for (s in detected) {
      shinyWidgets::updateMaterialSwitch(session, paste0("att_", s$student_id), value = TRUE)
    }

    names_str <- paste(sapply(detected, `[[`, "name"), collapse = ", ")
    output$cam_attendance_result <- shiny::renderUI(
      shiny::div(class = "alert alert-success", style = "margin-top:8px;",
                 shiny::strong(sprintf("%d detected:", n)), shiny::br(), names_str)
    )
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
  # Uses selected class + week to generate lecture_id.
  # ========================================================================

  live_reactive <- shiny::reactiveTimer(2000)
  live_session_status <- shiny::reactiveVal(list(status = "not_started", exists = FALSE))

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
      paste0("run_classroom_ai_", get_live_lecture_id() %||% "L1", ".ps1")
    },
    content = function(file) {
      lecture_id <- get_live_lecture_id() %||% "L1"
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

  output$lecturer_live_class_ui <- shiny::renderUI({
    courses_df <- lecturer_courses_data()
    if (is.null(courses_df) || nrow(courses_df) == 0) {
      return(shiny::selectInput("lecturer_live_class", "Class", choices = c("No classes available" = "")))
    }

    values <- apply(courses_df, 1, function(row) paste(row[["code"]], row[["class"]], sep = "-"))
    labels <- apply(courses_df, 1, function(row) {
      sprintf("%s | %s | Class %s", row[["course"]], row[["code"]], row[["class"]])
    })
    shiny::selectInput("lecturer_live_class", "Class", choices = stats::setNames(values, labels))
  })

  get_live_lecture_id <- function() {
    class_key <- input$lecturer_live_class
    if (is.null(class_key) || nchar(trimws(class_key)) == 0) return(NULL)
    format_week_lecture_id(input$lecturer_live_week %||% 1, class_key)
  }

  get_live_class_id <- function() {
    class_key <- input$lecturer_live_class
    if (is.null(class_key) || nchar(trimws(class_key)) == 0) return(NULL)
    sub("^[^-]+-", "", trimws(class_key))
  }

  get_live_course_row <- function() {
    class_key <- input$lecturer_live_class
    courses_df <- lecturer_courses_data()
    if (is.null(class_key) || nchar(trimws(class_key)) == 0 || nrow(courses_df) == 0) return(NULL)
    values <- apply(courses_df, 1, function(row) paste(row[["code"]], row[["class"]], sep = "-"))
    match_idx <- which(values == class_key)
    if (length(match_idx) == 0) return(NULL)
    as.list(courses_df[match_idx[1], ])
  }

  refresh_live_session_status <- function() {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) {
      live_session_status(list(status = "not_started", exists = FALSE))
      return(invisible(NULL))
    }
    res <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/session/status/", lecture_id)) |>
        httr2::req_error(is_error = \(resp) FALSE) |>
        httr2::req_timeout(5) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)
    if (!is.null(res)) live_session_status(res)
    invisible(res)
  }

  shiny::observe({
    live_reactive()
    refresh_live_session_status()
  })

  output$lecturer_live_lecture_id <- shiny::renderText({
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) "Lecture ID: select a class"
    else paste("Lecture ID:", lecture_id)
  })

  output$lecturer_live_status_text <- shiny::renderText({
    status <- live_session_status()$status %||% "not_started"
    label <- switch(status,
      live = "Status: Live",
      ended = "Status: Ended",
      "Status: Not started"
    )
    label
  })

  output$lecturer_live_session_actions <- shiny::renderUI({
    status <- live_session_status()$status %||% "not_started"
    if (identical(status, "live")) {
      return(shiny::tagList(
        actionButton("lecturer_live_end", "End Session", class = "btn-danger btn-block", icon = icon("stop"))
      ))
    }
    if (identical(status, "ended")) {
      return(shiny::tagList(
        actionButton("lecturer_live_attendance_review", "Attendance Review", class = "btn-info btn-block", icon = icon("clipboard-list")),
        br(),
        actionButton("lecturer_live_reset", "Reset Lecture", class = "btn-warning btn-block", icon = icon("rotate-left"))
      ))
    }
    shiny::tagList(
      actionButton("lecturer_live_start", "Start Session", class = "btn-success btn-block", icon = icon("play"))
    )
  })

  output$lecturer_live_custom_cam_ui <- shiny::renderUI({
    if (input$lecturer_live_camera == "custom") {
      textInput("lecturer_live_custom_cam", "Custom URL (RTSP/HTTP)", placeholder = "rtsp://...")
    }
  })

  output$lecturer_live_stream_ui <- shiny::renderUI({
    # Static render of stream URL - browser handles the MJPEG flow
    lecture_id <- get_live_lecture_id()
    status <- live_session_status()$status %||% "not_started"
    if (is.null(lecture_id)) {
      return(shiny::div(
        style = "color:#fff;padding:170px 20px;",
        "Select a class and week, then start the lecture."
      ))
    }

    if (identical(status, "ended")) {
      return(shiny::div(
        style = "color:#fff;padding:150px 20px;",
        shiny::h4("Lecture ended"),
        shiny::p(sprintf(
          "Final records: %s attendance, %s emotion logs, %s AI checks.",
          live_session_status()$attendance_count %||% 0,
          live_session_status()$emotion_count %||% 0,
          live_session_status()$check_count %||% 0
        ))
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
      shinyalert::shinyalert("Error", "Select a class first.", type = "error")
      return()
    }

    cam_url <- if (input$lecturer_live_camera == "custom") {
      input$lecturer_live_custom_cam
    } else {
      input$lecturer_live_camera
    }

    if (is.null(cam_url) || nchar(trimws(cam_url)) == 0) cam_url <- "0"

    result <- api_call("/session/start", method = "POST", body = list(
      lecture_id  = lecture_id,
      lecturer_id = "LECTURER_1",
      class_id    = get_live_class_id(),
      title       = paste("Week", input$lecturer_live_week %||% 1, "Lecture", input$lecturer_live_class),
      camera_url  = trimws(cam_url)
    ))

    if (!is.null(result)) {
      refresh_live_session_status()
      shinyalert::shinyalert("Lecture Started",
                             paste("Lecture", lecture_id, "is now live using camera:", cam_url), type = "success")
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
    refresh_live_session_status()
    shinyalert::shinyalert("Lecture Ended", "", type = "info")
  })

  shiny::observeEvent(input$lecturer_live_attendance_review, {
    selected <- get_live_course_row()
    if (is.null(selected)) {
      shinyalert::shinyalert("No Class", "Select a class first.", type = "warning")
      return()
    }
    selected_attendance_course(selected)
    shiny::updateSelectInput(session, "lecturer_attendance_week", selected = input$lecturer_live_week %||% 1)
    refresh_attendance()
    shinydashboard::updateTabItems(session, "lecturer_menu", selected = "lec_attendance_students")
  })

  shiny::observeEvent(input$lecturer_live_reset, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) return()

    shinyalert::shinyalert(
      title = "Reset Lecture?",
      text = paste("This deletes attendance, emotion analytics, snapshots, and AI checks for", lecture_id, "only."),
      type = "warning",
      showCancelButton = TRUE,
      confirmButtonText = "Reset",
      callbackR = function(confirmed) {
        if (!isTRUE(confirmed)) return()
        res <- api_call("/session/reset", method = "POST", body = list(lecture_id = lecture_id))
        if (!is.null(res)) {
          live_session_status(res)
          attendance_qr_base64(NULL)
          refresh_attendance()
          shinyalert::shinyalert("Lecture Reset", paste(lecture_id, "is ready to start again."), type = "success")
        }
      }
    )
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

  # --- AI Intervention Handlers ---

  # 1. Refresher Logic
  shiny::observeEvent(input$lecturer_trigger_refresher, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) return()
    
    shiny::showNotification("AI is generating refresher...", type = "message")
    
    res <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/gemini/refresher")) |>
        httr2::req_url_query(lecture_id = lecture_id) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)
    
    if (is.null(res)) {
       shinyalert::shinyalert("Error", "Could not generate refresher.", type="error")
       return()
    }
    
    shinyalert::shinyalert(
      title = "Accept AI Refresher?",
      text = res$summary,
      type = "info",
      showCancelButton = TRUE,
      confirmButtonText = "Push to Students",
      callbackR = function(confirmed) {
        if (!isTRUE(confirmed)) return()
        tryCatch({
          httr2::request(paste0(FASTAPI_BASE, "/gemini/intervention/push")) |>
            httr2::req_url_query(lecture_id = lecture_id, content = res$summary) |>
            httr2::req_method("POST") |>
            httr2::req_perform()
          shiny::showNotification("Refresher pushed!", type = "message")
        }, error = function(e) NULL)
      }
    )
  })

  # 2. Comprehension Check Logic
  shiny::observeEvent(input$lecturer_trigger_check, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) return()
    
    shiny::showNotification("AI is generating quiz...", type = "message")
    
    res <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/gemini/check/generate")) |>
        httr2::req_url_query(lecture_id = lecture_id) |>
        httr2::req_method("POST") |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)
    
    if (is.null(res)) {
       shinyalert::shinyalert("Error", "Could not generate quiz.", type="error")
       return()
    }
    
    shinyalert::shinyalert(
      title = "Accept AI Quiz?",
      text = paste0("Q: ", res$question, "\n\nOptions: ", paste(res$options, collapse=", ")),
      type = "info",
      showCancelButton = TRUE,
      confirmButtonText = "Push Quiz",
      callbackR = function(confirmed) {
        if (!isTRUE(confirmed)) return()
        tryCatch({
          httr2::request(paste0(FASTAPI_BASE, "/session/broadcast")) |>
            httr2::req_body_json(list(
              type = "comprehension_check",
              check_id = res$id,
              question = res$question,
              options = res$options,
              lecture_id = lecture_id
            )) |>
            httr2::req_perform()
          shiny::showNotification("Quiz pushed!", type = "message")
        }, error = function(e) NULL)
      }
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
      text     = paste0("Suggested 'Fresh Brainer':\n\n", question),
      type     = "warning",
      showCancelButton  = TRUE,
      confirmButtonText = "Push to Students",
      cancelButtonText  = "Dismiss",
      callbackR = function(confirmed) {
        if (!isTRUE(confirmed)) return()
        tryCatch({
          httr2::request(paste0(FASTAPI_BASE, "/gemini/intervention/push")) |>
            httr2::req_url_query(lecture_id = lecture_id, content = question) |>
            httr2::req_method("POST") |>
            httr2::req_perform()
          shiny::showNotification("Fresh Brainer pushed!", type = "message")
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
