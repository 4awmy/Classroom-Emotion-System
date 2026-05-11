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
        is_present <- !is.na(row$status) && (toupper(row$status) == "PRESENT")
        
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
  })

  shiny::observeEvent(input$stop_session_btn, {
    api_call("/session/end", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
    current_session_status("ended")
  })

  shiny::observeEvent(input$hard_reset_session, {
    api_call("/session/reset", method="POST", body=list(lecture_id = current_lecture_id()), auth_token=session_state$token)
    current_session_status("not_started")
    session_summary_data(NULL)
  })

  # ========================================================================
  # ANALYTICS & REPORTS (2X2 GRID)
  # ========================================================================
  output$lec_report_course_selector <- renderUI({
    df <- lecturer_courses_data()
    selectInput("rep_course_id", "Select Course", choices = setNames(df$code, df$course), selected = selected_course_id())
  })

  output$lec_report_class_selector <- renderUI({
    req(input$rep_course_id)
    df <- safe_db_get(sprintf("SELECT class_id FROM classes WHERE course_id = '%s'", input$rep_course_id))
    selectInput("rep_class_id", "Select Class", choices = df$class_id, selected = selected_class_id())
  })

  output$lec_report_session_selector <- renderUI({
    req(input$rep_class_id)
    df <- safe_db_get(sprintf("SELECT lecture_id, title FROM lectures WHERE class_id = '%s' ORDER BY created_at DESC", input$rep_class_id))
    selectInput("rep_lecture_id", "Select Session", choices = setNames(df$lecture_id, df$title))
  })

  output$lec_report_emotion_pie <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT emotion, count(*) as count FROM emotion_log WHERE lecture_id = '%s' GROUP BY emotion", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, labels = ~emotion, values = ~count, type = 'pie')
  })

  output$lec_report_engagement_line <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT timestamp, engagement_score FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score, type = 'scatter', mode = 'lines')
  })

  output$lec_report_attendance_table <- DT::renderDataTable({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT s.name, al.status, al.timestamp FROM students s JOIN attendance_log al ON s.student_id = al.student_id WHERE al.lecture_id = '%s'", input$rep_lecture_id))
    DT::datatable(df)
  })

  output$lec_report_student_clusters <- plotly::renderPlotly({
    req(input$rep_lecture_id)
    df <- safe_db_get(sprintf("SELECT student_id, avg(engagement_score) as avg_score FROM emotion_log WHERE lecture_id = '%s' GROUP BY student_id", input$rep_lecture_id))
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, x = ~student_id, y = ~avg_score, type = 'bar')
  })

  # --- LIVE GAUGE ---
  output$lecturer_d1_gauge <- plotly::renderPlotly({
    df <- live_emotions()
    val <- if (nrow(df) > 0) mean(df$engagement_score, na.rm=TRUE) else 0
    plotly::plot_ly(type = "indicator", mode = "gauge+number", value = val,
                   gauge = list(axis = list(range = list(0, 1)), bar = list(color = "#002147")))
  })

  output$lecturer_live_sentiment_ticker <- renderUI({
    df <- live_emotions()
    if (nrow(df) == 0) return(p("No data yet..."))
    latest <- head(df, 5)
    lapply(seq_len(nrow(latest)), function(i) {
      p(tags$span(style="color:#28a745", "[Live] "), 
        sprintf("Student detected with %s emotion.", latest$emotion[i]))
    })
  })

  # ========================================================================
  # LMS MATERIALS
  # ========================================================================
  output$lecturer_materials_table <- DT::renderDataTable({
    req(selected_course_id())
    df <- safe_db_get(sprintf("SELECT title, uploaded_at, drive_link FROM materials WHERE material_id LIKE 'MAT_%s%%'", selected_course_id()))
    DT::datatable(df)
  })

  # ========================================================================
  # DEBUG INFO
  # ========================================================================
  output$lecturer_debug_out <- renderText({
    db_status <- if(db_url != "") "DATABASE_URL Present" else "DATABASE_URL MISSING"
    courses_count <- if(!is.null(lecturer_courses_data())) nrow(lecturer_courses_data()) else "NULL"

    paste0(
      "--- Lecturer Debug ---\n",
      "User ID: ", session_state$user_id, "\n",
      "Role: ", session_state$role, "\n",
      "DB Status: ", db_status, "\n",
      "Classes Found: ", courses_count, "\n",
      "Lecture ID: ", current_lecture_id(), "\n",
      "Session Status: ", current_session_status()
    )
  })
}
