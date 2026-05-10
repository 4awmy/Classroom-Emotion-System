# AAST LMS Shiny Application - Hybrid v3 Production Version

source("global.R", local = FALSE)
source("ui/admin_ui.R", local = FALSE)
source("ui/lecturer_ui.R", local = FALSE)
source("server/admin_server.R", local = FALSE)
source("server/lecturer_server.R", local = FALSE)

# ============================================================================
# Shared UI Elements
# ============================================================================

login_ui_static <- shiny::fluidPage(
  shinyjs::useShinyjs(),
  shiny::tags$head(
    shiny::tags$style(HTML("
      body { background-color: #002147; color: white; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
      .login-box { 
        background: white; color: #333; padding: 40px; 
        width: 400px; margin: 80px auto; border-radius: 12px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      }
      .btn-primary { background-color: #002147; border: none; width: 100%; padding: 12px; font-weight: 600; border-radius: 6px; }
      .btn-link { color: #002147; background: none; border: none; padding: 0; font-size: 0.9em; text-decoration: underline; cursor: pointer; }
      h2 { text-align: center; color: #002147; margin-bottom: 30px; font-weight: 700; }
      .form-group { margin-bottom: 20px; }
    "))
  ),
  shiny::uiOutput("auth_container")
)

# ============================================================================
# Main UI
# ============================================================================

ui <- shiny::uiOutput("root_ui")

# ============================================================================
# Server
# ============================================================================

server <- function(input, output, session) {
  # Reactive values for session
  session_state <- shiny::reactiveValues(
    logged_in = FALSE,
    role = NULL,
    token = NULL,
    user_id = NULL,
    name = NULL,
    email = NULL,
    view = "login" # login | forgot
  )

  # Auth Container Router
  output$auth_container <- shiny::renderUI({
    if (session_state$view == "login") {
      shiny::div(class = "login-box",
        shiny::h2("AAST LMS Login"),
        shiny::div(class="form-group", shiny::textInput("user_id", "User ID", placeholder = "admin / omar")),
        shiny::div(class="form-group", shiny::passwordInput("password", "Password", placeholder = "admin / 123")),
        shiny::actionButton("login_btn", "Log In", class = "btn-primary", style="color:white;"),
        shiny::br(), shiny::br(),
        shiny::div(style="text-align:center;",
          shiny::actionLink("show_forgot", "Forgot Password?", class="btn-link")
        )
      )
    } else {
      shiny::div(class = "login-box",
        shiny::h2("Reset Password"),
        p("Enter your registered email to receive a recovery link via Supabase."),
        shiny::div(class="form-group", shiny::textInput("forgot_email", "Email Address")),
        shiny::actionButton("forgot_submit", "Send Reset Link", class = "btn-primary", style="color:white;"),
        shiny::br(), shiny::br(),
        shiny::div(style="text-align:center;",
          shiny::actionLink("show_login", "Back to Login", class="btn-link")
        )
      )
    }
  })

  # Render the correct page
  output$root_ui <- shiny::renderUI({
    if (!session_state$logged_in) {
      return(login_ui_static)
    } else if (session_state$role == "admin") {
      return(admin_ui())
    } else {
      return(lecturer_ui())
    }
  })

  # --- Auth Observers ---

  shiny::observeEvent(input$show_forgot, { session_state$view <- "forgot" })
  shiny::observeEvent(input$show_login, { session_state$view <- "login" })

  # Login Logic
  shiny::observeEvent(input$login_btn, {
    uid <- trimws(input$user_id)
    pwd <- trimws(input$password)
    
    print(paste("[AUTH] Attempting login for:", uid))
    
    if (uid == "" || pwd == "") {
       shinyalert::shinyalert("Error", "Enter ID and Password", type="error")
       return()
    }

    # Attempt API login
    res <- api_call("/auth/login", method = "POST", body = list(user_id=uid, password=pwd))
    
    if (!is.null(res) && !is.null(res$access_token)) {
      print("[AUTH] Success, fetching profile...")
      
      # Get user profile
      me <- api_call("/auth/me", auth_token = res$access_token)
      if (!is.null(me)) {
        print(paste("[AUTH] Profile loaded for", me$name))
        session_state$token <- res$access_token
        session_state$role <- me$role
        session_state$user_id <- me$user_id
        session_state$name <- me$name
        session_state$email <- me$email
        session_state$logged_in <- TRUE
      } else {
        print("[AUTH] Failed to fetch /auth/me")
        shinyalert::shinyalert("Error", "Could not retrieve user profile from backend.", type="error")
      }
    } else {
      print("[AUTH] API call returned NULL")
    }
  })

  # Forgot Password Logic
  shiny::observeEvent(input$forgot_submit, {
    email <- trimws(input$forgot_email)
    if (nchar(email) == 0) return()
    
    res <- api_call("/auth/forgot-password", method = "POST", body = list(email=email))
    if (!is.null(res)) {
      shinyalert::shinyalert("Check Email", res$message, type = "success")
      session_state$view <- "login"
    }
  })

  # Logout Logic
  shiny::observeEvent(input$logout_btn, {
    session_state$logged_in <- FALSE
    session_state$role <- NULL
    session_state$token <- NULL
    session_state$user_id <- NULL
    session_state$name <- NULL
    session_state$email <- NULL
    shiny::updateTextInput(session, "user_id", value = "")
    shiny::updateTextInput(session, "password", value = "")
    session_state$view <- "login"
  })

  # Module Servers
  try({
    admin_server(input, output, session, session_state)
    lecturer_server(input, output, session, session_state)
  }, silent = FALSE)
}

shiny::shinyApp(ui, server)
