# AAST LMS Shiny Application
# Entry point: loads global config, UI modules, and server logic

# Load global configuration
source("global.R", local = FALSE)

# Load UI modules
source("ui/admin_ui.R", local = FALSE)
source("ui/lecturer_ui.R", local = FALSE)

# Load server modules
source("server/admin_server.R", local = FALSE)
source("server/lecturer_server.R", local = FALSE)

# ============================================================================
# Main App Structure - Role-Based Navigation
# ============================================================================

ui <- shiny::navbarPage(
  title = "AAST LMS",
  theme = bslib::bs_theme(
    version = 5,
    primary = AAST_NAVY,
    secondary = AAST_GOLD
  ),
  # ========================================================================
  # Admin Panel
  # ========================================================================
  shiny::tabPanel(
    "Admin Portal",
    shiny::uiOutput("admin_panel_guard")
  ),
  # ========================================================================
  # Lecturer Portal
  # ========================================================================
  shiny::tabPanel(
    "Lecturer Portal",
    shiny::uiOutput("lecturer_panel_guard")
  ),
  # ========================================================================
  # Help/Documentation
  # ========================================================================
  shiny::tabPanel(
    "Help",
    shiny::div(
      class = "container mt-5",
      shiny::h2("AAST LMS - User Guide"),
      shiny::h3("Admin Portal"),
      shiny::p("Access comprehensive analytics, department-wide trends, at-risk student detection, and lecture effectiveness metrics."),
      shiny::h3("Lecturer Portal"),
      shiny::p("Manage your roster, upload materials, track attendance, monitor live class emotions, and generate student reports."),
      shiny::h3("Support"),
      shiny::p("Contact the IT team for technical issues or feature requests.")
    )
  )
)

# ============================================================================
# Server Logic - Role-based routing + shared state
# ============================================================================

server <- function(input, output, session) {
  # Determine user role (in real app, would come from auth system)
  user_role <- shiny::reactiveVal("lecturer")  # Default: lecturer. Set to "admin" for admin access

  # ========================================================================
  # Conditional Panel Rendering
  # ========================================================================

  output$admin_panel_guard <- shiny::renderUI({
    if (user_role() == "admin") {
      admin_ui()
    } else {
      shiny::div(
        class = "alert alert-danger",
        "You do not have permission to access the Admin Portal. Contact your administrator."
      )
    }
  })

  output$lecturer_panel_guard <- shiny::renderUI({
    if (user_role() %in% c("lecturer", "admin")) {
      lecturer_ui()
    } else {
      shiny::div(
        class = "alert alert-danger",
        "You do not have permission to access the Lecturer Portal."
      )
    }
  })

  # ========================================================================
  # Initialize Server Logic
  # ========================================================================

  # Admin server (runs regardless of role, but UI is hidden/shown conditionally)
  admin_server(input, output, session)

  # Lecturer server
  lecturer_server(input, output, session)

  # ========================================================================
  # Global Observers & Reactive Logic
  # ========================================================================

  # Log session info
  shiny::observe({
    cat("[Shiny] Session started. User role:", user_role(), "\n")
  })

  # Error handling
  shiny::observe({
    error_message <- shiny::session$userData$error
    if (!is.null(error_message)) {
      shinyalert::shinyalert(
        "Error",
        error_message,
        type = "error"
      )
      shiny::session$userData$error <- NULL
    }
  })
}

# ============================================================================
# Run Application
# ============================================================================

shiny::shinyApp(ui, server)
