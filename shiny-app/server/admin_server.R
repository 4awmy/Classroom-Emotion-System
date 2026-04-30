# server/admin_server.R — Server logic for the Admin role (8 panels)
#
# All reactive data comes through the `exports` reactivePoll defined in
# global.R.  Direct SQLite access is forbidden — see explanation.md §3.

admin_server <- function(input, output, session, exports) {

  # ── Derived data ────────────────────────────────────────────────────────────
  emotions_r    <- reactive({ exports()$emotions    })
  attendance_r  <- reactive({ exports()$attendance  })

  # Pre-computed engagement metrics (see modules/engagement_score.R)
  engagement_r  <- reactive({
    req(nrow(emotions_r()) > 0)
    compute_engagement(emotions_r())
  })

  # ── Panel 1: Attendance Overview ────────────────────────────────────────────
  observe({
    depts <- unique(attendance_r()$department)
    updateSelectInput(session, "att_dept",
                      choices = c("All", depts), selected = "All")
  })

  attendance_filtered <- reactive({
    df <- attendance_r()
    if (!is.null(input$att_dept) && input$att_dept != "All") {
      df <- df[df$department == input$att_dept, ]
    }
    df
  })

  output$admin_attendance_dt <- DT::renderDataTable({
    DT::datatable(attendance_filtered(),
                  options = list(pageLength = 20, scrollX = TRUE),
                  rownames = FALSE)
  })

  output$att_xlsx <- downloadHandler(
    filename = function() paste0("attendance_", Sys.Date(), ".xlsx"),
    content  = function(file) openxlsx::write.xlsx(attendance_filtered(), file)
  )

  # ── Panel 2: Engagement Trend ────────────────────────────────────────────────
  output$admin_trend_plot <- plotly::renderPlotly({
    df <- engagement_r()$by_lecture
    req(nrow(df) > 0)
    plotly::plot_ly(df, x = ~lecture_id, y = ~engagement_score,
                    color = ~student_id, type = "scatter", mode = "lines+markers") |>
      plotly::layout(
        xaxis = list(title = "Lecture"),
        yaxis = list(title = "Avg Engagement Score", range = c(0, 1))
      )
  })

  # ── Panel 3: Department Heatmap ──────────────────────────────────────────────
  output$admin_heatmap_plot <- renderPlot({
    df <- engagement_r()$by_lecture
    req(nrow(df) > 0)
    ggplot2::ggplot(df, ggplot2::aes(x = lecture_id, y = student_id,
                                      fill = engagement_score)) +
      ggplot2::geom_tile(colour = "white") +
      ggplot2::scale_fill_gradient(low = "#c0392b", high = "#1e7e34",
                                   name = "Engagement") +
      ggplot2::labs(x = "Lecture", y = "Student") +
      ggplot2::theme_minimal(base_size = 12)
  })

  # ── Panel 4: At-Risk Cohort ──────────────────────────────────────────────────
  output$admin_atrisk_dt <- DT::renderDataTable({
    df <- engagement_r()$by_student
    at_risk <- df[!is.na(df$trend_slope) & df$trend_slope <= -0.20, ]
    DT::datatable(at_risk,
                  options = list(pageLength = 15, scrollX = TRUE),
                  rownames = FALSE,
                  selection = "single") |>
      DT::formatStyle("avg_engagement",
                       backgroundColor = DT::styleInterval(c(0.25, 0.45),
                         c("#c0392b40", "#d3540040", "#1e7e3440")))
  })

  # ── Panel 5: Lecture Effectiveness Score ────────────────────────────────────
  output$admin_les_dt <- DT::renderDataTable({
    df <- engagement_r()$by_lecture
    req(nrow(df) > 0)
    df <- df |>
      dplyr::mutate(
        attendance_rate = 1,   # placeholder until attendance join is available
        LES = round(0.5 * engagement_score +
                    0.3 * (1 - confusion_rate) +
                    0.2 * attendance_rate, 3)
      ) |>
      dplyr::arrange(dplyr::desc(LES))

    n   <- nrow(df)
    top <- ceiling(n * 0.10)
    bot <- ceiling(n * 0.10)

    DT::datatable(df[, c("student_id", "lecture_id", "LES", "engagement_score",
                          "confusion_rate")],
                  options = list(pageLength = 20, scrollX = TRUE),
                  rownames = FALSE) |>
      DT::formatStyle("LES",
                       backgroundColor = DT::styleRow(
                         rows  = c(seq_len(top), seq(n - bot + 1, n)),
                         values = c(rep("#d4edda", top), rep("#f8d7da", bot))
                       ))
  })

  # ── Panel 6: Emotion Distribution ───────────────────────────────────────────
  output$admin_emotion_dist_plot <- renderPlot({
    df <- emotions_r()
    req(nrow(df) > 0)
    emotion_levels <- c("Focused", "Engaged", "Confused",
                        "Anxious", "Frustrated", "Disengaged")
    emotion_colors <- c(
      Focused    = "#1e7e34",
      Engaged    = "#28a745",
      Confused   = "#ffc107",
      Anxious    = "#9b59b6",
      Frustrated = "#e67e22",
      Disengaged = "#c0392b"
    )
    df$emotion <- factor(df$emotion, levels = emotion_levels)
    ggplot2::ggplot(df, ggplot2::aes(x = lecture_id, fill = emotion)) +
      ggplot2::geom_bar(position = "fill") +
      ggplot2::scale_fill_manual(values = emotion_colors) +
      ggplot2::scale_y_continuous(labels = scales::percent_format()) +
      ggplot2::labs(x = "Lecture", y = "Proportion", fill = "Emotion") +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(legend.position = "bottom")
  })

  # ── Panel 7: Lecturer Cluster Map ───────────────────────────────────────────
  output$admin_cluster_plot <- plotly::renderPlotly({
    clusters <- cluster_lecturers(engagement_r()$by_lecture)
    req(nrow(clusters) > 0)
    plotly::plot_ly(clusters,
                    x = ~avg_LES, y = ~attendance_variance,
                    color = ~cluster_label, type = "scatter", mode = "markers",
                    marker = list(size = 12),
                    text = ~paste("Lecturer:", lecturer_id)) |>
      plotly::layout(
        xaxis = list(title = "Avg LES"),
        yaxis = list(title = "Attendance Variance")
      )
  })

  # ── Panel 8: Time-of-Day Heatmap ────────────────────────────────────────────
  output$admin_tod_plot <- renderPlot({
    df <- emotions_r()
    req(nrow(df) > 0 && "timestamp" %in% names(df))
    df$timestamp <- as.POSIXct(df$timestamp)
    df$weekday   <- weekdays(df$timestamp)
    df$hour_slot <- format(lubridate::floor_date(df$timestamp, "hour"), "%H:00")
    tod <- df |>
      dplyr::group_by(weekday, hour_slot) |>
      dplyr::summarise(avg_engagement = mean(engagement_score, na.rm = TRUE),
                       .groups = "drop")
    ggplot2::ggplot(tod, ggplot2::aes(x = weekday, y = hour_slot,
                                       fill = avg_engagement)) +
      ggplot2::geom_tile(colour = "white") +
      ggplot2::scale_fill_gradient(low = "#c0392b", high = "#1e7e34",
                                   name = "Avg Engagement") +
      ggplot2::labs(x = "Day", y = "Hour") +
      ggplot2::theme_minimal(base_size = 12)
  })

}
