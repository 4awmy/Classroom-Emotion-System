# lecturer_server.R - v3.6.0 Dashboard Logic

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

  active_lecture_id <- reactiveVal("")
  selected_course_id <- reactiveVal(NULL)
  selected_class_id <- reactiveVal(NULL)

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

  # 2. Live Data Refreshers
  live_emotions <- reactive({
    req(active_lecture_id() != "")
    invalidateLater(2000, session)
    safe_db_get(sprintf("SELECT * FROM emotion_log WHERE lecture_id = '%s' ORDER BY timestamp DESC", active_lecture_id()))
  })

  live_attendance <- reactive({
    req(active_lecture_id() != "")
    invalidateLater(2000, session)
    # Join with students to get profile pictures and names
    query <- sprintf("
      SELECT s.student_id, s.name, s.photo_url, al.status, al.timestamp, al.snapshot_url
      FROM enrollments e
      JOIN students s ON e.student_id = s.student_id
      LEFT JOIN attendance_log al ON s.student_id = al.student_id AND al.lecture_id = '%s'
      WHERE e.class_id = (SELECT class_id FROM lectures WHERE lecture_id = '%s' LIMIT 1)
    ", active_lecture_id(), active_lecture_id())
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
    
    if (nav$dest == "live") {
      selected_course_id(row$code)
      selected_class_id(row$class)
      updateTabItems(session, "lecturer_menu", "lec_live")
    } else {
      selected_course_id(row$code)
      selected_class_id(row$class)
      updateTabItems(session, "lecturer_menu", "lec_reports")
    }
  })

  # ========================================================================
  # UI OUTPUTS: LIVE DASHBOARD
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
    # Check if there is an active session or create new
    tagList(
      h4("Ready to Start"),
      p("Click 'Start Camera' below to begin.")
    )
  })

  output$lecturer_attendance_grid <- renderUI({
    data <- live_attendance()
    if (nrow(data) == 0) return(tags$div("No students enrolled in this class.", style="color: #999;"))

    tags$div(class = "student-card-grid",
      lapply(seq_len(nrow(data)), function(i) {
        row <- data[i, ]
        is_present <- !is.na(row$status) && row$status == "PRESENT"
        
        # Snapshot Logic: Use snapshot if present, else original photo
        img_src <- if (!is.na(row$snapshot_url) && nchar(row$snapshot_url) > 0) {
            # Map snapshot path to API endpoint
            sprintf("%s/attendance/snapshot/%s/%s", Sys.getenv("FASTAPI_BASE_URL", "http://localhost:8000"), active_lecture_id(), row$student_id)
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

  # --- SESSION ACTIONS ---
  output$lecturer_live_session_actions <- renderUI({
    if (active_lecture_id() == "") {
      actionButton("start_session_btn", "START LECTURE CAMERA", class="btn-success btn-lg btn-block")
    } else {
      actionButton("stop_session_btn", "TERMINATE SESSION", class="btn-danger btn-lg btn-block")
    }
  })

  shiny::observeEvent(input$start_session_btn, {
    req(input$live_class_id)
    new_id <- sprintf("LEC_%s_%s", input$live_class_id, format(Sys.time(), "%H%M%S"))
    active_lecture_id(new_id)
    
    # Trigger API
    body <- list(lecture_id = new_id, class_id = input$live_class_id, lecturer_id = session_state$user_id)
    api_call("/session/start", method="POST", body=body, auth_token=session_state$token)
    shinyalert::shinyalert("Live", "Vision pipeline active.", type="success")
  })

  shiny::observeEvent(input$stop_session_btn, {
    api_call("/session/stop", method="POST", body=list(lecture_id = active_lecture_id()), auth_token=session_state$token)
    active_lecture_id("")
    shinyalert::shinyalert("Ended", "Session logs saved.", type="info")
  })

  # --- ANALYTICS ---
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
  # REPORTS & ANALYTICS (2X2 GRID)
  # ========================================================================
  output$lec_report_course_selector <- renderUI({
    df <- lecturer_courses_data()
    selectInput("rep_course_id", "Select Course", choices = setNames(df$code, df$course))
  })

  output$lec_report_class_selector <- renderUI({
    req(input$rep_course_id)
    df <- safe_db_get(sprintf("SELECT class_id FROM classes WHERE course_id = '%s'", input$rep_course_id))
    selectInput("rep_class_id", "Select Class", choices = df$class_id)
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
}
