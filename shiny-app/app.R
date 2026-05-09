# AAST LMS Shiny Application - Production Rescue Version
# This version is designed to bypass all initialization hangs

source("global.R", local = FALSE)
source("ui/admin_ui.R", local = FALSE)
source("ui/lecturer_ui.R", local = FALSE)
source("server/admin_server.R", local = FALSE)
source("server/lecturer_server.R", local = FALSE)

# ============================================================================
# Login UI
# ============================================================================

login_ui_static <- shiny::fluidPage(
  shinyjs::useShinyjs(),
  shiny::tags$head(
    shiny::tags$style(HTML("
      body { background-color: #002147; color: white; font-family: sans-serif; }
      .login-box { 
        background: white; color: #333; padding: 30px; 
        width: 350px; margin: 100px auto; border-radius: 10px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.3);
      }
      .btn-primary { background-color: #002147; border: none; width: 100%; padding: 10px; }
      h2 { text-align: center; color: #002147; margin-bottom: 20px; }
    "))
  ),
  shiny::div(class = "login-box",
    shiny::h2("AAST LMS Login"),
    shiny::textInput("user_id", "User ID", placeholder = "admin or omar"),
    shiny::passwordInput("password", "Password", placeholder = "admin or 123"),
    shiny::actionButton("login_btn", "Log In", class = "btn-primary", style="color:white;"),
    shiny::hr(),
    shiny::p(style="font-size:0.8em; color:#888; text-align:center;", "Test: admin/admin or omar/123")
  )
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
    email = NULL
  )

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

  # Login Logic
  shiny::observeEvent(input$login_btn, {
    uid <- trimws(input$user_id)
    pwd <- trimws(input$password)
    
    # Attempt API login
    res <- api_call("/auth/login", method = "POST", body = list(user_id=uid, password=pwd))
    
    if (!is.null(res) && !is.null(res$access_token)) {
      # Get user profile
      me <- api_call("/auth/me", auth_token = res$access_token)
      if (!is.null(me)) {
        session_state$token <- res$access_token
        session_state$role <- me$role
        session_state$user_id <- me$user_id
        session_state$name <- me$name
        session_state$email <- me$email
        session_state$logged_in <- TRUE
        return()
      }
    }

    # FALLBACKS (If API is down or login fails)
    if (uid == "admin" && pwd == "admin") {
      session_state$role <- "admin"
      session_state$user_id <- "admin"
      session_state$name <- "System Admin"
      session_state$logged_in <- TRUE
    } else if (uid == "omar" && pwd == "123") {
      session_state$role <- "lecturer"
      session_state$user_id <- "omar"
      session_state$name <- "Omar"
      session_state$email <- "omar@test.com"
      session_state$logged_in <- TRUE
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
  })

  # Module Servers
  try({
    admin_server(input, output, session, session_state)
    lecturer_server(input, output, session, session_state)
  }, silent = FALSE)
}

shiny::shinyApp(ui, server)
