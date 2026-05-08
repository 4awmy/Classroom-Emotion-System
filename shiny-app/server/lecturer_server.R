# lecturer_server.R - Server logic for 5 lecturer submodules

lecturer_server <- function(input, output, session) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # Reactive data
  emotions_data <- shiny::reactivePoll(
    intervalMillis = 10000,
    session = session,
    checkFunc = function() {
      get_file_mtime("../python-api/data/exports/emotions.csv")
    },
    valueFunc = function() {
      load_csv("../python-api/data/exports/emotions.csv")
    }
  )

  attendance_data <- shiny::reactivePoll(
    intervalMillis = 10000,
    session = session,
    checkFunc = function() {
      get_file_mtime("../python-api/data/exports/attendance.csv")
    },
    valueFunc = function() {
      load_csv("../python-api/data/exports/attendance.csv")
    }
  )

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
      shinyalert::shinyalert("Upload Failed / فشل التحميل", as.character(e), type = "error")
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
      shinyalert::shinyalert("Success / نجاح", "Material uploaded successfully.", type = "success")
    }
  })

  # ========================================================================
  # Submodule C: Attendance (Photo Card Grid)
  # ========================================================================

  attendance_list <- shiny::reactiveVal(list())

  # Helper: resolve lecture_id from either attendance or live lecture inputs
  get_attendance_lecture_id <- function() {
    lid <- input$lecturer_attendance_lecture
    if (is.null(lid) || nchar(trimws(lid)) == 0) return("")
    trimws(lid)
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
                        "No students found. Upload a roster first. / لا توجد بيانات. قم بتحميل قائمة الطلاب أولاً."))
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
          shiny::div(
            class = "confidence-rate-label",
            "Engagement: ",
            shiny::span(class = eng_class, eng_display)
          ),
          shiny::div(class = "card-actions",
            shinyWidgets::materialSwitch(
              inputId = paste0("att_", s$student_id),
              label   = if (s$status == "Present") "Present / حاضر" else "Absent / غائب",
              value   = (s$status == "Present"),
              status  = "success"
            )
          )
        )
      })
    )
  })

  shiny::observe({
    attendance_data()
    refresh_attendance()
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
      shinyalert::shinyalert("Success / نجاح", "Attendance records updated.", type = "success")
    }
  })

  # QR code
  shiny::observeEvent(input$lecturer_qr_generate, {
    lecture_id <- get_attendance_lecture_id()
    if (nchar(lecture_id) == 0) {
      shinyalert::shinyalert("Error", "Enter a Lecture ID first.", type = "error")
      return()
    }
    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/attendance/qr/", lecture_id)) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) NULL)

    if (!is.null(result) && !is.null(result$qr_image_base64)) {
      output$lecturer_qr_image <- shiny::renderImage({
        tmp <- tempfile(fileext = ".png")
        writeBin(base64enc::base64decode(result$qr_image_base64), tmp)
        list(src = tmp, contentType = "image/png", width = 300, height = 300)
      }, deleteFile = TRUE)
    }
  })

  # ========================================================================
  # Submodule D: Live Dashboard (D1-D7)
  # Uses input$lecturer_live_lecture for lecture_id
  # ========================================================================

  live_reactive <- shiny::reactiveTimer(10000)

  get_live_lecture_id <- function() {
    lid <- input$lecturer_live_lecture
    if (is.null(lid) || nchar(trimws(lid)) == 0) return(NULL)
    trimws(lid)
  }

  output$lecturer_live_custom_cam_ui <- shiny::renderUI({
    if (input$lecturer_live_camera == "custom") {
      textInput("lecturer_live_custom_cam", "Custom URL (RTSP/HTTP)", placeholder = "rtsp://...")
    }
  })

  shiny::observeEvent(input$lecturer_live_start, {
    lecture_id <- get_live_lecture_id()
    if (is.null(lecture_id)) {
      shinyalert::shinyalert("Error", "Enter a Lecture ID first.", type = "error")
      return()
    }

    cam_url <- if (input$lecturer_live_camera == "custom") {
      input$lecturer_live_custom_cam
    } else {
      input$lecturer_live_camera
    }

    if (is.null(cam_url) || nchar(trimws(cam_url)) == 0) cam_url <- "0"

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/session/start")) |>
        httr2::req_body_json(list(
          lecture_id  = lecture_id,
          lecturer_id = "LECTURER_1",
          camera_url  = trimws(cam_url)
        )) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      shinyalert::shinyalert("Error", paste("Could not start session:", e$message), type = "error")
      NULL
    })
    if (!is.null(result)) {
      shinyalert::shinyalert("Lecture Started / بدأت المحاضرة",
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
    shinyalert::shinyalert("Lecture Ended / انتهت المحاضرة", "", type = "info")
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
}
