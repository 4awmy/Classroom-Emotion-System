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
    shiny::tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    # Add login-page-body class so custom.css can apply campus.jpg background
    shiny::tags$script(HTML("document.addEventListener('DOMContentLoaded', function() { document.body.classList.add('login-page-body'); });")),
    shiny::tags$style(HTML("
      @keyframes floatOrb {
        0%, 100% { transform: translateY(0px) scale(1); opacity: 0.55; }
        50%       { transform: translateY(-28px) scale(1.06); opacity: 0.75; }
      }
      @keyframes floatOrbAlt {
        0%, 100% { transform: translateY(0px) scale(1); opacity: 0.35; }
        50%       { transform: translateY(22px) scale(0.93); opacity: 0.55; }
      }
      @keyframes shimmer {
        0%   { background-position: -400px 0; }
        100% { background-position: 400px 0; }
      }

      body {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        font-family: 'Roboto', Arial, sans-serif;
        overflow: hidden;
        position: relative;
      }

      /* ── Floating orb decorations ─────────────────────────── */
      body::before {
        content: '';
        position: fixed;
        top: -120px; left: -120px;
        width: 420px; height: 420px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(201,168,76,0.18) 0%, transparent 70%);
        animation: floatOrb 7s ease-in-out infinite;
        pointer-events: none;
      }
      body::after {
        content: '';
        position: fixed;
        bottom: -80px; right: -80px;
        width: 340px; height: 340px;
        border-radius: 50%;
        background: radial-gradient(circle, rgba(13,47,106,0.80) 0%, rgba(201,168,76,0.10) 60%, transparent 80%);
        animation: floatOrbAlt 9s ease-in-out infinite;
        pointer-events: none;
      }

      /* ── Subtle dot grid overlay ──────────────────────────── */
      .login-wrapper {
        width: 100%;
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 40px 20px;
        position: relative;
        background-image: radial-gradient(rgba(201,168,76,0.08) 1px, transparent 1px);
        background-size: 28px 28px;
      }

      /* ── Logo area ────────────────────────────────────────── */
      .login-logo-area {
        text-align: center;
        margin-bottom: 28px;
      }
      .login-logo-area img {
        height: 54px;
        filter: brightness(0) invert(1);
        margin-bottom: 10px;
      }
      .login-logo-area p {
        color: rgba(201,168,76,0.85);
        font-size: 0.82rem;
        font-weight: 500;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin: 0;
      }

      /* ── Login card ───────────────────────────────────────── */
      .login-box {
        background: rgba(255,255,255,0.97);
        color: #1a2340;
        padding: 36px 40px;
        width: 400px;
        max-width: 100%;
        border-radius: 16px;
        box-shadow: 0 32px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(201,168,76,0.22);
        position: relative;
        overflow: hidden;
      }
      /* Gold shimmer top border */
      .login-box::before {
        content: '';
        position: absolute;
        top: 0; left: 0; right: 0;
        height: 4px;
        background: linear-gradient(90deg, #C9A84C, #e0bc6a, #C9A84C);
        background-size: 400px 100%;
        animation: shimmer 2.8s linear infinite;
      }
      .login-box h2 {
        text-align: center;
        color: #06193c;
        margin-bottom: 26px;
        font-weight: 700;
        font-size: 1.4rem;
      }
      .login-box .form-group { margin-bottom: 18px; }
      .login-box label { color: #1a2340; font-weight: 600; font-size: 0.88rem; }
      .login-box .form-control {
        border: 1px solid #c8d0dd !important;
        border-radius: 7px !important;
        min-height: 42px;
        font-size: 0.95rem;
        color: #1a2340;
      }
      .login-box .form-control:focus {
        border-color: #06193c !important;
        box-shadow: 0 0 0 3px rgba(6,25,60,0.10) !important;
      }
      .login-box .btn-primary {
        background: linear-gradient(135deg, #06193c 0%, #0a2454 100%) !important;
        border: none !important;
        width: 100%;
        padding: 12px;
        font-weight: 700;
        border-radius: 8px !important;
        font-size: 1rem;
        letter-spacing: 0.03em;
        transition: opacity 0.2s, box-shadow 0.2s;
        color: #fff !important;
      }
      .login-box .btn-primary:hover {
        opacity: 0.88;
        box-shadow: 0 6px 20px rgba(6,25,60,0.40);
      }
      .btn-link { color: #06193c; background: none; border: none; padding: 0; font-size: 0.88em; text-decoration: underline; cursor: pointer; }
    "))
  ),
  shiny::div(class = "login-wrapper",
    shiny::div(class = "login-logo-area",
      shiny::tags$img(src = "aast-logo-wide.png", alt = "AAST LMS"),
      shiny::tags$p("Classroom Emotion Intelligence System")
    ),
    shiny::uiOutput("auth_container")
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
    email = NULL,
    view = "login" # login | forgot
  )

  # Auth Container Router
  output$auth_container <- shiny::renderUI({
    if (session_state$view == "login") {
      shiny::div(class = "login-box",
        shiny::h2("AAST LMS Login"),
        shiny::div(class="form-group", shiny::textInput("user_id", "User ID", placeholder = "e.g. 231006367")),
        shiny::div(class="form-group", shiny::passwordInput("password", "Password", placeholder = "Enter your password")),
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
