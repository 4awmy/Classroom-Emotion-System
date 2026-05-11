# admin_server.R - Full CRUD + Enrollment Management

admin_server <- function(input, output, session, session_state) {
  source("modules/engagement_score.R", local = TRUE)
  source("modules/attendance.R",       local = TRUE)

  # ── Reactive triggers ──────────────────────────────────────────────────────
  admin_refresh      <- reactiveVal(0)
  lecturer_refresh   <- reactiveVal(0)
  student_refresh    <- reactiveVal(0)
  course_refresh     <- reactiveVal(0)
  class_refresh      <- reactiveVal(0)
  enrollment_refresh <- reactiveVal(0)

  # ── Direct DB helper ───────────────────────────────────────────────────────
  safe_db_get <- function(query) {
    db_url <- get_db_url()
    if (db_url == "") {
      global_db_error("DATABASE_URL missing")
      return(data.frame())
    }
    params <- parse_postgres_url(db_url)
    tryCatch({
      con <- if (is.null(params)) {
        dbConnect(RPostgres::Postgres(), dbname = db_url)
      } else {
        dbConnect(RPostgres::Postgres(),
                  host = params$host, port = params$port,
                  user = params$user, password = params$password,
                  dbname = params$dbname, sslmode = "require")
      }
      res <- dbGetQuery(con, query)
      dbDisconnect(con)
      global_db_error("")
      res
    }, error = function(e) {
      global_db_error(paste("[DB]", e$message))
      data.frame()
    })
  }

  # ── BRANDING ───────────────────────────────────────────────────────────────
  output$dashboard_logo <- renderUI({
    tags$img(src = "logo.png",
             style = "height:32px; margin-right:8px; margin-top:-4px;",
             onerror = "this.style.display='none'")
  })

  # ── OVERVIEW STATS ─────────────────────────────────────────────────────────
  output$stat_students <- renderValueBox({
    student_refresh()
    n <- tryCatch(
      nrow(safe_db_get("SELECT student_id FROM students")),
      error = function(e) 0
    )
    valueBox(n, "Total Students", icon = icon("users"), color = "blue")
  })

  output$stat_lecturers <- renderValueBox({
    lecturer_refresh()
    n <- tryCatch(
      nrow(safe_db_get("SELECT lecturer_id FROM lecturers")),
      error = function(e) 0
    )
    valueBox(n, "Lecturers", icon = icon("chalkboard-teacher"), color = "green")
  })

  output$stat_courses <- renderValueBox({
    course_refresh()
    n <- tryCatch(
      nrow(safe_db_get("SELECT course_id FROM courses")),
      error = function(e) 0
    )
    valueBox(n, "Courses", icon = icon("book"), color = "purple")
  })

  # ── ADMIN MANAGEMENT ───────────────────────────────────────────────────────
  output$admin_list_table <- DT::renderDataTable({
    admin_refresh()
    df <- safe_db_get("SELECT admin_id, name, email, created_at FROM admins ORDER BY created_at DESC")
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  observeEvent(input$adm_submit, {
    req(input$adm_id_in, input$adm_name_in)
    body <- list(
      admin_id = input$adm_id_in,
      name     = input$adm_name_in,
      email    = input$adm_email_in,
      password = if (nchar(input$adm_pwd_in) > 0) input$adm_pwd_in else "aast2026"
    )
    res <- api_call("/admin/admins", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      admin_refresh(admin_refresh() + 1)
      shinyalert::shinyalert("Success", paste("Admin", input$adm_name_in, "saved."), type = "success")
      updateTextInput(session, "adm_id_in",    value = "")
      updateTextInput(session, "adm_name_in",  value = "")
      updateTextInput(session, "adm_email_in", value = "")
    }
  })

  # ── LECTURER MANAGEMENT ────────────────────────────────────────────────────
  output$admin_lecturer_table <- DT::renderDataTable({
    lecturer_refresh()
    df <- safe_db_get("SELECT lecturer_id, name, email, department FROM lecturers ORDER BY name")
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  observeEvent(input$admin_lecturer_submit, {
    req(input$admin_lecturer_id, input$admin_lecturer_name)
    body <- list(
      lecturer_id = input$admin_lecturer_id,
      name        = input$admin_lecturer_name,
      email       = input$admin_lecturer_email,
      department  = input$admin_lecturer_dept,
      password    = if (nchar(input$admin_lecturer_pwd) > 0) input$admin_lecturer_pwd else "aast2026"
    )
    res <- api_call("/admin/lecturers", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      lecturer_refresh(lecturer_refresh() + 1)
      shinyalert::shinyalert("Success", paste("Lecturer", input$admin_lecturer_name, "saved."), type = "success")
      updateTextInput(session, "admin_lecturer_id",   value = "")
      updateTextInput(session, "admin_lecturer_name", value = "")
    }
  })

  # ── STUDENT MANAGEMENT ─────────────────────────────────────────────────────
  output$admin_student_table <- DT::renderDataTable({
    student_refresh()
    df <- safe_db_get("SELECT student_id, name, email, department, (face_encoding IS NOT NULL) AS has_encoding FROM students ORDER BY name")
    DT::datatable(df,
      selection = "single",
      options   = list(pageLength = 15, scrollX = TRUE),
      rownames  = FALSE
    )
  })

  observeEvent(input$admin_student_submit, {
    req(input$admin_student_id, input$admin_student_name)

    photo_b64 <- NULL
    if (!is.null(input$admin_student_photo)) {
      raw_data  <- readBin(input$admin_student_photo$datapath, "raw",
                           file.info(input$admin_student_photo$datapath)$size)
      ext       <- tolower(tools::file_ext(input$admin_student_photo$name))
      mime      <- if (ext == "png") "image/png" else "image/jpeg"
      photo_b64 <- paste0("data:", mime, ";base64,", base64enc::base64encode(raw_data))
    }

    body <- list(
      student_id = input$admin_student_id,
      name       = input$admin_student_name,
      email      = input$admin_student_email,
      department = input$admin_student_dept,
      password   = if (nchar(input$admin_student_pwd) > 0) input$admin_student_pwd else "aast2026",
      photo_b64  = photo_b64
    )
    res <- api_call("/admin/students", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      student_refresh(student_refresh() + 1)
      enc_msg <- if (isTRUE(res$has_encoding)) " Face encoding saved." else " (No face detected in photo.)"
      shinyalert::shinyalert("Success", paste("Student saved.", enc_msg), type = "success")
      updateTextInput(session, "admin_student_id",   value = "")
      updateTextInput(session, "admin_student_name", value = "")
    }
  })

  observeEvent(input$admin_student_delete, {
    s  <- input$admin_student_table_rows_selected
    req(s)
    df  <- safe_db_get("SELECT student_id FROM students ORDER BY name")
    sid <- df[s, "student_id"]
    res <- api_call(paste0("/admin/students/", sid), method = "DELETE", auth_token = session_state$token)
    if (!is.null(res)) {
      student_refresh(student_refresh() + 1)
      shinyalert::shinyalert("Deleted", paste("Student", sid, "removed."), type = "warning")
    }
  })

  # ── COURSE MANAGEMENT ──────────────────────────────────────────────────────
  output$admin_courses_table <- DT::renderDataTable({
    course_refresh()
    DT::datatable(safe_db_get("SELECT course_id, title FROM courses ORDER BY course_id"),
      options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
  })

  observeEvent(input$course_submit, {
    req(input$course_id_in, input$course_title_in)
    body <- list(course_id = input$course_id_in, title = input$course_title_in)
    res  <- api_call("/courses", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      course_refresh(course_refresh() + 1)
      shinyalert::shinyalert("Success", "Course added.", type = "success")
      updateTextInput(session, "course_id_in",    value = "")
      updateTextInput(session, "course_title_in", value = "")
    }
  })

  # ── CLASS MANAGEMENT ───────────────────────────────────────────────────────
  output$class_course_selector <- renderUI({
    course_refresh()
    df <- safe_db_get("SELECT course_id, title FROM courses ORDER BY title")
    if (nrow(df) == 0) return(p("No courses found. Add a course first.", style = "color:#e74c3c;"))
    selectInput("class_course_id_in", "Select Course:",
                choices = setNames(df$course_id, paste(df$course_id, "-", df$title)))
  })

  output$class_lecturer_selector <- renderUI({
    lecturer_refresh()
    df <- safe_db_get("SELECT lecturer_id, name FROM lecturers ORDER BY name")
    if (nrow(df) == 0) return(p("No lecturers found.", style = "color:#e74c3c;"))
    selectInput("class_lecturer_id_in", "Assign Lecturer:",
                choices = setNames(df$lecturer_id, df$name))
  })

  output$admin_classes_table <- DT::renderDataTable({
    class_refresh()
    df <- safe_db_get("
      SELECT cl.class_id, co.title AS course, cl.course_id,
             l.name AS lecturer, cl.lecturer_id
      FROM classes cl
      LEFT JOIN courses co ON cl.course_id = co.course_id
      LEFT JOIN lecturers l ON cl.lecturer_id = l.lecturer_id
      ORDER BY co.title, cl.class_id
    ")
    DT::datatable(df, options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE)
  })

  observeEvent(input$class_submit, {
    req(input$class_id_in, input$class_course_id_in)
    body <- list(
      class_id    = input$class_id_in,
      course_id   = input$class_course_id_in,
      lecturer_id = input$class_lecturer_id_in
    )
    res <- api_call("/courses/classes", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      class_refresh(class_refresh() + 1)
      shinyalert::shinyalert("Success", paste("Class", input$class_id_in, "assigned."), type = "success")
      updateTextInput(session, "class_id_in", value = "")
    }
  })

  # ── ENROLLMENT MANAGEMENT ──────────────────────────────────────────────────
  output$enroll_class_selector <- renderUI({
    enrollment_refresh(); class_refresh()
    df <- safe_db_get("
      SELECT cl.class_id, co.title AS course
      FROM classes cl
      LEFT JOIN courses co ON cl.course_id = co.course_id
      ORDER BY co.title, cl.class_id
    ")
    if (nrow(df) == 0) return(p("No classes yet. Create one in 'Class & Sections'.", style = "color:#e74c3c;"))
    selectInput("enroll_class_id", "Select Class:",
                choices = setNames(df$class_id, paste(df$class_id, "-", df$course)))
  })

  output$bulk_enroll_class_selector <- renderUI({
    enrollment_refresh(); class_refresh()
    df <- safe_db_get("
      SELECT cl.class_id, co.title AS course
      FROM classes cl
      LEFT JOIN courses co ON cl.course_id = co.course_id
      ORDER BY co.title, cl.class_id
    ")
    if (nrow(df) == 0) return(NULL)
    selectInput("bulk_enroll_class_id", "Enroll into Class:",
                choices = setNames(df$class_id, paste(df$class_id, "-", df$course)))
  })

  output$enroll_student_selector <- renderUI({
    student_refresh()
    df <- safe_db_get("SELECT student_id, name FROM students ORDER BY name")
    if (nrow(df) == 0) return(p("No students found.", style = "color:#e74c3c;"))
    selectInput("enroll_student_id", "Select Student:",
                choices = setNames(df$student_id, paste(df$student_id, "-", df$name)))
  })

  output$admin_enrollment_table <- DT::renderDataTable({
    enrollment_refresh()
    df <- safe_db_get("
      SELECT e.id, e.class_id, co.title AS course,
             e.student_id, s.name AS student_name
      FROM enrollments e
      LEFT JOIN classes cl ON e.class_id = cl.class_id
      LEFT JOIN courses co ON cl.course_id = co.course_id
      LEFT JOIN students s ON e.student_id = s.student_id
      ORDER BY co.title, e.class_id, s.name
    ")
    DT::datatable(df,
      selection = "single",
      options   = list(pageLength = 20, scrollX = TRUE),
      rownames  = FALSE
    )
  })

  observeEvent(input$enroll_refresh_btn, {
    enrollment_refresh(enrollment_refresh() + 1)
  })

  observeEvent(input$enroll_submit, {
    req(input$enroll_class_id, input$enroll_student_id)
    body <- list(
      class_id   = input$enroll_class_id,
      student_id = input$enroll_student_id
    )
    res <- api_call("/courses/enrollments", method = "POST", body = body, auth_token = session_state$token)
    if (!is.null(res)) {
      enrollment_refresh(enrollment_refresh() + 1)
      shinyalert::shinyalert("Enrolled",
        paste("Student", input$enroll_student_id, "enrolled in", input$enroll_class_id),
        type = "success")
    }
  })

  observeEvent(input$bulk_enroll_submit, {
    req(input$bulk_enroll_ids, input$bulk_enroll_class_id)
    ids  <- trimws(strsplit(input$bulk_enroll_ids, ",|\\n")[[1]])
    ids  <- ids[nchar(ids) > 0]
    if (length(ids) == 0) {
      shinyalert::shinyalert("Error", "No student IDs entered.", type = "error")
      return()
    }
    ok <- fail <- 0
    for (sid in ids) {
      body <- list(class_id = input$bulk_enroll_class_id, student_id = trimws(sid))
      res  <- api_call("/courses/enrollments", method = "POST", body = body, auth_token = session_state$token)
      if (!is.null(res)) ok <- ok + 1 else fail <- fail + 1
    }
    enrollment_refresh(enrollment_refresh() + 1)
    shinyalert::shinyalert("Bulk Enroll Done",
      paste("Enrolled:", ok, "| Failed:", fail), type = if (fail == 0) "success" else "warning")
  })

  observeEvent(input$enroll_delete_btn, {
    s  <- input$admin_enrollment_table_rows_selected
    req(s)
    df  <- safe_db_get("SELECT id FROM enrollments ORDER BY id")  # re-fetch aligned to table
    # Use the DT table's data to get the actual row id
    # safer: re-fetch and index by row
    df2 <- safe_db_get("
      SELECT e.id FROM enrollments e
      LEFT JOIN classes cl ON e.class_id = cl.class_id
      LEFT JOIN courses co ON cl.course_id = co.course_id
      LEFT JOIN students st ON e.student_id = st.student_id
      ORDER BY co.title, e.class_id, st.name
    ")
    eid <- df2[s, "id"]
    res <- api_call(paste0("/courses/enrollments/", eid), method = "DELETE", auth_token = session_state$token)
    if (!is.null(res)) {
      enrollment_refresh(enrollment_refresh() + 1)
      shinyalert::shinyalert("Removed", "Enrollment removed.", type = "warning")
    }
  })

  # ── ANALYTICS ──────────────────────────────────────────────────────────────
  output$admin_attendance_table <- DT::renderDataTable({
    df <- safe_db_get("
      SELECT al.timestamp, s.name AS student, al.lecture_id, al.status, al.method
      FROM attendance_log al
      LEFT JOIN students s ON al.student_id = s.student_id
      ORDER BY al.timestamp DESC
      LIMIT 100
    ")
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  output$admin_confidence_trend <- plotly::renderPlotly({
    df <- safe_db_get("
      SELECT timestamp, engagement_score
      FROM emotion_log
      ORDER BY timestamp DESC
      LIMIT 500
    ")
    if (nrow(df) == 0) {
      return(plotly::plot_ly() |>
        plotly::layout(title = "No engagement data yet",
                       xaxis = list(title = "Time"),
                       yaxis = list(title = "Score")))
    }
    plotly::plot_ly(df, x = ~timestamp, y = ~engagement_score,
                    type = "scatter", mode = "lines",
                    line = list(color = "#002147")) |>
      plotly::layout(title = "Engagement Score Over Time",
                     xaxis = list(title = "Time"),
                     yaxis = list(title = "Score", range = c(0, 1)))
  })

  output$admin_emotion_dist <- renderPlot({
    df <- safe_db_get("
      SELECT emotion, COUNT(*) AS count
      FROM emotion_log
      GROUP BY emotion
      ORDER BY count DESC
    ")
    if (nrow(df) == 0) {
      plot.new()
      text(0.5, 0.5, "No emotion data yet", cex = 1.4, col = "#888")
      return()
    }
    colors <- c(
      "Focused"     = "#1B5E20", "Engaged"    = "#4CAF50",
      "Confused"    = "#FFC107", "Frustrated" = "#FF9800",
      "Anxious"     = "#9C27B0", "Disengaged" = "#F44336"
    )
    bar_colors <- colors[df$emotion]
    bar_colors[is.na(bar_colors)] <- "#CCCCCC"
    barplot(df$count, names.arg = df$emotion,
            col = bar_colors, border = NA,
            main = "Global Emotion Distribution",
            ylab = "Count", las = 2,
            cex.names = 0.9)
  })

  output$admin_incidents_table <- DT::renderDataTable({
    df <- safe_db_get("
      SELECT i.timestamp, s.name AS student, i.flag_type, i.severity, i.exam_id
      FROM incidents i
      LEFT JOIN students s ON i.student_id = s.student_id
      ORDER BY i.timestamp DESC
    ")
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })
}
