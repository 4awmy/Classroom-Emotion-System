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

  # Reactive data
  my_classes <- shiny::reactive({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT c.*, cr.title as course_title FROM classes c JOIN courses cr ON c.course_id = cr.course_id WHERE c.lecturer_id = '%s'", uid)
    safe_query(sql)
  })

  my_past_lectures <- shiny::reactive({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT * FROM lectures WHERE lecturer_id = '%s' AND end_time IS NOT NULL ORDER BY start_time DESC", uid)
    safe_query(sql)
  })

  # ========================================================================
  # Tab: Personal Info
  # ========================================================================
  output$lec_profile_card <- renderUI({
    classes <- my_classes()
    course_list <- if(nrow(classes) > 0) paste(unique(classes$course_title), collapse=", ") else "None"
    
    tagList(
      div(class="profile-info",
        h4(paste("Name:", if (!is.null(session_state$name)) session_state$name else "N/A")),
        p(paste("ID:", if (!is.null(session_state$user_id)) session_state$user_id else "N/A")),
        p(paste("Email:", if (!is.null(session_state$email)) session_state$email else "N/A")),
        tags$hr(),
        h5(strong("Teaching Load:")),
        p(paste("Courses:", course_list)),
        p(paste("Active Classes:", nrow(classes))),
        span(class="label label-primary", "Verified Lecturer")
      )
    )
  })

  # ========================================================================
  # Tab: Schedule
  # ========================================================================
  output$lec_schedule_table <- DT::renderDataTable({
    uid <- if (!is.null(session_state$user_id)) session_state$user_id else ""
    if (uid == "") return(data.frame())
    sql <- sprintf("SELECT cs.day_of_week, cs.start_time, cs.end_time, c.room, cr.title 
                    FROM class_schedule cs 
                    JOIN classes c ON cs.class_id = c.class_id 
                    JOIN courses cr ON c.course_id = cr.course_id 
                    WHERE c.lecturer_id = '%s'", uid)
    DT::datatable(safe_query(sql))
  })

  # ========================================================================
  # Tab: Classes Grid
  # ========================================================================
  output$lec_classes_grid <- renderUI({
    classes <- my_classes()
    if (nrow(classes) == 0) return(p("No classes assigned."))
    box_list <- list()
    for (i in seq_len(nrow(classes))) {
      box_list[[i]] <- column(4,
        shinydashboard::box(
          title = classes$class_id[i], status = "primary", solidHeader = TRUE, width = NULL,
          h4(classes$course_title[i]),
          p(paste("Section:", classes$section_name[i])),
          p(paste("Room:", classes$room[i])),
          tags$hr(), p(strong("Status:"), "Active Section")
        )
      )
    }
    do.call(fluidRow, box_list)
  })

  # ========================================================================
  # Tab: Materials
  # ========================================================================
  mat_refresh <- reactiveVal(0)
  output$lec_material_class_selector <- renderUI({
    df <- my_classes(); choices <- if(nrow(df) > 0) setNames(df$class_id, df$course_title) else c("No Classes" = "")
    selectInput("lec_mat_selected_class", "Select Class:", choices = choices)
  })
  output$lec_materials_table <- DT::renderDataTable({
    mat_refresh(); req(session_state$user_id)
    sql <- sprintf("SELECT m.*, l.title as session_title FROM materials m LEFT JOIN lectures l ON m.lecture_id = l.lecture_id WHERE m.lecturer_id = '%s'", session_state$user_id)
    DT::datatable(safe_query(sql))
  })
  shiny::observeEvent(input$lec_material_upload_btn, {
    req(input$lec_material_file, input$lec_mat_selected_class, input$lec_material_title)
    tryCatch({
      res <- httr::POST(paste0(FASTAPI_BASE, "/upload/material"),
        body = list(lecture_id = "GENERAL", lecturer_id = session_state$user_id, title = input$lec_material_title, file = httr::upload_file(input$lec_material_file$datapath, type = "application/pdf")),
        httr::add_headers(Authorization = paste("Bearer", session_state$token))
      )
      if (httr::status_code(res) < 300) { shinyalert::shinyalert("Success", "Material uploaded!", type="success"); mat_refresh(mat_refresh() + 1) }
    }, error = function(e) { shinyalert::shinyalert("Error", e$message, type="error") })
  })

  # ========================================================================
  # Tab: Live Dashboard (FIXED STATS & END BUTTON)
  # ========================================================================
  
  output$lec_live_course_selector <- renderUI({
    classes <- my_classes(); if (nrow(classes) == 0) return(p("No courses available."))
    courses_df <- unique(classes[, c("course_id", "course_title")])
    selectInput("lec_live_selected_course", "Select Course:", choices = setNames(courses_df$course_id, courses_df$course_title))
  })

  output$lec_live_class_selector <- renderUI({
    req(input$lec_live_selected_course); classes <- my_classes()
    filtered <- classes[classes$course_id == input$lec_live_selected_course, ]
    selectInput("lec_live_selected_class", "Select Section:", choices = setNames(filtered$class_id, paste("Section:", filtered$section_name)))
  })

  shiny::observeEvent(input$lec_live_start, {
    cid <- input$lec_live_selected_class; req(cid)
    lecture_id <- paste0(cid, "_", format(Sys.time(), "%Y%m%d_%H%M"))
    body <- list(lecture_id = lecture_id, lecturer_id = session_state$user_id, title = paste("Live:", cid), context = "lecture")
    res <- api_call("/session/start", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      shiny::updateTextInput(session, "active_lecture_id_hidden", value = lecture_id)
      shinyalert::shinyalert("Live!", paste("Session", lecture_id, "active."), type = "success")
    }
  })

  shiny::observeEvent(input$lec_live_end, {
    lid <- input$active_lecture_id_hidden
    req(lid); if(lid == "") return()
    res <- api_call("/session/end", method = "POST", body = list(lecture_id = lid), auth_token = session_state$token)
    if (!is.null(res)) {
      shiny::updateTextInput(session, "active_lecture_id_hidden", value = "")
      shinyalert::shinyalert("Ended", "Session closed successfully.", type = "info")
    }
  })

  output$lec_live_stream_ui <- renderUI({
    lid <- input$active_lecture_id_hidden
    if (is.null(lid) || lid == "") return(div(style="height:300px; display:flex; align-items:center; justify-content:center; background:#eee;", "Wait for start..."))
    tags$img(src = paste0(FASTAPI_BASE, "/session/video_feed/", lid), style="width:100%; border-radius:8px;")
  })

  # Live Stats Logic
  live_stats_timer <- shiny::reactiveTimer(3000)
  
  output$lec_live_attendance_count <- shinydashboard::renderInfoBox({
    live_stats_timer(); lid <- input$active_lecture_id_hidden; req(lid); if(lid == "") return(NULL)
    data <- safe_query(sprintf("SELECT count(DISTINCT student_id) FROM attendance_log WHERE lecture_id = '%s'", lid))
    shinydashboard::infoBox("Attendance", data[1,1], icon = icon("users"), color = "blue", fill = TRUE)
  })

  output$lec_live_gauge <- plotly::renderPlotly({
    live_stats_timer(); lid <- input$active_lecture_id_hidden; req(lid); if(lid == "") return(NULL)
    data <- safe_query(sprintf("SELECT avg(engagement_score) FROM emotion_log WHERE lecture_id = '%s'", lid))
    val <- if(!is.na(data[1,1])) data[1,1] else 0
    plotly::plot_ly(type = "indicator", mode = "gauge+number", value = val,
                   gauge = list(axis = list(range = list(0, 1)), bar = list(color = "#002147")))
  })

  output$lec_live_confusion_ticker <- renderUI({
    live_stats_timer(); lid <- input$active_lecture_id_hidden; req(lid); if(lid == "") return(NULL)
    sql <- sprintf("SELECT student_id, emotion FROM emotion_log WHERE lecture_id = '%s' AND emotion IN ('Confused', 'Frustrated') ORDER BY timestamp DESC LIMIT 5", lid)
    confused <- safe_query(sql)
    if (nrow(confused) == 0) return(p("Class is stable."))
    tags$ul(lapply(seq_len(nrow(confused)), function(i) tags$li(paste("ID:", confused$student_id[i], "-", confused$emotion[i]))))
  })

  # ========================================================================
  # Tab: Reports & Analytics
  # ========================================================================
  output$lec_report_course_selector <- renderUI({
    classes <- my_classes(); selectInput("lec_report_selected_course", "Select Course:", choices = setNames(classes$course_id, classes$course_title))
  })
  output$lec_report_class_selector <- renderUI({
    req(input$lec_report_selected_course); classes <- my_classes(); filtered <- classes[classes$course_id == input$lec_report_selected_course, ]
    selectInput("lec_report_selected_class", "Select Section:", choices = setNames(filtered$class_id, filtered$section_name))
  })
  output$lec_report_session_selector <- renderUI({
    req(input$lec_report_selected_class); past <- my_past_lectures(); filtered <- past[past$class_id == input$lec_report_selected_class, ]
    if (nrow(filtered) == 0) return(p("No past sessions."))
    selectInput("lec_report_selected_session", "Select Session:", choices = setNames(filtered$lecture_id, paste(filtered$start_time, "-", filtered$title)))
  })

  report_data <- reactive({
    req(input$lec_report_selected_session)
    list(emotions = safe_query(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s'", input$lec_report_selected_session)),
         attendance = safe_query(sprintf("SELECT * FROM attendance_log WHERE lecture_id = '%s'", input$lec_report_selected_session)))
  })

  output$lec_report_emotion_pie <- plotly::renderPlotly({
    d <- report_data(); if (nrow(d$emotions) == 0) return(NULL)
    sum <- d$emotions |> dplyr::group_by(emotion) |> dplyr::summarise(count = n())
    plotly::plot_ly(sum, labels = ~emotion, values = ~count, type = 'pie')
  })

  output$lec_report_engagement_line <- plotly::renderPlotly({
    d <- report_data(); if (nrow(d$emotions) == 0) return(NULL)
    line <- d$emotions |> dplyr::group_by(timestamp) |> dplyr::summarise(eng = mean(engagement_score))
    plotly::plot_ly(line, x = ~timestamp, y = ~eng, type = 'scatter', mode = 'lines')
  })

  output$lec_report_attendance_table <- DT::renderDataTable({ DT::datatable(report_data()$attendance) })
  
  output$lec_attendance_table <- DT::renderDataTable({
    uid <- session_state$user_id; req(uid)
    sql <- sprintf("SELECT a.*, l.title FROM attendance_log a JOIN lectures l ON a.lecture_id = l.lecture_id WHERE l.lecturer_id = '%s'", uid)
    DT::datatable(safe_query(sql))
  })

  output$lec_exam_table <- DT::renderDataTable({ DT::datatable(safe_query("SELECT * FROM exams")) })
}
