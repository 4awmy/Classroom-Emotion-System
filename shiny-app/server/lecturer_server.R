# lecturer_server.R - Server logic for 5 lecturer submodules
# Fully migrated to Supabase PostgreSQL with null-safety

lecturer_server <- function(input, output, session) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # Helper: Null-safe Database Query
  # ========================================================================
  safe_query <- function(sql) {
    if (is.null(con)) {
      message("WARN: Attempted to query database without active connection.")
      return(data.frame())
    }
    tryCatch({
      dbGetQuery(con, sql)
    }, error = function(e) {
      message("DB Error: ", e$message)
      data.frame()
    })
  }

  # Reactive data - accelerated for Live Dashboard
  emotions_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    safe_query("SELECT * FROM emotion_log")
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    safe_query("SELECT * FROM attendance_log")
  })

  incidents_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    safe_query("SELECT * FROM incidents")
  })

  # ========================================================================
  # Submodule B: Material Upload
  # ========================================================================

  output$lecturer_materials_table <- DT::renderDataTable({
    materials <- safe_query("SELECT * FROM materials")
    if (nrow(materials) == 0) return(data.frame())
    DT::datatable(
      materials |> dplyr::select(dplyr::any_of(c("title", "lecture_id", "lecturer_id", "uploaded_at"))),
      options = list(pageLength = 10)
    )
  })

  # ========================================================================
  # Submodule C: Attendance (Photo Card Grid)
  # ========================================================================

  attendance_list <- shiny::reactiveVal(list())

  get_attendance_lecture_id <- function() {
    lid <- input$lecturer_attendance_lecture
    if (is.null(lid) || nchar(trimws(lid)) == 0) return("")
    trimws(lid)
  }

  refresh_attendance <- function() {
    students <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/admin/students")) |> # Updated to new endpoint
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
      return(shiny::div(class = "alert alert-info", "No students found. Use Student Management to add them."))
    }

    shiny::div(class = "attendance-grid",
      lapply(students, function(s) {
        status_class <- if (s$status == "Present") "present" else "absent"
        snapshot_url <- if (nchar(lecture_id) > 0) {
          paste0(FASTAPI_BASE, "/attendance/snapshot/", lecture_id, "/", s$student_id)
        } else { "" }

        latest_eng <- if (nrow(emotions) > 0) {
          emotions |>
            dplyr::filter(.data$student_id == s$student_id) |>
            dplyr::arrange(dplyr::desc(.data$timestamp)) |>
            dplyr::slice(1) |>
            dplyr::pull(.data$engagement_score)
        } else { numeric(0) }

        eng_display <- if (length(latest_eng) > 0 && !is.na(latest_eng)) {
          sprintf("%.0f%%", latest_eng * 100)
        } else { "N/A" }

        eng_class <- if (length(latest_eng) > 0 && !is.na(latest_eng)) {
          if (latest_eng >= 0.75) "confidence-high"
          else if (latest_eng >= 0.45) "confidence-med"
          else "confidence-low"
        } else ""

        shiny::div(class = paste("student-card", status_class),
          if (nchar(snapshot_url) > 0) {
            shiny::tags$img(src = snapshot_url, class = "student-photo", onerror = "this.style.display='none'")
          } else {
            shiny::div(style = "width:110px;height:110px;border-radius:50%;background:#e0e0e0;margin:0 auto 15px;display:flex;align-items:center;justify-content:center;",
                       shiny::icon("user", style = "font-size:3rem;color:#aaa;"))
          },
          shiny::div(class = "student-id", s$student_id),
          shiny::div(class = "student-name", s$name),
          shiny::div(class = "confidence-rate-label", "Engagement: ", shiny::span(class = eng_class, eng_display)),
          shiny::div(class = "card-actions",
            shinyWidgets::materialSwitch(
              inputId = paste0("att_", s$student_id),
              label   = if (s$status == "Present") "Present" else "Absent",
              value   = (s$status == "Present"),
              status  = "success"
            ))
        )
      })
    )
  })

  shiny::observe({
    attendance_data()
    refresh_attendance()
  })

  # ========================================================================
  # Submodule D: Live Dashboard
  # ========================================================================

  get_live_lecture_id <- function() {
    lid <- input$lecturer_live_lecture
    if (is.null(lid) || nchar(trimws(lid)) == 0) return(NULL)
    trimws(lid)
  }

  output$lecturer_live_stream_ui <- shiny::renderUI({
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) {
      return(shiny::div(style = "color:#fff;padding:170px 20px;", "Enter a Lecture ID and start the lecture."))
    }
    shiny::tags$img(src = paste0(FASTAPI_BASE, "/session/video_feed/", lecture_id),
                    style = "max-width:100%;width:100%;height:auto;display:block;",
                    onerror = "this.style.display='none';")
  })

  # D1: Engagement Gauge
  output$lecturer_d1_gauge <- plotly::renderPlotly({
    emotions <- emotions_data()
    lecture_id <- get_live_lecture_id()
    if (nrow(emotions) == 0 || is.null(lecture_id)) return(plotly::plot_ly())

    recent <- emotions |> dplyr::filter(.data$lecture_id == lecture_id) |> tail(60)
    if (nrow(recent) == 0) return(plotly::plot_ly())

    avg_eng <- mean(recent$engagement_score, na.rm = TRUE)
    plotly::plot_ly(
      type = "indicator", mode = "gauge+number",
      value = round(avg_eng, 2),
      domain = list(x = c(0, 1), y = c(0, 1)),
      gauge = list(axis = list(range = list(0, 1)), bar  = list(color = "#002147"))
    ) |> plotly::layout(margin = list(t = 20, b = 20))
  })

  # ========================================================================
  # Submodule E: Student Reports
  # ========================================================================

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
                   line   = list(color = "#002147"),
                   marker = list(color = "#C9A84C")) |>
      plotly::layout(yaxis = list(range = c(0, 1), title = "Engagement Score"))
  })

  # 7. Exam Incidents
  output$lecturer_incidents_table <- DT::renderDataTable({
    data <- incidents_data()
    if (nrow(data) == 0) return(data.frame())

    data <- data |>
      dplyr::mutate(
        evidence = ifelse(is.na(.data$evidence_path) | .data$evidence_path == "", "No Photo",
                         sprintf('<a href="%s/attendance/evidence/%s" target="_blank">View Photo</a>',
                                 FASTAPI_BASE, basename(.data$evidence_path)))
      ) |>
      dplyr::select(`Student ID` = .data$student_id, `Exam ID` = .data$exam_id, 
                    `Type` = .data$flag_type, Severity = .data$severity, Timestamp = .data$timestamp, evidence)

    DT::datatable(data, escape = FALSE, options = list(pageLength = 25))
  })
}
