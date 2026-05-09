# admin_server.R - Server logic for 14 admin analytics panels
# Fully migrated to Supabase PostgreSQL with null-safety

admin_server <- function(input, output, session, session_state) {
  # Load R modules
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
    shiny::invalidateLater(30000, session)
    safe_query("SELECT * FROM emotion_log")
  })

  attendance_data <- shiny::reactive({
    shiny::invalidateLater(60000, session)
    safe_query("SELECT * FROM attendance_log")
  })

  courses_data <- shiny::reactive({
    safe_query("SELECT * FROM courses")
  })

  classes_data <- shiny::reactive({
    safe_query("SELECT * FROM classes")
  })

  lectures_data <- shiny::reactive({
    safe_query("SELECT * FROM lectures")
  })

  students_data <- shiny::reactive({
    safe_query("SELECT * FROM students")
  })

  lecturers_data <- shiny::reactive({
    safe_query("SELECT * FROM lecturers")
  })

  # ========================================================================
  # Panel 0: Global Statistics
  # ========================================================================

  output$stats_course_selector <- renderUI({
    df <- courses_data()
    choices <- if (nrow(df) > 0) setNames(df$course_id, paste(df$course_id, "-", df$title)) else c("No Courses" = "None")
    selectInput("stats_course", "Filter by Course:", choices = c("All", choices))
  })

  output$stats_lecture_selector <- renderUI({
    df <- lectures_data()
    sc <- if (!is.null(input$stats_course)) input$stats_course else "All"
    if (sc != "All") {
       cl <- classes_data()
       if (nrow(cl) > 0) {
         cl_filt <- cl |> dplyr::filter(course_id == sc)
         df <- df |> dplyr::filter(class_id %in% cl_filt$class_id)
       }
    }
    choices <- if (nrow(df) > 0) setNames(df$lecture_id, paste(df$lecture_id, "-", df$title)) else c("No Lectures" = "None")
    selectInput("stats_lecture", "Filter by Lecture:", choices = c("All", choices))
  })

  output$stats_student_selector <- renderUI({
    df <- students_data()
    choices <- if (nrow(df) > 0) setNames(df$student_id, paste(df$student_id, "-", df$name)) else c("No Students" = "None")
    selectInput("stats_student", "Filter by Student:", choices = c("All", choices))
  })

  filtered_stats_data <- reactive({
    df <- emotions_data()
    if (nrow(df) == 0) return(df)
    st <- input$stats_student
    le <- input$stats_lecture
    co <- input$stats_course
    if (!is.null(st) && st != "All") df <- df |> dplyr::filter(student_id == st)
    if (!is.null(le) && le != "All") df <- df |> dplyr::filter(lecture_id == le)
    if (!is.null(co) && co != "All") {
       cl <- classes_data() |> dplyr::filter(course_id == co)
       df <- df |> dplyr::filter(lecture_id %in% (lectures_data()$lecture_id[lectures_data()$class_id %in% cl$class_id]))
    }
    df
  })

  output$stats_emotion_pie <- plotly::renderPlotly({
    data <- filtered_stats_data()
    if (nrow(data) == 0) return(plotly::plot_ly() |> plotly::add_text(text = "No data"))
    summary <- data |> dplyr::group_by(emotion) |> dplyr::summarise(count = n(), .groups = "drop")
    plotly::plot_ly(summary, labels = ~emotion, values = ~count, type = 'pie')
  })

  output$stats_engagement_gauge <- plotly::renderPlotly({
    data <- filtered_stats_data()
    avg_eng <- if(nrow(data) > 0) mean(data$engagement_score, na.rm=TRUE) else 0
    plotly::plot_ly(type = "indicator", mode = "gauge+number", value = avg_eng,
                   gauge = list(axis = list(range = list(0, 1)), bar = list(color = "#002147")))
  })

  output$stats_trend_line <- plotly::renderPlotly({
    data <- filtered_stats_data()
    if (nrow(data) == 0) return(plotly::plot_ly())
    data$timestamp <- as.POSIXct(data$timestamp)
    summary <- data |> dplyr::mutate(time_bin = lubridate::round_date(timestamp, "5 minutes")) |>
      dplyr::group_by(time_bin) |> dplyr::summarise(eng = mean(engagement_score, na.rm=TRUE), .groups = "drop")
    plotly::plot_ly(summary, x = ~time_bin, y = ~eng, type = 'scatter', mode = 'lines+markers')
  })

  # ========================================================================
  # Panel Audit Logic
  # ========================================================================

  output$audit_lecturer_selector <- renderUI({
    df <- lecturers_data()
    choices <- if (nrow(df) > 0) setNames(df$lecturer_id, df$name) else c("No Lecturers" = "None")
    selectInput("audit_lecturer", "Select Lecturer:", choices = c("All", choices))
  })

  audit_data <- reactive({
    df <- lectures_data()
    if (nrow(df) == 0) return(df)
    if (!is.null(input$audit_lecturer) && input$audit_lecturer != "All") df <- df |> dplyr::filter(lecturer_id == input$audit_lecturer)
    if (!is.null(input$audit_date_filter)) df <- df |> dplyr::filter(as.Date(scheduled_start) == input$audit_date_filter)
    
    df <- df |> dplyr::mutate(
      start_delay = as.numeric(difftime(actual_start_time, scheduled_start, units = "mins")),
      early_exit  = as.numeric(difftime(scheduled_end, actual_end_time, units = "mins")),
      penalty = pmax(0, start_delay - 10) * 2 + pmax(0, early_exit - 10) * 5,
      punctuality_score = pmax(0, 100 - penalty)
    )
    df
  })

  output$admin_audit_table <- DT::renderDataTable({
    df <- audit_data()
    if (nrow(df) == 0) return(data.frame())
    flagged <- df |> dplyr::filter(start_delay > 10 | early_exit > 10)
    DT::datatable(flagged)
  })

  output$admin_reliability_plot <- plotly::renderPlotly({
    df <- audit_data()
    if (nrow(df) == 0) return(NULL)
    emotions <- emotions_data() |> dplyr::filter(lecture_id %in% df$lecture_id)
    if (nrow(emotions) == 0) return(NULL)
    stats <- emotions |> dplyr::group_by(lecture_id) |>
      dplyr::summarise(mean_eng = mean(engagement_score, na.rm=TRUE), se = sd(engagement_score, na.rm=TRUE) / sqrt(n()),
                       lower = mean_eng - (1.96 * se), upper = mean_eng + (1.96 * se), .groups = "drop")
    plotly::plot_ly(stats, x = ~lecture_id, y = ~mean_eng, type = 'scatter', mode = 'markers',
                   error_y = list(type = 'data', array = ~upper - mean_eng, arrayminus = ~mean_eng - lower))
  })

  output$admin_conclusion_test_results <- DT::renderDataTable({
    df <- audit_data()
    emotions <- emotions_data()
    results <- data.frame()
    for(lid in unique(df$lecture_id)) {
      session_emotions <- emotions |> dplyr::filter(lecture_id == lid)
      if (nrow(session_emotions) < 20) next
      start_time <- min(session_emotions$timestamp); end_time <- max(session_emotions$timestamp)
      first_10 <- session_emotions |> dplyr::filter(timestamp <= start_time + lubridate::minutes(10))
      last_10  <- session_emotions |> dplyr::filter(timestamp >= end_time - lubridate::minutes(10))
      if (nrow(first_10) > 5 && nrow(last_10) > 5) {
        t_test <- t.test(first_10$engagement_score, last_10$engagement_score)
        is_drop <- t_test$p.value < 0.05 && mean(last_10$engagement_score) < mean(first_10$engagement_score)
        results <- rbind(results, data.frame(Lecture = lid, P_Value = round(t_test$p.value, 4), Conclusion = if(is_drop) "DROP" else "STABLE"))
      }
    }
    DT::datatable(results)
  })

  # ========================================================================
  # --- COURSE MANAGEMENT ---
  # ========================================================================

  course_refresh <- reactiveVal(0)
  output$admin_courses_table <- DT::renderDataTable({ course_refresh(); DT::datatable(courses_data()) })
  shiny::observeEvent(input$course_submit, {
    req(session_state$token, input$course_id_in)
    body <- list(course_id=input$course_id_in, title=input$course_title_in, department=input$course_dept_in, credit_hours=as.integer(input$course_credits_in))
    api_call("/courses/", method="POST", body=body, auth_token=session_state$token)
    course_refresh(course_refresh() + 1)
  })

  # --- Class Manager ---
  class_refresh <- reactiveVal(0)
  output$class_course_selector <- renderUI({ df <- courses_data(); selectInput("class_course_id_in", "Select Course:", choices = setNames(df$course_id, df$title)) })
  output$class_lecturer_selector <- renderUI({ df <- lecturers_data(); selectInput("class_lecturer_id_in", "Select Lecturer:", choices = setNames(df$lecturer_id, df$name)) })
  output$admin_classes_table <- DT::renderDataTable({ class_refresh(); DT::datatable(classes_data()) })
  shiny::observeEvent(input$class_submit, {
    req(session_state$token, input$class_id_in)
    body <- list(class_id=input$class_id_in, course_id=input$class_course_id_in, lecturer_id=input$class_lecturer_id_in, section_name=input$class_section_in, room=input$class_room_in)
    api_call("/courses/classes", method="POST", body=body, auth_token=session_state$token)
    class_refresh(class_refresh() + 1)
  })

  # --- Admin Manager ---
  admin_refresh <- reactiveVal(0)
  output$admin_list_table <- DT::renderDataTable({ admin_refresh(); data <- api_call("/admin/admins", auth_token = session_state$token); if (is.null(data)) return(data.frame()); dplyr::bind_rows(lapply(data, as.data.frame)) |> DT::datatable() })
  shiny::observeEvent(input$adm_submit, {
    req(session_state$token, input$adm_id_in)
    body <- list(admin_id=input$adm_id_in, name=input$adm_name_in, email=input$adm_email_in, password=input$adm_pwd_in)
    api_call("/admin/admins", method="POST", body=body, auth_token=session_state$token)
    admin_refresh(admin_refresh() + 1)
  })

  # --- Student Manager ---
  student_refresh <- reactiveVal(0)
  output$admin_student_table <- DT::renderDataTable({ student_refresh(); data <- api_call("/admin/students", auth_token = session_state$token); if (is.null(data)) return(data.frame()); dplyr::bind_rows(lapply(data, as.data.frame)) |> DT::datatable(selection = "single") })
  shiny::observeEvent(input$admin_student_submit, {
    req(session_state$token, input$admin_student_id)
    body <- list(student_id=input$admin_student_id, name=input$admin_student_name, email=input$admin_student_email, password=input$admin_student_pwd)
    api_call("/admin/students", method="POST", body=body, auth_token=session_state$token)
    student_refresh(student_refresh() + 1)
  })
  shiny::observeEvent(input$admin_student_delete, {
    s <- input$admin_student_table_rows_selected; req(s)
    students <- api_call("/admin/students", auth_token = session_state$token); sid <- students[[s]]$student_id
    api_call(paste0("/admin/students/", sid), method="DELETE", auth_token=session_state$token)
    student_refresh(student_refresh() + 1)
  })

  # --- Lecturer Manager ---
  lecturer_refresh <- reactiveVal(0)
  output$admin_lecturer_table <- DT::renderDataTable({ lecturer_refresh(); data <- api_call("/admin/lecturers", auth_token = session_state$token); if (is.null(data)) return(data.frame()); dplyr::bind_rows(lapply(data, as.data.frame)) |> DT::datatable() })
  shiny::observeEvent(input$admin_lecturer_submit, {
    req(session_state$token, input$admin_lecturer_id)
    body <- list(lecturer_id=input$admin_lecturer_id, name=input$admin_lecturer_name, email=input$admin_lecturer_email, password=input$admin_lecturer_pwd)
    api_call("/admin/lecturers", method="POST", body=body, auth_token=session_state$token)
    lecturer_refresh(lecturer_refresh() + 1)
  })
}
