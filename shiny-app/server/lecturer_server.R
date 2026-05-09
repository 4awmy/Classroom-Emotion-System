# lecturer_server.R - Server logic for Lecturer Portal (Schema v2)

lecturer_server <- function(input, output, session, session_state) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/clustering.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # Helper: Null-safe Database Query
  # ========================================================================
  safe_query <- function(sql) {
    if (is.null(con)) return(data.frame())
    tryCatch({
      dbGetQuery(con, sql)
    }, error = function(e) {
      message("DB Error: ", e$message)
      data.frame()
    })
  }

  # Reactive data
  emotions_data <- shiny::reactive({
    shiny::invalidateLater(2000, session)
    safe_query("SELECT * FROM emotion_log")
  })

  # ========================================================================
  # Tab A: Personal Info
  # ========================================================================
  output$lec_profile_card <- renderUI({
    req(session_state$logged_in)
    tagList(
      h4(paste("Name:", session_state$name)),
      p(paste("ID:", session_state$user_id)),
      p(paste("Email:", session_state$email)),
      p(paste("Role: Lecturer"))
    )
  })

  # ========================================================================
  # Tab B: Schedule
  # ========================================================================
  output$lec_schedule_table <- DT::renderDataTable({
    req(session_state$user_id)
    sql <- sprintf("SELECT cs.* FROM class_schedule cs JOIN classes c ON cs.class_id = c.class_id WHERE c.lecturer_id = '%s'", session_state$user_id)
    data <- safe_query(sql)
    DT::datatable(data, options = list(pageLength = 10))
  })

  # ========================================================================
  # Tab C: My Classes
  # ========================================================================
  output$lec_classes_grid <- renderUI({
    req(session_state$user_id)
    sql <- sprintf("SELECT * FROM classes WHERE lecturer_id = '%s'", session_state$user_id)
    classes <- safe_query(sql)
    
    if (nrow(classes) == 0) return("No classes assigned.")
    
    fluidRow(
      lapply(1:nrow(classes), function(i) {
        column(4,
          shinydashboard::box(
            title = classes$class_id[i], status = "info", width = NULL,
            p(paste("Section:", classes$section_name[i])),
            p(paste("Room:", classes$room[i])),
            actionButton(paste0("start_", classes$class_id[i]), "Start Class", class="btn-xs btn-success")
          )
        )
      })
    )
  })

  # ========================================================================
  # Tab D: Materials
  # ========================================================================
  output$lec_materials_table <- DT::renderDataTable({
    data <- safe_query("SELECT * FROM materials")
    DT::datatable(data)
  })

  # ========================================================================
  # Tab E: Attendance
  # ========================================================================
  output$lec_attendance_grid <- renderUI({
    "Attendance visualization goes here."
  })

  # ========================================================================
  # Tab F: Live Dashboard (CRITICAL FIX)
  # ========================================================================
  
  # Start Session Observer
  shiny::observeEvent(input$lec_live_start, {
    lid <- trimws(input$lec_live_lecture)
    if (nchar(lid) == 0) {
      shinyalert::shinyalert("Error", "Please enter a Lecture ID.", type = "error")
      return()
    }
    
    body <- list(
      lecture_id = lid,
      lecturer_id = session_state$user_id,
      title = paste("Live Session -", lid),
      context = "lecture"
    )
    
    res <- api_call("/session/start", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      shinyalert::shinyalert("Success", "Live session started and Vision Pipeline is active.", type = "success")
    }
  })

  output$lec_live_stream_ui <- renderUI({
    lecture_id <- input$lec_live_lecture
    if (nchar(lecture_id) == 0) return(div(style="color:#888;padding:100px;text-align:center;","Enter Lecture ID and click Start Session"))
    tags$img(src = paste0(FASTAPI_BASE, "/session/video_feed/", lecture_id), style="width:100%; border-radius:8px; border: 2px solid #002147;")
  })

  output$lec_live_gauge <- plotly::renderPlotly({
    # Real-time Gauge logic using emotions_data reactive
    data <- emotions_data()
    lecture_id <- input$lec_live_lecture
    if (nchar(lecture_id) == 0 || nrow(data) == 0) return(plotly::plot_ly())
    
    val <- mean(data$engagement_score[data$lecture_id == lecture_id], na.rm=TRUE)
    if (is.nan(val)) val <- 0
    
    plotly::plot_ly(
      type = "indicator",
      mode = "gauge+number",
      value = val,
      title = list(text = "Engagement"),
      gauge = list(
        axis = list(range = list(0, 1)),
        bar = list(color = "#002147"),
        steps = list(
          list(range = c(0, 0.4), color = "#F44336"),
          list(range = c(0.4, 0.7), color = "#FF9800"),
          list(range = c(0.7, 1), color = "#4CAF50")
        )
      )
    )
  })

  # ========================================================================
  # Tab H: Exams
  # ========================================================================
  output$lec_exam_table <- DT::renderDataTable({
    data <- safe_query("SELECT * FROM exams")
    DT::datatable(data)
  })

  output$lec_exam_incidents <- DT::renderDataTable({
    data <- safe_query("SELECT * FROM incidents")
    DT::datatable(data)
  })
}
