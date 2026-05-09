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
  # Tab: Materials (UPLOAD LOGIC)
  # ========================================================================
  
  mat_refresh <- reactiveVal(0)

  output$lec_material_class_selector <- renderUI({
    df <- my_classes()
    choices <- if(nrow(df) > 0) setNames(df$class_id, df$course_title) else c("No Classes" = "")
    selectInput("lec_mat_selected_class", "Select Class:", choices = choices)
  })

  output$lec_materials_table <- DT::renderDataTable({
    mat_refresh()
    req(session_state$user_id)
    sql <- sprintf("SELECT m.*, l.title as session_title FROM materials m LEFT JOIN lectures l ON m.lecture_id = l.lecture_id WHERE m.lecturer_id = '%s'", session_state$user_id)
    DT::datatable(safe_query(sql))
  })

  shiny::observeEvent(input$lec_material_upload_btn, {
    req(input$lec_material_file, input$lec_mat_selected_class, input$lec_material_title)
    
    # We need a lecture_id to attach to. For floating materials, we use a placeholder or create a "Shell" lecture.
    # For now, we'll use 'GENERAL' as the lecture_id.
    
    file_path <- input$lec_material_file$datapath
    file_name <- input$lec_material_file$name
    
    # Call FastAPI Upload
    # Multipart form data in R httr2
    req_url <- paste0(FASTAPI_BASE, "/upload/material")
    
    tryCatch({
      res <- httr::POST(
        req_url,
        body = list(
          lecture_id = "GENERAL",
          lecturer_id = session_state$user_id,
          title = input$lec_material_title,
          file = httr::upload_file(file_path, type = "application/pdf")
        ),
        httr::add_headers(Authorization = paste("Bearer", session_state$token))
      )
      
      if (httr::status_code(res) < 300) {
        shinyalert::shinyalert("Success", "Material uploaded successfully!", type="success")
        mat_refresh(mat_refresh() + 1)
      } else {
        shinyalert::shinyalert("Upload Error", httr::content(res, "text"), type="error")
      }
    }, error = function(e) {
      shinyalert::shinyalert("Network Error", e$message, type="error")
    })
  })

  # ========================================================================
  # Tab: Live Dashboard
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
    choices <- setNames(filtered$class_id, paste("Section:", filtered$section_name))
    selectInput("lec_live_selected_class", "Select Section:", choices = choices)
  })

  shiny::observeEvent(input$lec_live_start, {
    cid <- input$lec_live_selected_class
    req(cid)
    lecture_id <- paste0(cid, "_", format(Sys.time(), "%Y%m%d_%H%M"))
    body <- list(lecture_id = lecture_id, lecturer_id = session_state$user_id, title = paste("Live:", cid), context = "lecture")
    res <- api_call("/session/start", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      shiny::updateTextInput(session, "active_lecture_id_hidden", value = lecture_id)
      shinyalert::shinyalert("Live!", paste("Session", lecture_id, "active."), type = "success")
    }
  })

  output$lec_live_stream_ui <- renderUI({
    lid <- input$active_lecture_id_hidden
    if (is.null(lid) || lid == "") return(div(class="placeholder", "Waiting for session start..."))
    tags$img(src = paste0(FASTAPI_BASE, "/session/video_feed/", lid), style="width:100%; border-radius:8px;")
  })

  # Real-time stats
  live_stats_timer <- shiny::reactiveTimer(5000)
  output$lec_live_attendance_count <- shinydashboard::renderInfoBox({
    live_stats_timer()
    lid <- input$active_lecture_id_hidden
    req(lid)
    data <- safe_query(sprintf("SELECT count(*) FROM attendance_log WHERE lecture_id = '%s'", lid))
    shinydashboard::infoBox("Attendance", data[1,1], icon = icon("users"), color = "blue", fill = TRUE)
  })

  # (Remaining logic for Reports/Exams kept...)
}
