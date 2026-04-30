# server/lecturer_server.R — Server logic for the Lecturer role (5 submodules)
#
# All read-only analytics come through `exports` reactivePoll.
# Write operations go through FastAPI HTTP calls (httr2).
# Direct SQLite access is forbidden — see explanation.md §3.

lecturer_server <- function(input, output, session, exports) {

  emotions_r    <- reactive({ exports()$emotions   })
  attendance_r  <- reactive({ exports()$attendance })
  materials_r   <- reactive({ exports()$materials  })

  # ── Submodule A: Roster Setup ────────────────────────────────────────────────
  roster_result <- eventReactive(input$roster_upload_btn, {
    req(input$roster_xlsx)
    shinyjs::disable("roster_upload_btn")
    on.exit(shinyjs::enable("roster_upload_btn"))
    resp <- httr2::request(paste0(FASTAPI_BASE, "/roster/upload")) |>
      httr2::req_body_multipart(
        roster_xlsx = curl::form_file(input$roster_xlsx$datapath,
                                      type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      ) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    httr2::resp_body_json(resp)
  })

  output$roster_result_ui <- renderUI({
    res <- roster_result()
    if (!is.null(res$students_created)) {
      div(class = "alert alert-success",
          icon("check-circle"),
          sprintf(" Upload complete: %d students created, %d face encodings saved.",
                  res$students_created, res$encodings_saved))
    } else {
      div(class = "alert alert-danger",
          icon("exclamation-circle"),
          paste("Upload failed:", res$detail %||% "Unknown error"))
    }
  })

  # ── Submodule B: Material Upload ─────────────────────────────────────────────
  observe({
    lec_ids <- unique(materials_r()$lecture_id)
    updateSelectInput(session, "mat_lecture_id", choices = lec_ids)
  })

  observeEvent(input$mat_upload_btn, {
    req(input$mat_file, input$mat_lecture_id, input$mat_title)
    resp <- httr2::request(paste0(FASTAPI_BASE, "/upload/material")) |>
      httr2::req_body_multipart(
        file       = curl::form_file(input$mat_file$datapath),
        lecture_id = input$mat_lecture_id,
        title      = input$mat_title
      ) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200) {
      shinyalert::shinyalert("Uploaded", "Material uploaded to Google Drive.", type = "success")
    } else {
      shinyalert::shinyalert("Error", "Upload failed. Check FastAPI logs.", type = "error")
    }
  })

  output$materials_dt <- DT::renderDataTable({
    DT::datatable(materials_r()[, c("material_id", "lecture_id", "title",
                                     "drive_link", "uploaded_at")],
                  options = list(pageLength = 10, scrollX = TRUE),
                  rownames = FALSE)
  })

  # ── Submodule C: Attendance ──────────────────────────────────────────────────
  observe({
    lec_ids <- unique(attendance_r()$lecture_id)
    updateSelectInput(session, "att_lecture_id",    choices = lec_ids)
    updateSelectInput(session, "ai_att_lecture_id", choices = lec_ids)
    updateSelectInput(session, "qr_lecture_id",     choices = lec_ids)
  })

  output$manual_attendance_dt <- DT::renderDataTable({
    df <- attendance_r()[attendance_r()$lecture_id == input$att_lecture_id, ]
    DT::datatable(df[, c("student_id", "status")],
                  editable  = list(target = "cell", disable = list(columns = 0)),
                  selection = "none",
                  rownames  = FALSE)
  })

  observeEvent(input$start_ai_att, {
    resp <- httr2::request(paste0(FASTAPI_BASE, "/attendance/start")) |>
      httr2::req_body_json(list(lecture_id = input$ai_att_lecture_id)) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    output$ai_att_status <- renderText({
      if (httr2::resp_status(resp) == 200) "AI attendance detection started."
      else paste("Error:", httr2::resp_status(resp))
    })
  })

  output$qr_image <- renderImage({
    req(input$qr_lecture_id)
    resp <- httr2::request(
      paste0(FASTAPI_BASE, "/attendance/qr/", input$qr_lecture_id)) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200) {
      tmp <- tempfile(fileext = ".png")
      writeBin(httr2::resp_body_raw(resp), tmp)
      list(src = tmp, contentType = "image/png", width = "250px")
    } else {
      list(src = "", alt = "QR code unavailable")
    }
  }, deleteFile = TRUE)

  # ── Submodule D: Live Dashboard ──────────────────────────────────────────────
  # Poll live emotion data every 10 seconds while a session is active
  live_timer  <- reactiveTimer(10000)
  live_active <- reactiveVal(FALSE)

  observeEvent(input$start_session_btn, {
    resp <- httr2::request(paste0(FASTAPI_BASE, "/session/start")) |>
      httr2::req_body_json(list(
        lecture_id  = input$live_lecture_id,
        lecturer_id = session$userData$lecturer_id %||% "lecturer_01"
      )) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200) live_active(TRUE)
  })

  observeEvent(input$end_session_btn, {
    httr2::request(paste0(FASTAPI_BASE, "/session/end")) |>
      httr2::req_body_json(list(lecture_id = input$live_lecture_id)) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    live_active(FALSE)
  })

  live_data <- reactive({
    live_timer()
    req(live_active(), input$live_lecture_id)
    resp <- httr2::request(paste0(FASTAPI_BASE, "/emotion/live")) |>
      httr2::req_url_query(lecture_id = input$live_lecture_id, limit = 60) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200) {
      df <- as.data.frame(do.call(rbind,
              lapply(httr2::resp_body_json(resp), as.data.frame)))
      df
    } else {
      data.frame()
    }
  })

  # D1 — Engagement gauge
  output$live_gauge <- plotly::renderPlotly({
    df <- live_data()
    val <- if (nrow(df) > 0) round(mean(df$engagement_score, na.rm = TRUE), 2) else 0
    plotly::plot_ly(
      type  = "indicator", mode = "gauge+number",
      value = val,
      gauge = list(
        axis  = list(range = list(0, 1)),
        steps = list(
          list(range = c(0,    0.25), color = "#c0392b"),
          list(range = c(0.25, 0.45), color = "#e67e22"),
          list(range = c(0.45, 1),    color = "#1e7e34")
        ),
        threshold = list(line = list(color = "#002147", width = 3), value = val)
      )
    ) |>
      plotly::layout(margin = list(t = 30, b = 10))
  })

  # D2 — Real-time emotion timeline
  output$live_timeline_plot <- plotly::renderPlotly({
    df <- live_data()
    req(nrow(df) > 0 && "timestamp" %in% names(df))
    df$timestamp  <- as.POSIXct(df$timestamp)
    emotion_levels <- c("Focused","Engaged","Confused","Anxious","Frustrated","Disengaged")
    timeline <- df |>
      dplyr::mutate(time_bucket = lubridate::floor_date(timestamp, "2 minutes")) |>
      dplyr::group_by(time_bucket, emotion) |>
      dplyr::summarise(pct = dplyr::n() / nrow(df), .groups = "drop")
    emotion_colors <- c(Focused="#1e7e34", Engaged="#28a745", Confused="#ffc107",
                         Anxious="#9b59b6", Frustrated="#e67e22", Disengaged="#c0392b")
    plotly::plot_ly(timeline, x = ~time_bucket, y = ~pct,
                    color = ~emotion, colors = emotion_colors,
                    type = "scatter", mode = "lines") |>
      plotly::layout(
        xaxis = list(title = "Time"),
        yaxis = list(title = "% of Class", tickformat = ".0%")
      )
  })

  # D3 — Cognitive Load value box
  output$live_cog_load_box <- renderValueBox({
    df <- live_data()
    if (nrow(df) == 0) {
      return(valueBox("N/A", "Cognitive Load", icon = icon("brain"), color = "blue"))
    }
    eng  <- compute_engagement(df)$by_lecture
    cog  <- mean(eng$cognitive_load, na.rm = TRUE)
    col  <- if (cog > 0.50) "red" else if (cog > 0.30) "orange" else "green"
    lbl  <- if (cog > 0.50) "Overloaded — slow down" else if (cog > 0.30) "Moderate" else "OK"
    valueBox(sprintf("%.2f", cog), paste("Cognitive Load:", lbl),
             icon = icon("brain"), color = col)
  })

  # D4 — Class Valence gauge
  output$live_valence_gauge <- plotly::renderPlotly({
    df <- live_data()
    val <- if (nrow(df) > 0) {
      eng <- compute_engagement(df)$by_lecture
      round(mean(eng$class_valence, na.rm = TRUE), 2)
    } else 0
    plotly::plot_ly(
      type  = "indicator", mode = "gauge+number",
      value = val,
      gauge = list(
        axis  = list(range = list(-1, 1)),
        steps = list(
          list(range = c(-1, 0), color = "#c0392b"),
          list(range = c(0,  1), color = "#1e7e34")
        )
      )
    ) |>
      plotly::layout(margin = list(t = 30, b = 10))
  })

  # D5 — Per-student heatmap
  output$live_student_heatmap <- renderPlot({
    df <- live_data()
    req(nrow(df) > 0 && all(c("student_id","timestamp","emotion") %in% names(df)))
    df$timestamp <- as.POSIXct(df$timestamp)
    df$segment   <- format(lubridate::floor_date(df$timestamp, "5 minutes"), "%H:%M")
    emotion_colors <- c(Focused="#1e7e34", Engaged="#28a745", Confused="#ffc107",
                         Anxious="#9b59b6", Frustrated="#e67e22", Disengaged="#c0392b")
    dominant <- df |>
      dplyr::group_by(student_id, segment) |>
      dplyr::summarise(dom_emotion = names(which.max(table(emotion))), .groups="drop")
    ggplot2::ggplot(dominant, ggplot2::aes(x = segment, y = student_id, fill = dom_emotion)) +
      ggplot2::geom_tile(colour = "white") +
      ggplot2::scale_fill_manual(values = emotion_colors, name = "Emotion") +
      ggplot2::labs(x = "5-min segment", y = "Student") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
  })

  # D6 — Persistent struggle alert table
  output$live_struggle_dt <- DT::renderDataTable({
    df <- live_data()
    req(nrow(df) > 0 && all(c("student_id","timestamp","emotion") %in% names(df)))
    df$timestamp <- as.POSIXct(df$timestamp)
    persistent <- df |>
      dplyr::arrange(student_id, timestamp) |>
      dplyr::group_by(student_id) |>
      dplyr::mutate(
        is_struggling = emotion %in% c("Confused", "Frustrated"),
        streak        = cumsum(!is_struggling),
        consecutive   = ave(is_struggling, student_id, streak, FUN = cumsum)
      ) |>
      dplyr::filter(consecutive >= 3) |>
      dplyr::slice_tail(n = 1) |>
      dplyr::ungroup() |>
      dplyr::select(student_id, emotion, consecutive)

    DT::datatable(persistent, rownames = FALSE,
                  options = list(pageLength = 10)) |>
      DT::formatStyle("emotion",
                       backgroundColor = DT::styleEqual(
                         c("Confused", "Frustrated"), c("#fff3cd", "#f8d7da")
                       ))
  })

  # D7 — Peak confusion moment
  output$live_peak_confusion_box <- renderValueBox({
    df <- live_data()
    if (nrow(df) == 0 || !"timestamp" %in% names(df)) {
      return(valueBox("—", "Peak Confusion Moment", icon = icon("clock"), color = "blue"))
    }
    df$timestamp  <- as.POSIXct(df$timestamp)
    df$bucket     <- lubridate::floor_date(df$timestamp, "2 minutes")
    peak <- df |>
      dplyr::group_by(bucket) |>
      dplyr::summarise(
        rate = mean(emotion %in% c("Confused","Frustrated"), na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::slice_max(order_by = rate, n = 1)
    ts <- if (nrow(peak) > 0) format(peak$bucket[1], "%H:%M") else "—"
    valueBox(ts, "Peak Confusion Moment", icon = icon("clock"), color = "orange")
  })

  # ── Confusion alert observer ─────────────────────────────────────────────────
  observe({
    df <- live_data()
    req(nrow(df) >= 10)
    confusion_rate <- mean(df$emotion %in% c("Confused", "Frustrated"), na.rm = TRUE)
    if (confusion_rate >= 0.40) {
      resp <- httr2::request(paste0(FASTAPI_BASE, "/gemini/question")) |>
        httr2::req_body_json(list(lecture_id = input$live_lecture_id)) |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform()
      if (httr2::resp_status(resp) == 200) {
        q <- httr2::resp_body_json(resp)$question
        shinyalert::shinyalert(
          title = sprintf("\u26a0 Class confused (%.0f%%)", confusion_rate * 100),
          text  = paste("Suggested:", q),
          type  = "warning",
          showCancelButton   = TRUE,
          confirmButtonText  = "Ask it",
          cancelButtonText   = "Dismiss",
          callbackR = function(x) {
            if (isTRUE(x)) {
              httr2::request(paste0(FASTAPI_BASE, "/session/broadcast")) |>
                httr2::req_body_json(list(type = "freshbrainer", question = q)) |>
                httr2::req_error(is_error = function(resp) FALSE) |>
                httr2::req_perform()
            }
          }
        )
      }
    }
  })

  # ── Submodule E: Student Reports ─────────────────────────────────────────────
  observe({
    sids <- unique(emotions_r()$student_id)
    updateSelectInput(session, "report_student_id", choices = sids)
  })

  student_eng <- reactive({
    req(input$report_student_id, nrow(emotions_r()) > 0)
    df <- emotions_r()[emotions_r()$student_id == input$report_student_id, ]
    compute_engagement(df)$by_lecture
  })

  output$report_engagement_trend <- plotly::renderPlotly({
    df <- student_eng()
    req(nrow(df) > 0)
    plotly::plot_ly(df, x = ~lecture_id, y = ~engagement_score,
                    type = "scatter", mode = "lines+markers") |>
      plotly::layout(xaxis = list(title = "Lecture"),
                     yaxis = list(title = "Engagement", range = c(0, 1)))
  })

  output$report_cog_load_trend <- plotly::renderPlotly({
    df <- student_eng()
    req(nrow(df) > 0)
    plotly::plot_ly(df, x = ~lecture_id, y = ~cognitive_load,
                    type = "scatter", mode = "lines+markers",
                    line = list(color = "#e67e22")) |>
      plotly::layout(xaxis = list(title = "Lecture"),
                     yaxis = list(title = "Cognitive Load", range = c(0, 2)))
  })

  output$report_plan_md <- renderUI({
    req(input$report_student_id)
    resp <- httr2::request(
      paste0(FASTAPI_BASE, "/notes/", input$report_student_id, "/plan")) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200) {
      md <- httr2::resp_body_json(resp)$plan
      shiny::markdown(md)
    } else {
      p(em("No AI plan available yet."))
    }
  })

  output$download_report_pdf <- downloadHandler(
    filename = function() {
      paste0("student_", input$report_student_id, "_", Sys.Date(), ".pdf")
    },
    content = function(file) {
      params <- list(student_id = input$report_student_id,
                     export_dir = EXPORT_DIR,
                     api_base   = FASTAPI_BASE)
      rmarkdown::render(
        file.path("reports", "student_report.Rmd"),
        output_file = file,
        params      = params,
        envir       = new.env(parent = globalenv())
      )
    }
  )
}

# ── Helper: NULL coalescing ───────────────────────────────────────────────────
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b
