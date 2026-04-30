# app.R — Entry point for the AAST Classroom Emotion Analytics portal
#
# Architecture (see explanation.md for a junior-developer walkthrough):
#
#   1. global.R  — loads libraries, sets constants, wires up reactivePoll
#   2. htmlTemplate() — injects Shiny components into www/template.html
#      (the AAST Moodle "costume").  Design and logic are kept separate.
#   3. Role routing — after login, the UI switches between admin_ui() and
#      lecturer_ui() based on the JWT role claim returned by FastAPI.
#
# Data isolation (non-negotiable):
#   • This app NEVER connects to SQLite directly.
#   • All data comes from nightly CSV exports polled via reactivePoll.

# global.R sources all modules, ui/* and server/* files
source("global.R")

# ── UI ─────────────────────────────────────────────────────────────────────────
ui <- htmlTemplate(
  # The AAST Moodle "costume" — provides navy/gold branding, bilingual font,
  # RTL support, logo and footer.  DO NOT rebuild this chrome in R.
  filename = file.path("www", "template.html"),

  # {{ userMenuOutput }} — reactive: shows logged-in user name + role badge.
  userMenuOutput = uiOutput("user_menu"),

  # {{ roleTabsOutput }} — reactive: switches between admin and lecturer nav.
  roleTabsOutput = uiOutput("role_tabs"),

  # {{ mainPanelOutput }} — reactive: renders the correct panel set for the role.
  mainPanelOutput = uiOutput("main_panel")
)

# ── Server ─────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # ── Session state ───────────────────────────────────────────────────────────
  # In Phase 1 the role is hard-coded to "lecturer" so S2 can test the full UI.
  # Phase 2+: replace with a real JWT validation call to FASTAPI_BASE/auth/verify.
  user_role <- reactiveVal("lecturer")   # "admin" | "lecturer"
  user_name <- reactiveVal("Demo User")

  # ── Nightly CSV poll (shared across all panels) ─────────────────────────────
  exports <- make_csv_poll(session)

  # ── User menu (top-right of navbar) ─────────────────────────────────────────
  output$user_menu <- renderUI({
    role_badge_color <- switch(user_role(), admin = "#C9A84C", lecturer = "#28a745", "#6c757d")
    tags$div(
      style = "display:flex; align-items:center; gap:10px; color:#fff;",
      tags$span(user_name()),
      tags$span(
        style = paste0("background:", role_badge_color,
                       "; color:#fff; padding:2px 8px; border-radius:12px;",
                       " font-size:0.75rem; font-weight:700; text-transform:uppercase;"),
        user_role()
      )
    )
  })

  # ── Role-based tab navigation ────────────────────────────────────────────────
  output$role_tabs <- renderUI({
    switch(user_role(),
      admin    = tags$div(class = "aast-role-label",
                          style = "color:#C9A84C; padding:10px 24px; font-weight:700;",
                          icon("shield-alt"), " Admin Portal"),
      lecturer = tags$div(class = "aast-role-label",
                          style = "color:#C9A84C; padding:10px 24px; font-weight:700;",
                          icon("chalkboard-teacher"), " Lecturer Portal"),
      tags$div()
    )
  })

  # ── Main panel: switch UI by role ───────────────────────────────────────────
  output$main_panel <- renderUI({
    switch(user_role(),
      admin    = admin_ui(),
      lecturer = lecturer_ui(),
      div(class = "alert alert-warning", "Unknown role. Please log in again.")
    )
  })

  # ── Delegate server logic to role modules ───────────────────────────────────
  observe({
    role <- user_role()
    if (role == "admin") {
      admin_server(input, output, session, exports)
    } else if (role == "lecturer") {
      lecturer_server(input, output, session, exports)
    }
  })
}

shinyApp(ui, server)
