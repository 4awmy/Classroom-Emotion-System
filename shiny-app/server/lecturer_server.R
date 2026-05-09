# lecturer_server.R - Server logic for Lecturer Portal (Schema v3 Hybrid)

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

  # Reactive data - All emotions
  all_emotions <- shiny::reactive({
    shiny::invalidateLater(10000, session)
    safe_query("SELECT * FROM emotion_log")
  })

  # Reactive: Get classes assigned to this lecturer
  my_classes <- shiny::reactive({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT c.*, cr.title as course_title FROM classes c JOIN courses cr ON c.course_id = cr.course_id WHERE c.lecturer_id = '%s'", uid)
    safe_query(sql)
  })

  # Reactive: Get past lectures for this lecturer
  my_past_lectures <- shiny::reactive({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT * FROM lectures WHERE lecturer_id = '%s' AND end_time IS NOT NULL ORDER BY start_time DESC", uid)
    safe_query(sql)
  })

  # ========================================================================
  # Tab A: Personal Info
  # ========================================================================
  output$lec_profile_card <- renderUI({
    tagList(
      div(class="profile-info",
        h4(paste("Name:", if (!is.null(session_state$name)) session_state$name else "N/A")),
        p(paste("ID:", if (!is.null(session_state$user_id)) session_state$user_id else "N/A")),
        p(paste("Email:", if (!is.null(session_state$email)) session_state$email else "N/A")),
        span(class="label label-primary", "Lecturer Account")
      )
    )
  })

  # ========================================================================
  # Tab B: Schedule
  # ========================================================================
  output$lec_schedule_table <- DT::renderDataTable({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT cs.day_of_week, cs.start_time, cs.end_time, c.room, cr.title 
                    FROM class_schedule cs 
                    JOIN classes c ON cs.class_id = c.class_id 
                    JOIN courses cr ON c.course_id = cr.course_id 
                    WHERE c.lecturer_id = '%s'", uid)
    data <- safe_query(sql)
    DT::datatable(data, options = list(pageLength = 10))
  })

  # ========================================================================
  # Tab C: My Classes
  # ========================================================================
  output$lec_classes_grid <- renderUI({
    classes <- my_classes()
    if (nrow(classes) == 0) return("No classes assigned. Contact Admin.")
    
    # Create boxes individually for safety
    box_list <- list()
    for (i in seq_len(nrow(classes))) {
      box_list[[i]] <- column(4,
        shinydashboard::box(
          title = classes$class_id[i], status = "primary", solidHeader = TRUE, width = NULL,
          h4(classes$course_title[i]),
          p(paste("Section:", classes$section_name[i])),
          p(paste("Room:", classes$room[i])),
          tags$hr(),
          p(strong("Status:"), "Active Section")
        )
      )
    }
    do.call(fluidRow, box_list)
  })

  # ========================================================================
  # Tab F: Live Dashboard
  # ========================================================================
  
  output$lec_live_course_selector <- renderUI({
    classes <- my_classes()
    if (nrow(classes) == 0) return(p("No courses available."))
    
    courses_df <- unique(classes[, c("course_id", "course_title")])
    choices <- setNames(courses_df$course_id, courses_df$course_title)
    selectInput("lec_live_selected_course", "Select Course:", choices = choices)
  })

  output$lec_live_class_selector <- renderUI({
    req(input$lec_live_selected_course)
    classes <- my_classes()
    filtered <- classes[classes$course_id == input$lec_live_selected_course, ]
    
    if (nrow(filtered) == 0) return(p("No classes for this course."))
    
    choices <- setNames(filtered$class_id, paste("Section:", filtered$section_name))
    selectInput("lec_live_selected_class", "Select Section:", choices = choices)
  })

  output$lec_live_schedule_info <- renderUI({
    req(input$lec_live_selected_class)
    classes <- my_classes()
    row <- classes[classes$class_id == input$lec_live_selected_class, ]
    if (nrow(row) == 0) return(NULL)
    p(style="color: #666; font-style: italic;",
      paste("Room:", row$room, "| Section:", row$section_name, "| Course ID:", row$course_id)
    )
  })

  # Start Session Observer
  shiny::observeEvent(input$lec_live_start, {
    cid <- input$lec_live_selected_class
    req(cid)
    
    lecture_id <- paste0(cid, "_", format(Sys.time(), "%Y%m%d_%H%M"))
    
    body <- list(
      lecture_id = lecture_id,
      lecturer_id = if (!is.null(session_state$user_id)) session_state$user_id else "unknown",
      title = paste("Live Session:", cid),
      context = "lecture"
    )
    
    res <- api_call("/session/start", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      shiny::updateTextInput(session, "active_lecture_id_hidden", value = lecture_id)
      shinyalert::shinyalert("Live!", paste("Session", lecture_id, "is now active."), type = "success")
    }
  })

  output$lec_live_stream_ui <- renderUI({
    lecture_id <- input$active_lecture_id_hidden
    if (is.null(lecture_id) || nchar(lecture_id) == 0) {
       return(div(style="height:400px; display:flex; align-items:center; justify-content:center; background:#f8f9fa; border:2px dashed #ddd;", 
                  "Select a class and click 'Start Session' to see the feed."))
    }
    tags$img(src = paste0(FASTAPI_BASE, "/session/video_feed/", lecture_id), style="width:100%; border-radius:8px;")
  })

  # Real-time Stats Polling
  live_stats_timer <- shiny::reactiveTimer(5000)

  live_data <- shiny::reactive({
    live_stats_timer()
    lecture_id <- input$active_lecture_id_hidden
    if (is.null(lecture_id) || nchar(lecture_id) == 0) return(NULL)
    
    emotions <- safe_query(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s'", lecture_id))
    attendance <- safe_query(sprintf("SELECT * FROM attendance_log WHERE lecture_id = '%s'", lecture_id))
    
    list(emotions = emotions, attendance = attendance)
  })

  output$lec_live_attendance_count <- shinydashboard::renderInfoBox({
    data <- live_data()
    count <- if(!is.null(data) && nrow(data$attendance) > 0) nrow(data$attendance) else 0
    shinydashboard::infoBox("Attendance", count, icon = icon("users"), color = "blue", fill = TRUE)
  })

  output$lec_live_gauge <- plotly::renderPlotly({
    data <- live_data()
    if (is.null(data) || nrow(data$emotions) == 0) return(plotly::plot_ly())
    
    val <- mean(data$emotions$engagement_score, na.rm=TRUE)
    if (is.nan(val)) val <- 0
    plotly::plot_ly(type = "indicator", mode = "gauge+number", value = val,
                   gauge = list(axis = list(range = list(0, 1)), bar = list(color = "#002147")))
  })

  output$lec_live_confusion_ticker <- renderUI({
    data <- live_data()
    if (is.null(data) || nrow(data$emotions) == 0) return(p("No data yet."))
    
    latest <- data$emotions |>
      dplyr::group_by(student_id) |>
      dplyr::filter(timestamp == max(timestamp)) |>
      dplyr::ungroup()
    
    confused <- latest[latest$emotion %in% c("Confused", "Frustrated"), ]
    if (nrow(confused) == 0) return(p("Class is doing well!"))
    
    tags$ul(
      lapply(seq_len(nrow(confused)), function(i) {
        tags$li(paste("Student", confused$student_id[i], "is", confused$emotion[i]))
      })
    )
  })

  # ========================================================================
  # Tab G: Reports & Analytics
  # ========================================================================
  
  output$lec_report_course_selector <- renderUI({
    classes <- my_classes()
    if (nrow(classes) == 0) return(p("No courses available."))
    courses_df <- unique(classes[, c("course_id", "course_title")])
    choices <- setNames(courses_df$course_id, courses_df$course_title)
    selectInput("lec_report_selected_course", "Select Course:", choices = choices)
  })

  output$lec_report_class_selector <- renderUI({
    req(input$lec_report_selected_course)
    classes <- my_classes()
    filtered <- classes[classes$course_id == input$lec_report_selected_course, ]
    choices <- setNames(filtered$class_id, paste("Section:", filtered$section_name))
    selectInput("lec_report_selected_class", "Select Section:", choices = choices)
  })

  output$lec_report_session_selector <- renderUI({
    req(input$lec_report_selected_class)
    past <- my_past_lectures()
    filtered <- past[past$class_id == input$lec_report_selected_class, ]
    if (nrow(filtered) == 0) return(p("No past sessions."))
    choices <- setNames(filtered$lecture_id, paste(filtered$start_time, "-", filtered$title))
    selectInput("lec_report_selected_session", "Select Session:", choices = choices)
  })

  report_data <- reactive({
    req(input$lec_report_selected_session)
    emotions <- safe_query(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s'", input$lec_report_selected_session))
    attendance <- safe_query(sprintf("SELECT * FROM attendance_log WHERE lecture_id = '%s'", input$lec_report_selected_session))
    list(emotions = emotions, attendance = attendance)
  })

  output$lec_report_emotion_pie <- plotly::renderPlotly({
    data <- report_data()
    if (is.null(data) || nrow(data$emotions) == 0) return(NULL)
    summary <- data$emotions |> dplyr::group_by(emotion) |> dplyr::summarise(count = n(), .groups="drop")
    plotly::plot_ly(summary, labels = ~emotion, values = ~count, type = 'pie')
  })

  output$lec_report_engagement_line <- plotly::renderPlotly({
    data <- report_data()
    if (is.null(data) || nrow(data$emotions) == 0) return(NULL)
    timeline <- data$emotions |> dplyr::group_by(timestamp) |> dplyr::summarise(eng = mean(engagement_score, na.rm=TRUE), .groups="drop")
    plotly::plot_ly(timeline, x = ~timestamp, y = ~eng, type = 'scatter', mode = 'lines')
  })

  output$lec_report_attendance_table <- DT::renderDataTable({
    data <- report_data()
    if (is.null(data) || nrow(data$attendance) == 0) return(data.frame())
    DT::datatable(data$attendance)
  })

  output$lec_report_student_selector_ui <- renderUI({
    data <- report_data()
    if (is.null(data) || nrow(data$emotions) == 0) return(NULL)
    selectInput("lec_report_selected_student", "Select Student:", choices = unique(data$emotions$student_id))
  })

  output$lec_report_student_timeline <- plotly::renderPlotly({
    req(input$lec_report_selected_student)
    data <- report_data()
    df <- data$emotions[data$emotions$student_id == input$lec_report_selected_student, ]
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score, type = 'scatter', mode = 'lines+markers')
  })

  # Tab H: Exams
  output$lec_exam_table <- DT::renderDataTable({
    data <- safe_query("SELECT * FROM exams")
    DT::datatable(data)
  })
}
