# admin_server.R - Server logic for 8 admin analytics panels
# Reads from nightly CSV exports (data/exports/*.csv)

admin_server <- function(input, output, session) {
  # Load R modules
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # Reactive Data Loading (from Supabase PostgreSQL)
  # ========================================================================

  emotions_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    dbGetQuery(con, "SELECT * FROM emotions")
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    dbGetQuery(con, "SELECT * FROM attendance")
  })

  materials_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    dbGetQuery(con, "SELECT * FROM materials")
  })

  incidents_data <- shiny::reactive({
    shiny::invalidateLater(30000, session)
    dbGetQuery(con, "SELECT * FROM incidents")
  })

  # ========================================================================
  # Panel 1: Attendance Overview
  # ========================================================================

  output$admin_attendance_table <- DT::renderDataTable({
    data <- attendance_data()
    if (nrow(data) == 0) {
      return(data.frame())
    }

    # Note: department column not in locked schema (§6.3) — filter by lecture_id prefix instead
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
    filename = function() {
      paste0("attendance_", Sys.Date(), ".xlsx")
    },
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
      return(plotly::plot_ly() |> plotly::add_text(text = "No data"))
    }

    # Group by lecture_id prefix as proxy for department (department not in locked schema)
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
        title = "Weekly Engagement Score Trend",
        xaxis = list(title = "Week"),
        yaxis = list(title = "Avg Engagement Score", range = c(0, 1))
      )
  })

  # ========================================================================
  # Panel 3: Department Engagement Heatmap (ggplot2)
  # ========================================================================

  output$admin_dept_heatmap <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(NULL)
    }

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
      ggplot2::labs(title = "Lecture Group Engagement Heatmap", y = "Lecture Group", fill = "Avg Engagement Score")
  })

  # ========================================================================
  # Panel 4: At-Risk Cohort
  # ========================================================================

  output$admin_at_risk_table <- DT::renderDataTable({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(data.frame())
    }

    eng_metrics <- compute_engagement(emotions)$by_lecture |>
      dplyr::arrange(.data$student_id, .data$lecture_id)

    # Identify students with >20% drop over 3 consecutive lectures
    at_risk <- eng_metrics |>
      dplyr::group_by(.data$student_id) |>
      dplyr::mutate(
        lag_score  = dplyr::lag(.data$engagement_score),
        drop       = .data$lag_score - .data$engagement_score,
        is_drop    = !is.na(.data$drop) & .data$drop > 0.20,
        # reset streak counter whenever the streak breaks
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
        `Lecture ID` = .data$lecture_id,
        Streak = .data$consec_run
      )

    DT::datatable(at_risk, options = list(pageLength = 10))
  })

  # At-risk notify button — POST selected students to /notify/lecturer
  shiny::observeEvent(input$admin_notify_button, {
    emotions <- emotions_data()
    if (nrow(emotions) == 0) return()

    eng_metrics <- compute_engagement(emotions)$by_lecture |>
      dplyr::arrange(.data$student_id, .data$lecture_id)

    at_risk_ids <- eng_metrics |>
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
      dplyr::pull(.data$student_id)

    if (length(at_risk_ids) == 0) {
      shinyalert::shinyalert("No at-risk students", "No students meet the threshold.", type = "info")
      return()
    }

    # Use lecture_id from first row in at_risk set
    lecture_id <- eng_metrics |>
      dplyr::filter(.data$student_id %in% at_risk_ids) |>
      dplyr::pull(.data$lecture_id) |>
      dplyr::first()

    success <- 0
    for (sid in at_risk_ids) {
      tryCatch({
        httr2::request(paste0(FASTAPI_BASE, "/notify/lecturer")) |>
          httr2::req_url_query(
            student_id = sid,
            lecture_id = lecture_id,
            reason     = "At-risk: >20% engagement drop over 3+ lectures"
          ) |>
          httr2::req_method("POST") |>
          httr2::req_perform()
        success <- success + 1
      }, error = function(e) NULL)
    }
    shinyalert::shinyalert(
      "Notifications Sent",
      sprintf("%d at-risk student(s) flagged to lecturer.", success),
      type = "success"
    )
  })

  # ========================================================================
  # Panel 5: Lecture Effectiveness Score (LES)
  # ========================================================================

  output$admin_les_table <- DT::renderDataTable({
    emotions <- emotions_data()
    attendance <- attendance_data()

    if (nrow(emotions) == 0 || nrow(attendance) == 0) {
      return(data.frame())
    }

    eng_metrics <- compute_engagement(emotions)$by_lecture
    att_metrics <- attendance |>
      dplyr::mutate(present = .data$status == "Present") |>
      dplyr::group_by(.data$lecture_id) |>
      dplyr::summarise(attendance_rate = mean(.data$present, na.rm = TRUE), .groups = "drop")

    les_data <- eng_metrics |>
      dplyr::left_join(att_metrics, by = "lecture_id") |>
      dplyr::mutate(
        LES = 0.5 * .data$engagement_score + 0.3 * (1 - .data$confusion_rate) + 0.2 * .data$attendance_rate,
        LES_category = dplyr::if_else(.data$LES >= 0.7, "Excellent", dplyr::if_else(.data$LES >= 0.5, "Good", "Needs Improvement"))
      ) |>
      dplyr::arrange(dplyr::desc(.data$LES)) |>
      dplyr::select(
        `Lecture ID` = .data$lecture_id,
        `Engagement Score` = .data$engagement_score,
        `Confusion Rate` = .data$confusion_rate,
        `Attendance Rate` = .data$attendance_rate,
        LES = .data$LES,
        Category = .data$LES_category
      )

    DT::datatable(les_data, options = list(pageLength = 10))
  })

  # ========================================================================
  # Panel 6: Emotion Distribution (ggplot2 stacked bar)
  # ========================================================================

  output$admin_emotion_dist <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(NULL)
    }

    emotion_dist <- emotions |>
      dplyr::mutate(lecture_group = substr(.data$lecture_id, 1, 2)) |>
      dplyr::group_by(.data$lecture_group, .data$emotion) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::group_by(.data$lecture_group) |>
      dplyr::mutate(pct = .data$count / sum(.data$count))

    ggplot2::ggplot(emotion_dist, ggplot2::aes(x = .data$lecture_group, y = .data$pct, fill = .data$emotion)) +
      ggplot2::geom_col(position = "fill") +
      ggplot2::scale_fill_manual(
        values = c(
          "Focused" = "#1B5E20", "Engaged" = "#4CAF50", "Confused" = "#FFC107",
          "Frustrated" = "#FF9800", "Anxious" = "#9C27B0", "Disengaged" = "#F44336"
        )
      ) +
      ggplot2::theme_minimal() +
      ggplot2::labs(title = "Emotion Distribution by Department", y = "Proportion", fill = "Emotion")
  })

  output$admin_emotion_trend <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No data"))
    }

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
        title = "Weekly Emotion Trend (Stacked)",
        xaxis = list(title = "Week"),
        yaxis = list(title = "Proportion", range = c(0, 1))
      )
  })

  # ========================================================================
  # Panel 7: Clusters
  # ========================================================================

  output$admin_lecturer_clusters <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No data"))
    }

    attendance <- attendance_data()

    # Compute real LES per lecture then average per lecturer
    att_rates <- if (nrow(attendance) > 0) {
      attendance |>
        dplyr::mutate(present = .data$status == "Present") |>
        dplyr::group_by(.data$lecture_id) |>
        dplyr::summarise(attendance_rate = mean(.data$present, na.rm = TRUE), .groups = "drop")
    } else {
      data.frame(lecture_id = character(), attendance_rate = numeric())
    }

    eng_metrics <- compute_engagement(emotions)$by_lecture |>
      dplyr::left_join(att_rates, by = "lecture_id") |>
      dplyr::mutate(
        attendance_rate = dplyr::coalesce(.data$attendance_rate, 0.8),
        LES_lecture = 0.5 * .data$engagement_score +
          0.3 * (1 - .data$confusion_rate) +
          0.2 * .data$attendance_rate
      ) |>
      dplyr::group_by(.data$lecturer_id) |>
      dplyr::summarise(
        LES                 = round(mean(.data$LES_lecture, na.rm = TRUE), 3),
        attendance_variance = round(sd(.data$attendance_rate, na.rm = TRUE), 3),
        .groups = "drop"
      ) |>
      dplyr::mutate(attendance_variance = dplyr::coalesce(.data$attendance_variance, 0))

    clustered <- cluster_lecturers(eng_metrics, k = min(3, nrow(eng_metrics)))

    plotly::plot_ly(clustered, x = ~LES, y = ~attendance_variance, color = ~cluster_label,
                    text = ~paste("Lecturer:", lecturer_id),
                    mode = "markers", marker = list(size = 12)) |>
      plotly::layout(
        title = "Lecturer Performance Clusters",
        xaxis = list(title = "Avg LES Score"),
        yaxis = list(title = "Attendance Rate Variance")
      )
  })

  output$admin_student_clusters <- plotly::renderPlotly({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "No data"))
    }

    clustered <- cluster_student_behavior(emotions, k = min(3, length(unique(emotions$student_id))))

    if (nrow(clustered) == 0) {
      return(plotly::plot_ly() |> plotly::add_text(text = "Insufficient data for clustering"))
    }

    plotly::plot_ly(clustered, x = ~avg_engagement_score, y = ~avg_confused, color = ~cluster_label,
                    text = ~paste("Student:", student_id),
                    mode = "markers", marker = list(size = 10)) |>
      plotly::layout(
        title = "Student Behavior Clusters",
        xaxis = list(title = "Avg Engagement Score"),
        yaxis = list(title = "Avg Confusion Rate")
      )
  })

  # ========================================================================
  # Panel 8: Time-of-Day Heatmap (ggplot2)
  # ========================================================================

  output$admin_tod_heatmap <- shiny::renderPlot({
    emotions <- emotions_data()
    if (nrow(emotions) == 0) {
      return(NULL)
    }

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
      ggplot2::labs(title = "Engagement Score by Time of Day & Weekday", x = "Hour", y = "Weekday", fill = "Avg Engagement Score")
  })

  # ========================================================================
  # Panel 9: Student Management
  # ========================================================================

  # Trigger table refresh
  student_refresh <- shiny::reactiveVal(0)

  output$admin_student_table <- DT::renderDataTable({
    student_refresh() # Dependency
    data <- api_call("/roster/students")
    if (is.null(data) || length(data) == 0) return(data.frame())

    # Convert list of lists to data frame
    df <- dplyr::bind_rows(lapply(data, as.data.frame))

    DT::datatable(df, options = list(pageLength = 10), selection = "single")
  })

  shiny::observeEvent(input$admin_student_submit, {
    req(input$admin_student_id, input$admin_student_name, input$admin_student_photo)

    # Validate 9-digit student_id
    if (!grepl("^\\d{9}$", input$admin_student_id)) {
      shinyalert::shinyalert("Invalid ID", "Student ID must be exactly 9 digits.", type = "error")
      return()
    }

    result <- tryCatch({
      httr2::request(paste0(FASTAPI_BASE, "/roster/student")) |>
        httr2::req_body_multipart(
          student_id = input$admin_student_id,
          name = input$admin_student_name,
          email = input$admin_student_email,
          photo = curl::form_file(input$admin_student_photo$datapath)
        ) |>
        httr2::req_perform() |>
        httr2::resp_body_json()
    }, error = function(e) {
      # Handle specific status codes if possible, or generic error
      shinyalert::shinyalert("Error", as.character(e), type = "error")
      NULL
    })

    if (!is.null(result)) {
      shinyalert::shinyalert("Success",
                             paste("Student", result$name, "added and face encoded successfully."),
                             type = "success")
      # Clear inputs
      shiny::updateTextInput(session, "admin_student_id", value = "")
      shiny::updateTextInput(session, "admin_student_name", value = "")
      shiny::updateTextInput(session, "admin_student_email", value = "")
      # Refresh table
      student_refresh(student_refresh() + 1)
    }
  })

  # ========================================================================
  # Panel 10: Exam Incidents
  # ========================================================================

  output$admin_incidents_table <- DT::renderDataTable({
    data <- incidents_data()
    if (nrow(data) == 0) {
      return(data.frame())
    }

    # Format evidence link
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
        `Incident Type` = .data$flag_type,
        Severity        = .data$severity,
        Timestamp       = .data$timestamp,
        Evidence        = .data$evidence
      )

    DT::datatable(data, escape = FALSE, options = list(pageLength = 25))
  })
}
