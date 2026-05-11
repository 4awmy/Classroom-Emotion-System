# admin_server.R - Centralized User & System Management

admin_server <- function(input, output, session, session_state) {
  # Load R modules
  source("modules/engagement_score.R", local = TRUE)
  source("modules/attendance.R", local = TRUE)

  # Reactive triggers
  admin_refresh <- reactiveVal(0)
  lecturer_refresh <- reactiveVal(0)
  student_refresh <- reactiveVal(0)
  course_refresh <- reactiveVal(0)
  class_refresh <- reactiveVal(0)

  # ========================================================================
  # DATA FETCHERS (DB Direct)
  # ========================================================================
  
  safe_db_get <- function(query) {
    db_url <- get_db_url()
    if (db_url == "") {
      global_db_error("DATABASE_URL MISSING in Admin Portal")
      return(data.frame())
    }
    
    params <- parse_postgres_url(db_url)

    tryCatch({
      if (is.null(params)) {
        con <- dbConnect(RPostgres::Postgres(), dbname = db_url)
      } else {
        con <- dbConnect(RPostgres::Postgres(), 
                         host = params$host,
                         port = params$port,
                         user = params$user,
                         password = params$password,
                         dbname = params$dbname,
                         sslmode = "require")
      }
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      global_db_error("") # Clear error
      return(res)
    }, error = function(e) { 
      err_msg <- paste("[DB] Admin Query failed:", e$message)
      global_db_error(err_msg)
      return(data.frame()) 
    })
  }

  # ========================================================================
  # ADMIN MANAGEMENT
  # ========================================================================
  output$admin_list_table <- DT::renderDataTable({
    admin_refresh()
    df <- safe_db_get("SELECT admin_id, name, email, created_at FROM admins")
    DT::datatable(df, options = list(pageLength = 10))
  })

  shiny::observeEvent(input$adm_submit, {
    req(input$adm_id_in, input$adm_name_in)
    body <- list(
      admin_id = input$adm_id_in,
      name = input$adm_name_in,
      email = input$adm_email_in,
      password = input$adm_pwd_in
    )
    api_call("/admin/admins", method="POST", body=body, auth_token=session_state$token)
    admin_refresh(admin_refresh() + 1)
    shinyalert::shinyalert("Success", "Admin saved.", type="success")
  })

  # ========================================================================
  # LECTURER MANAGEMENT
  # ========================================================================
  output$admin_lecturer_table <- DT::renderDataTable({
    lecturer_refresh()
    df <- safe_db_get("SELECT lecturer_id, name, email, department FROM lecturers")
    DT::datatable(df, options = list(pageLength = 10))
  })

  shiny::observeEvent(input$admin_lecturer_submit, {
    req(input$admin_lecturer_id, input$admin_lecturer_name)
    body <- list(
      lecturer_id = input$admin_lecturer_id,
      name = input$admin_lecturer_name,
      email = input$admin_lecturer_email,
      department = input$admin_lecturer_dept,
      password = input$admin_lecturer_pwd
    )
    api_call("/admin/lecturers", method="POST", body=body, auth_token=session_state$token)
    lecturer_refresh(lecturer_refresh() + 1)
    shinyalert::shinyalert("Success", "Lecturer saved.", type="success")
  })

  # ========================================================================
  # STUDENT MANAGEMENT
  # ========================================================================
  output$admin_student_table <- DT::renderDataTable({
    student_refresh()
    df <- safe_db_get("SELECT student_id, name, email, department FROM students")
    DT::datatable(df, selection = "single", options = list(pageLength = 15))
  })

  shiny::observeEvent(input$admin_student_submit, {
    req(input$admin_student_id, input$admin_student_name)
    
    # Handle Photo Upload
    photo_base64 <- NULL
    if (!is.null(input$admin_student_photo)) {
      photo_data <- readBin(input$admin_student_photo$datapath, "raw", file.info(input$admin_student_photo$datapath)$size)
      photo_base64 <- base64enc::base64encode(photo_data)
    }

    body <- list(
      student_id = input$admin_student_id,
      name = input$admin_student_name,
      email = input$admin_student_email,
      department = input$admin_student_dept,
      password = input$admin_student_pwd,
      photo_b64 = photo_base64
    )
    
    api_call("/admin/students", method="POST", body=body, auth_token=session_state$token)
    student_refresh(student_refresh() + 1)
    shinyalert::shinyalert("Success", "Student updated in roster.", type="success")
  })

  shiny::observeEvent(input$admin_student_delete, {
    s <- input$admin_student_table_rows_selected
    req(s)
    df <- safe_db_get("SELECT student_id FROM students")
    sid <- df[s, "student_id"]
    api_call(paste0("/admin/students/", sid), method="DELETE", auth_token=session_state$token)
    student_refresh(student_refresh() + 1)
  })

  # ========================================================================
  # COURSE & CLASS
  # ========================================================================
  output$admin_courses_table <- DT::renderDataTable({
    course_refresh()
    DT::datatable(safe_db_get("SELECT * FROM courses"))
  })

  output$class_course_selector <- renderUI({
    df <- safe_db_get("SELECT course_id, title FROM courses")
    selectInput("class_course_id_in", "Select Course:", choices = setNames(df$course_id, df$title))
  })

  output$class_lecturer_selector <- renderUI({
    df <- safe_db_get("SELECT lecturer_id, name FROM lecturers")
    selectInput("class_lecturer_id_in", "Assign Lecturer:", choices = setNames(df$lecturer_id, df$name))
  })

  output$admin_classes_table <- DT::renderDataTable({
    class_refresh()
    DT::datatable(safe_db_get("SELECT * FROM classes"))
  })

  shiny::observeEvent(input$course_submit, {
    req(input$course_id_in, input$course_title_in)
    body <- list(
      course_id = input$course_id_in,
      title = input$course_title_in
    )
    api_call("/courses", method="POST", body=body, auth_token=session_state$token)
    course_refresh(course_refresh() + 1)
    shinyalert::shinyalert("Success", "Course added.", type="success")
  })

  shiny::observeEvent(input$class_submit, {
    req(input$class_id_in, input$class_course_id_in)
    body <- list(
      class_id = input$class_id_in,
      course_id = input$class_course_id_in,
      lecturer_id = input$class_lecturer_id_in
    )
    api_call("/courses/classes", method="POST", body=body, auth_token=session_state$token)
    class_refresh(class_refresh() + 1)
  })

  # ========================================================================
  # ANALYTICS
  # ========================================================================
  output$admin_attendance_table <- DT::renderDataTable({
    df <- safe_db_get("SELECT * FROM attendance_log ORDER BY timestamp DESC LIMIT 100")
    DT::datatable(df)
  })

  output$admin_confidence_trend <- plotly::renderPlotly({
    df <- safe_db_get("SELECT timestamp, engagement_score FROM emotion_log ORDER BY timestamp DESC LIMIT 500")
    if (nrow(df) == 0) return(NULL)
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score, type = 'scatter', mode = 'lines')
  })

  output$admin_emotion_dist <- renderPlot({
    df <- safe_db_get("SELECT emotion, count(*) as count FROM emotion_log GROUP BY emotion")
    if (nrow(df) == 0) return(NULL)
    barplot(df$count, names.arg = df$emotion, col = "skyblue", main = "Global Emotion Distribution")
  })

  output$admin_incidents_table <- DT::renderDataTable({
    df <- safe_db_get("SELECT * FROM incidents ORDER BY timestamp DESC")
    DT::datatable(df)
  })

  # ========================================================================
  # BRANDING
  # ========================================================================
  output$dashboard_logo <- renderUI({
    tags$img(src = "logo.png", style = "height: 35px; margin-right: 10px; margin-top: -5px;")
  })
}
