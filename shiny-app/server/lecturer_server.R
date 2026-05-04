# lecturer_server.R - Server logic for 5 lecturer submodules
# Submodules: A-Roster, B-Materials, C-Attendance, D-Live, E-Reports

lecturer_server <- function(input, output, session) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # Reactive data
  emotions_data <- shiny::reactivePoll(
    intervalMillis = 10000,
    session = session,
    checkFunc = function() {
      if (file.exists("../python-api/data/exports/emotions.csv")) {
        file.info("../python-api/data/exports/emotions.csv")$mtime
      } else {
        0
      }
    },
    valueFunc = function() {
      load_csv("../python-api/data/exports/emotions.csv")
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
          roster_xlsx = curl::form_file(file_info$datapath, type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
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
          sprintf("✓ Upload complete: %d students, %d face encodings saved",
                  result$students_created, result$encodings_saved)
        )
      })
    }
  })

  # ========================================================================
  # Submodule B: Material Upload
  # ========================================================================

  output$lecturer_materials_table <- DT::renderDataTable({
    materials <- load_csv("../python-api/data/exports/materials.csv")
    if (nrow(materials) == 0) {
      return(data.frame())
    }
    DT::datatable(
      materials |> dplyr::select(.data$title, .data$lecturer_id, .data$uploaded_at),
      options = list(pageLength = 10)
    )
  })

  shiny::observeEvent(input$lecturer_material_upload, {
    req(input$lecturer_material_file, input$lecturer_lecture_select, input$lecturer_material_title)

    file <- input$lecturer_material_file
    body <- list(
      title = input$lecturer_material_title,
      lecture_id = input$lecturer_lecture_select
    )

    result <- api_call("/upload/material", method = "POST", body = body)
    if (!is.null(result)) {
      shinyalert::shinyalert("Success", "Material uploaded", type = "success")
    }
  })

  # ========================================================================
  # Submodule C: Attendance (3 modes)
  # ========================================================================

  attendance_data <- shiny::reactiveVal(data.frame())

  output$lecturer_attendance_table <- DT::renderDataTable({
    data <- attendance_data()
    if (nrow(data) == 0) {
      return(data.frame())
    }
    DT::datatable(data, editable = TRUE, options = list(pageLength = 25))
  })

  shiny::observeEvent(input$lecturer_attendance_start, {
    req(input$lecturer_lecture_select)
    result <- api_call("/attendance/start", method = "POST",
                       body = list(lecture_id = input$lecturer_lecture_select))
    if (!is.null(result)) {
      output$lecturer_ai_attendance_status <- shiny::renderUI({
        shiny::div(
          class = "alert alert-info",
          "✓ AI attendance detection started. Monitoring will begin in 5 seconds..."
        )
      })
    }
  })

  # ========================================================================
  # Submodule D: Live Dashboard (D1-D7 panels)
  # ========================================================================

  live_reactive <- shiny::reactiveTimer(10000)

  output$lecturer_d1_gauge <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly())
    }

    avg_eng <- mean(emotions$engagement_score, na.rm = TRUE)
    plotly::plot_ly(
      type = "indicator",
      mode = "gauge+number",
      value = avg_eng,
      domain = list(x = c(0, 1), y = c(0, 1)),
      gauge = list(
        axis = list(range = list(0, 1)),
        bar = list(color = "darkblue"),
        steps = list(
          list(range = c(0, 0.25), color = "lightpink"),
          list(range = c(0.25, 0.45), color = "lightyellow"),
          list(range = c(0.45, 0.75), color = "lightgreen"),
          list(range = c(0.75, 1), color = "darkgreen")
        )
      )
    )
  })

  output$lecturer_d2_timeline <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No live data"))
    }

    timeline_data <- emotions |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "2 minutes")) |>
      dplyr::group_by(.data$time_bucket, .data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::group_by(.data$time_bucket) |>
      dplyr::mutate(pct = .data$count / sum(.data$count))

    plotly::plot_ly(timeline_data, x = ~time_bucket) |>
      plotly::add_trace(y = ~pct, color = ~emotion, type = "scatter", mode = "lines", stackgroup = "one")
  })

  output$lecturer_d3_load <- shiny::renderUI({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(shiny::div("No data"))
    }

    cog_load <- mean(
      (emotions$emotion == "Confused") + (emotions$emotion == "Frustrated"),
      na.rm = TRUE
    )

    status_color <- if (cog_load > 0.5) "danger" else if (cog_load > 0.3) "warning" else "success"

    shiny::div(
      class = paste0("alert alert-", status_color),
      sprintf("Cognitive Load: %.1f%%", cog_load * 100),
      if (cog_load > 0.5) shiny::p("⚠ Overloaded — consider slowing down") else NULL
    )
  })

  output$lecturer_d5_heatmap <- shiny::renderPlot({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(NULL)
    }

    heatmap_data <- emotions |>
      dplyr::mutate(time_bucket = lubridate::floor_date(.data$timestamp, "5 minutes")) |>
      dplyr::group_by(.data$student_id, .data$time_bucket) |>
      dplyr::slice(1) |>
      dplyr::ungroup()

    ggplot2::ggplot(heatmap_data, ggplot2::aes(x = .data$time_bucket, y = .data$student_id, fill = .data$emotion)) +
      ggplot2::geom_tile() +
      ggplot2::scale_fill_manual(
        values = c(
          "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
          "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
        )
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(axis.text.y = ggplot2::element_blank()) +
      ggplot2::labs(title = "Per-Student Emotion Heatmap", x = "Time", y = "Students", fill = "Emotion")
  })

  output$lecturer_d6_struggle <- DT::renderDataTable({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(data.frame())
    }

    struggle <- emotions |>
      dplyr::arrange(.data$student_id, .data$timestamp) |>
      dplyr::group_by(.data$student_id) |>
      dplyr::mutate(
        is_struggling = .data$emotion %in% c("Confused", "Frustrated"),
        streak = cumsum(!.data$is_struggling),
        consecutive = ave(as.numeric(.data$is_struggling), .data$student_id, .data$streak, FUN = cumsum)
      ) |>
      dplyr::filter(.data$consecutive >= 3) |>
      dplyr::slice_tail(n = 1) |>
      dplyr::ungroup() |>
      dplyr::select(.data$student_id, .data$emotion, .data$consecutive) |>
      dplyr::arrange(dplyr::desc(.data$consecutive))

    DT::datatable(struggle, options = list(pageLength = 10))
  })

  # D4: Class Valence Meter (-1.0 to +1.0)
  output$lecturer_d4_valence <- plotly::renderPlotly({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(plotly::plot_ly())

    valence <- mean(
      (emotions$emotion %in% c("Focused", "Engaged")) -
        (emotions$emotion %in% c("Frustrated", "Disengaged", "Anxious")),
      na.rm = TRUE
    )
    plotly::plot_ly(
      type = "indicator", mode = "gauge+number",
      value = round(valence, 2),
      domain = list(x = c(0, 1), y = c(0, 1)),
      gauge = list(
        axis  = list(range = list(-1, 1)),
        bar   = list(color = if (valence >= 0) "green" else "red"),
        steps = list(
          list(range = c(-1, 0), color = "lightyellow"),
          list(range = c(0, 1),  color = "lightgreen")
        )
      )
    )
  })

  # D7: Peak Confusion Moment
  output$lecturer_d7_peak <- shiny::renderUI({
    live_reactive()
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(shiny::div("No data"))

    peak <- emotions |>
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
      shiny::strong("Most confusing moment:"),
      format(peak$time_bucket[1], "%I:%M %p"),
      shiny::br(),
      sprintf("%.0f%% of class showed Confused/Frustrated", peak$confused_pct[1] * 100)
    )
  })

  # ========================================================================
  # Submodule E: Student Reports
  # ========================================================================

  output$lecturer_student_trend <- plotly::renderPlotly({
    req(input$lecturer_student_select)
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly())
    }

    student_data <- emotions |>
      dplyr::filter(.data$student_id == input$lecturer_student_select) |>
      dplyr::arrange(.data$timestamp)

    plotly::plot_ly(student_data, x = ~timestamp, y = ~engagement_score, type = "scatter", mode = "lines+markers")
  })

  output$lecturer_student_emotions <- plotly::renderPlotly({
    req(input$lecturer_student_select)
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly())
    }

    emotion_counts <- emotions |>
      dplyr::filter(.data$student_id == input$lecturer_student_select) |>
      dplyr::group_by(.data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop")

    plotly::plot_ly(emotion_counts, x = ~emotion, y = ~count, type = "bar")
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

    plotly::plot_ly(load_data, x = ~time_bucket, y = ~cognitive_load,
                   type = "scatter", mode = "lines+markers",
                   line = list(color = "orange")) |>
      plotly::layout(
        title = "Cognitive Load Timeline",
        yaxis = list(range = c(0, 1), title = "Load"),
        shapes = list(
          list(type = "line", x0 = min(load_data$time_bucket), x1 = max(load_data$time_bucket),
               y0 = 0.5, y1 = 0.5, line = list(color = "red", dash = "dot"))
        )
      )
  })

  output$lecturer_student_plan_ui <- shiny::renderUI({
    req(input$lecturer_student_select)
    result <- tryCatch({
      api_call(paste0("/notes/", input$lecturer_student_select, "/plan"))
    }, error = function(e) NULL)

    if (is.null(result) || is.null(result$plan)) {
      return(shiny::div(class = "alert alert-info", "No AI plan available yet for this student."))
    }

    shiny::div(
      class = "card p-3",
      shiny::markdown(result$plan)
    )
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
        quiet = TRUE
      )
    }
  )
}
