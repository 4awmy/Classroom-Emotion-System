# AAST LMS Shiny Application
# Entry point: login → role-based shinydashboard portal

source("global.R", local = FALSE)
source("ui/admin_ui.R", local = FALSE)
source("ui/lecturer_ui.R", local = FALSE)
source("server/admin_server.R", local = FALSE)
source("server/lecturer_server.R", local = FALSE)

# ============================================================================
# Login UI — Split-screen layout
# ============================================================================

login_ui <- function() {
  shiny::fluidPage(
    shinyjs::useShinyjs(),
    shiny::tags$head(
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
      shiny::tags$style(HTML("
        body, html { height: 100%; margin: 0; }
        .login-split {
          display: flex;
          height: 100vh;
          overflow: hidden;
        }
        .login-left {
          flex: 0 0 55%;
          background: linear-gradient(135deg, #002147 60%, #003366 100%);
          display: flex;
          align-items: center;
          justify-content: center;
          flex-direction: column;
          color: white;
          padding: 40px;
        }
        .login-left h1 {
          font-size: 2.5rem;
          color: #C9A84C;
          margin-bottom: 8px;
        }
        .login-left p {
          font-size: 1.2rem;
          opacity: 0.85;
          text-align: center;
        }
        .login-right {
          flex: 0 0 45%;
          background: white;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 40px;
        }
        .login-card {
          width: 100%;
          max-width: 380px;
        }
        .login-card h2 {
          color: #002147;
          font-weight: 700;
          margin-bottom: 6px;
        }
        .login-card .subtitle {
          color: #C9A84C;
          font-size: 1.05rem;
          margin-bottom: 28px;
        }
        .login-card .btn-login {
          background-color: #002147;
          border-color: #002147;
          color: white;
          width: 100%;
          padding: 10px;
          font-size: 1rem;
          border-radius: 6px;
          margin-top: 8px;
        }
        .login-card .btn-login:hover {
          background-color: #003366;
        }
        .login-card .form-control {
          border-radius: 6px;
          border: 1px solid #ccc;
          padding: 10px 14px;
        }
        .login-hint {
          text-align: center;
          margin-top: 16px;
          color: #999;
          font-size: 0.85rem;
        }
      "))
    ),
    shiny::div(class = "login-split",
      # Left panel — AAST branding
      shiny::div(class = "login-left",
        shiny::h1("AAST LMS"),
        shiny::p(
          HTML("AI-Powered Learning Management System<br>Arab Academy for Science, Technology & Maritime Transport")
        )
      ),
      # Right panel — login form
      shiny::div(class = "login-right",
        shiny::div(class = "login-card",
          shiny::h2("Welcome"),
          shiny::div(class = "subtitle", "Web Portal Access"),
          shiny::textInput("user_id", NULL, placeholder = "Username (admin or lecturer)"),
          shiny::passwordInput("password", NULL, placeholder = "Password"),
          shiny::br(),
          shiny::actionButton("login_btn", "Log In", class = "btn-login"),
          shiny::div(class = "login-hint",
            "Use 'admin/admin' or 'lecturer/lecturer' for testing"
          )
        )
      )
    )
  )
}

# ============================================================================
# Router
# ============================================================================

ui <- shiny::uiOutput("current_page")

# ============================================================================
# Server
# ============================================================================

server <- function(input, output, session) {
  logged_in <- shiny::reactiveVal(FALSE)
  user_role <- shiny::reactiveVal(NULL)

  # Login
  shiny::observeEvent(input$login_btn, {
    uid <- trimws(input$user_id)
    pwd <- trimws(input$password)
    if (uid == "admin" && pwd == "admin") {
      user_role("admin")
      logged_in(TRUE)
    } else if (uid == "lecturer" && pwd == "lecturer") {
      user_role("lecturer")
      logged_in(TRUE)
    } else {
      shinyalert::shinyalert("Login Failed",
                             "Invalid username or password.",
                             type = "error")
    }
  })

  # Logout — caught here for both admin and lecturer dashboards
  shiny::observeEvent(input$logout_btn, {
    logged_in(FALSE)
    user_role(NULL)
  })

  # Page router
  output$current_page <- shiny::renderUI({
    if (!logged_in()) {
      login_ui()
    } else if (user_role() == "admin") {
      admin_ui()
    } else {
      lecturer_ui()
    }
  })

  # Initialize module servers (always active; guards inside each function)
  admin_server(input, output, session)
  lecturer_server(input, output, session)
}

shiny::shinyApp(ui, server)
