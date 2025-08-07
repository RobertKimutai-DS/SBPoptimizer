#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @import shinydashboard
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),

    # Your application UI logic
    shinydashboard::dashboardPage(
      shinydashboard::dashboardHeader(title = "SBP Optimizer - Business Permit Management"),

      shinydashboard::dashboardSidebar(
        shinydashboard::sidebarMenu(
          shinydashboard::menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
          shinydashboard::menuItem("Businesses", tabName = "businesses", icon = icon("building")),
          shinydashboard::menuItem("Permits", tabName = "permits", icon = icon("certificate")),
          shinydashboard::menuItem("Payments", tabName = "payments", icon = icon("money-bill")),
          shinydashboard::menuItem("Inspections", tabName = "inspections", icon = icon("search")),
          shinydashboard::menuItem("Reports", tabName = "reports", icon = icon("chart-bar")),
          shinydashboard::menuItem("Database Admin", tabName = "db_admin", icon = icon("database"))
        )
      ),

      shinydashboard::dashboardBody(
        shinydashboard::tabItems(
          # Dashboard tab
          shinydashboard::tabItem(tabName = "dashboard",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Business Summary",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      DT::dataTableOutput("business_summary")
                                    )
                                  ),
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Payment Statistics",
                                      status = "info",
                                      solidHeader = TRUE,
                                      width = 6,
                                      verbatimTextOutput("payment_stats")
                                    ),
                                    shinydashboard::box(
                                      title = "Quick Actions",
                                      status = "success",
                                      solidHeader = TRUE,
                                      width = 6,
                                      actionButton("new_business", "Register New Business", class = "btn-primary btn-lg btn-block"),
                                      br(),
                                      actionButton("new_permit", "Issue New Permit", class = "btn-success btn-lg btn-block"),
                                      br(),
                                      actionButton("schedule_inspection", "Schedule Inspection", class = "btn-warning btn-lg btn-block")
                                    )
                                  )
          ),

          # Database Admin tab
          shinydashboard::tabItem(tabName = "db_admin",
                                  mod_database_admin_ui("database_admin")
          ),

          # Placeholder tabs for other modules
          shinydashboard::tabItem(tabName = "businesses",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Business Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("Business management functionality will be implemented here")
                                    )
                                  )
          ),

          shinydashboard::tabItem(tabName = "permits",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Permit Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("Permit management functionality will be implemented here")
                                    )
                                  )
          ),

          shinydashboard::tabItem(tabName = "payments",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Payment Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("Payment management functionality will be implemented here")
                                    )
                                  )
          ),

          shinydashboard::tabItem(tabName = "inspections",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Inspection Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("Inspection management functionality will be implemented here")
                                    )
                                  )
          ),

          shinydashboard::tabItem(tabName = "reports",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Reports & Analytics",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("Reports and analytics functionality will be implemented here")
                                    )
                                  )
          )
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function(){

  add_resource_path(
    'www', app_sys('app/www')
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys('app/www'),
      app_title = 'SBPoptimizer'
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
