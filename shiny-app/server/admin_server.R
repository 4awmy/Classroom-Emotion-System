# admin_server.R - Server logic for 8 admin analytics panels
# Reads from nightly CSV exports (data/exports/*.csv)

admin_server <- function(input, output, session) {
  # Load R modules
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # Reactive Data Loading (with reactivePoll - checks file mtime every 60s)
  # ========================================================================

  emotions_data <- shiny::reactivePoll(
    intervalMillis = 60000,
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

  attendance_data <- shiny::reactivePoll(
    intervalMillis = 60000,
    session = session,
    checkFunc = function() {
      if (file.exists("../python-api/data/exports/attendance.csv")) {
        file.info("../python-api/data/exports/attendance.csv")$mtime
      } else {
        0
      }
    },
    valueFunc = function() {
      load_csv("../python-api/data/exports/attendance.csv")
    }
  )

  materials_data <- shiny::reactivePoll(
    intervalMillis = 60000,
    session = session,
    checkFunc = function() {
      if (file.exists("../python-api/data/exports/materials.csv")) {
        file.info("../python-api/data/exports/materials.csv")$mtime
      } else {
        0
      }
    },
    valueFunc = function() {
      load_csv("../python-api/data/exports/materials.csv")
    }
  )

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
  # Panel 2: Engagement Trend
  # ========================================================================

  output$admin_engagement_trend <- plotly::renderPlotly({
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
      plotly::layout(title = "Weekly Engagement Trend", xaxis = list(title = "Week"), yaxis = list(title = "Avg Engagement"))
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
      ggplot2::labs(title = "Lecture Group Engagement Heatmap", y = "Lecture Group", fill = "Avg Engagement")
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
      dplyr::select(.data$student_id, .data$engagement_score, .data$drop, .data$lecture_id, .data$consec_run)

    DT::datatable(at_risk, options = list(pageLength = 10))
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
      dplyr::select(.data$lecture_id, .data$engagement_score, .data$confusion_rate, .data$attendance_rate, .data$LES, .data$LES_category)

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

  # ========================================================================
  # Panel 7: Lecturer Cluster Map
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

    plotly::plot_ly(clustered, x = ~LES, y = ~attendance_variance, color = ~cluster_label, mode = "markers", marker = list(size = 10)) |>
      plotly::layout(
        title = "Lecturer Performance Clusters",
        xaxis = list(title = "LES Score"),
        yaxis = list(title = "Engagement Variance")
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
      ggplot2::labs(title = "Engagement by Time of Day & Weekday", x = "Hour", y = "Weekday", fill = "Avg Engagement")
  })
}
