# lecturer_server.R - v3.6.0 Production State Machine

lecturer_server <- function(input, output, session, session_state) {
  # Load R modules
  source("modules/engagement_score.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # ========================================================================
  # STATE & REACTIVES
  # ========================================================================
  db_url <- Sys.getenv("DATABASE_URL", "")
  
  safe_db_get <- function(query) {
    if (db_url == "") return(data.frame())
    tryCatch({
      con <- dbConnect(RPostgres::Postgres(), url = db_url)
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      return(res)
    }, error = function(e) { message(e); data.frame() })
  }

  # Navigation State
  selected_course_id <- reactiveVal(NULL)
  selected_class_id <- reactiveVal(NULL)
  
  # Session State Machine
  # not_started, live, ended
  current_session_status <- reactiveVal("not_started")
  current_lecture_id <- reactiveVal("")
  session_summary_data <- reactiveVal(NULL)

  # 1. Fetch real classes for THIS lecturer
  lecturer_courses_data <- shiny::reactive({
    uid <- session_state$user_id
    if (is.null(uid)) return(data.frame())
    query <- sprintf("SELECT co.title as course, co.course_id as code, cl.class_id as class 
                      FROM classes cl 
                      JOIN courses co ON cl.course_id = co.course_id 
                      WHERE cl.lecturer_id = '%s'", uid)
    safe_db_get(query)
  })

  # Polling Session Status
  shiny::observe({
    req(current_lecture_id() != "")
    shiny::invalidateLater(3000, session)
    
    status_data <- api_call(paste0("/session/status/", current_lecture_id()), auth_token = session_state$token)
    if (!is.null(status_data)) {
      current_session_status(status_data$status)
      if (status_data$status == "ended") {
        session_summary_data(status_data)
      }
    }
  })

  # Live Data Refreshers (Only active when status is 'live')
  live_emotions <- reactive({
    req(current_lecture_id() != "")
    if (current_session_status() == "live") {
      invalidateLater(2000, session)
    }
    safe_db_get(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp DESC", current_lecture_id()))
  })

  live_attendance <- reactive({
    req(current_lecture_id() != "")
    if (current_session_status() == "live") {
      invalidateLater(2000, session)
    }
    query <- sprintf("
      SELECT s.student_id, s.name, s.photo_url, al.status, al.timestamp, al.snapshot_url
      FROM enrollments e
      JOIN students s ON e.student_id = s.student_id
      LEFT JOIN attendance_log al ON s.student_id = al.student_id AND al.lecture_id = '%s'
      WHERE e.class_id = (SELECT class_id FROM lectures WHERE lecture_id = '%s' LIMIT 1)
    ", current_lecture_id(), current_lecture_id())
    safe_db_get(query)
  })

  # ========================================================================
  # UI OUTPUTS: NAVIGATION
  # ========================================================================
  output$lecturer_course_table <- shiny::renderUI({
    lecturer_attendance_course_table(courses_df = lecturer_courses_data())
  })

  shiny::observeEvent(input$lecturer_course_nav, {
    nav <- input$lecturer_course_nav
    df <- lecturer_courses_data()
    row <- df[nav$row, ]
    
    selected_course_id(row$code)
    selected_class_id(row$class)
    
    # Auto-generate Lecture ID for this week/class
    # We use a placeholder logic: W[CurrentWeek]-[ClassID]
    lec_id <- sprintf("LEC_%s_%s", row$class, format(Sys.Date(), "%Y%W"))
    current_lecture_id(lec_id)
    
    if (nav$dest == "live") {
      updateTabItems(session, "lecturer_menu", "lec_live")
    } else {
      updateTabItems(session, "lecturer_menu", "lec_reports")
    }
  })

  # ========================================================================
  # UI OUTPUTS: LIVE DASHBOARD (STATE MACHINE RENDERING)
  # ========================================================================
  
  output$lec_live_course_selector <- renderUI({
    df <- lecturer_courses_data()
    selectInput("live_course_id", "1. Select Course", choices = setNames(df$code, df$course), selected = selected_course_id())
  })

  output$lec_live_class_selector <- renderUI({
    req(input$live_course_id)
    uid <- session_state$user_id
    df <- safe_db_get(sprintf("SELECT class_id FROM classes WHERE course_id = '%s' AND lecturer_id = '%s'", input$live_course_id, uid))
    selectInput("live_class_id", "2. Select Section", choices = df$class_id, selected = selected_class_id())
  })

  output$lec_live_session_info <- renderUI({
    req(input$live_class_id)
    status <- current_session_status()
    
    if (status == "not_started") {
      tags$div(class="alert alert-info", "Waiting for lecturer to start camera.")
    } else if (status == "live") {
      tags$div(class="alert alert-success", "Session is LIVE. AI is monitoring.")
    } else {
      tags$div(class="alert alert-warning", "Session ENDED. Reviewing results.")
    }
  })

  output$lecturer_live_stream_ui <- renderUI({
    status <- current_session_status()
    if (status == "live") {
      tags$img(src = sprintf("%s/api/session/video_feed/%s", Sys.getenv("FASTAPI_BASE_URL", ""), current_lecture_id()), 
               style="width: 100%; border-radius: 8px;")
    } else if (status == "ended") {
      # Show Summary Box
      summary <- session_summary_data()
      tags$div(style="padding: 40px; color: white; text-align: left;",
        h3("Session Summary"),
        hr(),
        p(strong("Total Attendance: "), summary$attendance_count),
        p(strong("Emotion Data Points: "), summary$emotion_count),
        p(strong("AI Checks Performed: "), summary$check_count),
        p(strong("Frames Captured: "), summary$frames_captured),
        br(),
        actionButton("view_attendance_review", "ATTENDANCE REVIEW", class="btn-primary"),
        actionButton("hard_reset_session", "HARD RESET SESSION", class="btn-warning")
      )
    } else {
      tags$div(style="padding: 100px; color: #888;", icon("video-slash", class="fa-4x"), br(), "Camera Offline")
    }
  })

  output$lecturer_attendance_grid <- renderUI({
    data <- live_attendance()
    if (nrow(data) == 0) return(tags$div("No students enrolled.", style="color: #999;"))

    tags$div(class = "student-card-grid",
      lapply(seq_len(nrow(data)), function(i) {
        row <- data[i, ]
        is_present <- !is.na(row$status) && row$status == "PRESENT"
        
        # Snapshot replacement logic
        img_src <- if (!is.na(row$snapshot_url) && nchar(row$snapshot_url) > 0) {
            sprintf("%s/api/attendance/snapshot/%s/%s", Sys.getenv("FASTAPI_BASE_URL", ""), current_lecture_id(), row$student_id)
        } else {
            row$photo_url
        }

        tags$div(class = paste("student-card", if(is_present) "present" else "absent"),
          tags$img(src = img_src, class = "student-img"),
          tags$div(class = "student-name", row$name),
          tags$div(class = "student-status", if(is_present) "IDENTIFIED" else "WAITING...")
        )
      })
    )
  })

  output$lecturer_live_session_actions <- renderUI({
    status <- current_session_status()
    if (status == "not_started") {
      actionButton("start_session_btn", "START SESSION", class="btn-success btn-lg btn-block")
    } else if (status == "live") {
      actionButton("stop_session_btn", "END SESSION", class="btn-danger btn-lg btn-block")
    } else {
      # Buttons moved to summary box
      NULL
    }
  })

  # --- ACTION HANDLERS ---
  
  shiny::observeEvent(input$start_session_btn, {
    req(input$live_class_id)
    body <- list(
      lecture_id = current_lecture_id(),
      class_id = input$live_class_id,
      lecturer_id = session_state$user_id,
      title = sprintf("Session %s", current_lecture_id())
    )
    api_call("/session/start", method="POST", body=body, auth_token=session_state$token)
    current_session_status("live")
    
    # Gemini Integration Check on Session Start
    api_call(paste0("/gemini/refresher?lecture_id=", current_lecture_id()), auth_token = session_state$token)
  })

  shiny::observeEvent(input$stop_session_btn, {
    api_call("/session/end", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
    current_session_status("ended")
  })

  shiny::observeEvent(input$hard_reset_session, {
    shinyalert::shinyconfirm("Hard Reset?", "This will wipe all session data permanently. Are you sure?", type="warning", callbackR = function(val) {
      if (val) {
        api_call("/session/reset", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
        current_session_status("not_started")
        session_summary_data(NULL)
      }
    })
  })

  # ========================================================================
  # LMS MATERIALS (WEEKLY)
  # ========================================================================
  output$lecturer_materials_table <- DT::renderDataTable({
    week <- input$lecturer_material_week
    req(selected_course_id())
    
    # Fetch materials for this course and week
    df <- safe_db_get(sprintf("SELECT title, uploaded_at, drive_link FROM materials WHERE lecture_id LIKE 'LEC_%%'"))
    # (In a real app, we'd filter by course and week properly in SQL)
    DT::datatable(df, options = list(pageLength = 10))
  })

  shiny::observeEvent(input$lecturer_material_upload, {
    req(input$lecturer_material_file, selected_class_id())
    
    # Logic to upload file and trigger Gemini parsing
    shinyalert::shinyalert("Processing", "Gemini is analyzing your slides...", type="info")
    # (API call to /upload/material would go here)
  })

  # ========================================================================
  # BRANDING & LOGOS
  # ========================================================================
  # Placeholder for logos (User should place them in www/ folder)
  # C:\Users\omarh\OneDrive\Desktop\Temp\logos -> shiny-app/www/
  output$dashboard_logo <- renderUI({
    tags$img(src = "logo.png", style = "height: 50px; margin: 10px;")
  })

  # ... other analytics outputs matching the 2x2 grid ...
}
