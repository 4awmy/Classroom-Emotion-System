# admin_server.R - Server logic for 10 admin analytics panels
# Fully migrated to Supabase PostgreSQL with null-safety

admin_server <- function(input, output, session) {
  # Load R modules
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

  # ========================================================================
  # Reactive Data Loading
  # ========================================================================

  emotions_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    safe_query("SELECT * FROM emotion_log") # Table name fixed from 'emotions'
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    safe_query("SELECT * FROM attendance_log") # Table name fixed from 'attendance'
  })

  materials_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    safe_query("SELECT * FROM materials")
  })

  incidents_data <- shiny::reactive({
    shiny::invalidateLater(30000, session)
    safe_query("SELECT * FROM incidents")
  })

  # ========================================================================
  # Panel 1: Attendance Overview
  # ========================================================================

  output$admin_attendance_table <- DT::renderDataTable({
    data <- attendance_data()
    if (nrow(data) == 0) return(data.frame())

    filtered <- if (input$admin_dept_filter != "All") {
      data |> dplyr::filter(grepl(input$admin_dept_filter, .data$lecture_id, ignore.case = TRUE))
    } else {
      data
    }

    filtered |>
      dplyr::select(
        .data$student_id, .data$lecture_id, .data$status, .data$method,
        .data$timestamp
      ) |>
      DT::datatable(options = list(pageLength = 25))
  })

  output$admin_attendance_xlsx <- shiny::downloadHandler(
    filename = function() { paste0("attendance_", Sys.Date(), ".xlsx") },
    content = function(file) {
      data <- attendance_data()
      openxlsx::write.xlsx(data, file)
    }
  )

  # ========================================================================
  # Panel 2: Engagement Rate Trend
  # ========================================================================

  output$admin_confidence_trend <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No data available in PostgreSQL"))
    }

    trend_data <- emotions |>
      dplyr::mutate(
        week       = lubridate::floor_date(.data$timestamp, "week"),
        lecture_group = substr(.data$lecture_id, 1, 2)
      ) |>
      dplyr::group_by(.data$week, .data$lecture_group) |>
      dplyr::summarise(
        avg_engagement = mean(.data$engagement_score, na.rm = TRUE),
        .groups = "drop"
      )

    plotly::plot_ly(trend_data, x = ~week, y = ~avg_engagement, color = ~lecture_group, mode = "lines+markers") |>
      plotly::layout(
        xaxis = list(title = "Week"),
        yaxis = list(title = "Avg Engagement", range = c(0, 1))
      )
  })

  # ========================================================================
  # Panel 3: Dept Heatmap
  # ========================================================================

  output$admin_dept_heatmap <- shiny::renderPlot({
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
      ggplot2::labs(y = "Lecture Group", fill = "Avg Engagement")
  })

  # ========================================================================
  # Panel 4: At-Risk Cohort
  # ========================================================================

  output$admin_at_risk_table <- DT::renderDataTable({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return(data.frame())

    eng_metrics <- compute_engagement(emotions)$by_lecture
    if (nrow(eng_metrics) == 0) return(data.frame())

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
        `Engagement` = .data$engagement_score,
        Drop = .data$drop,
        `Latest Lecture` = .data$lecture_id,
        Streak = .data$consec_run
      )

    DT::datatable(at_risk, options = list(pageLength = 10))
  })

  # ========================================================================
  # Panel 9: Student Management
  # ========================================================================

  student_refresh <- shiny::reactiveVal(0)

  output$admin_student_table <- DT::renderDataTable({
    student_refresh()
    data <- api_call("/admin/students") # Updated to new endpoint
    if (is.null(data) || length(data) == 0) return(data.frame())
    df <- dplyr::bind_rows(lapply(data, as.data.frame))
    DT::datatable(df, options = list(pageLength = 10), selection = "single")
  })

  # ========================================================================
  # Panel 10: Exam Incidents
  # ========================================================================

  output$admin_incidents_table <- DT::renderDataTable({
    data <- incidents_data()
    if (nrow(data) == 0) return(data.frame())

    data <- data |>
      dplyr::mutate(
        evidence = ifelse(is.na(.data$evidence_path) | .data$evidence_path == "",
                         "No Photo",
                         sprintf('<a href="%s/attendance/evidence/%s" target="_blank">View Photo</a>',
                                 FASTAPI_BASE, basename(.data$evidence_path)))
      ) |>
      dplyr::select(
        `Student ID`    = .data$student_id,
        `Exam ID`       = .data$exam_id,
        `Type`          = .data$flag_type,
        Severity        = .data$severity,
        Timestamp       = .data$timestamp,
        Evidence        = .data$evidence
      )

    DT::datatable(data, escape = FALSE, options = list(pageLength = 25))
  })
}
