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

    # SmartLicenSync Application UI
    shinydashboard::dashboardPage(

      # Header
      shinydashboard::dashboardHeader(
        title = "SmartLicenSync - Kericho County",
        titleWidth = 300,
        tags$li(class = "dropdown",
                tags$a(href = "https://github.com/RobertKimutai-DS/SBPoptimizer",
                       icon("github"), "GitHub", target = "_blank")),
        tags$li(class = "dropdown",
                tags$a(href = "#", icon("user"), "Profile"))
      ),

      # Sidebar
      shinydashboard::dashboardSidebar(
        width = 300,
        shinydashboard::sidebarMenu(
          id = "sidebar_menu",

          # Main Dashboard
          shinydashboard::menuItem("Dashboard",
                                   tabName = "dashboard",
                                   icon = icon("tachometer-alt"),
                                   badgeLabel = "Overview",
                                   badgeColor = "blue"),

          # Core Business Operations
          shinydashboard::menuItem("Business Operations",
                                   icon = icon("briefcase"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("Register Business",
                                                               tabName = "register_business",
                                                               icon = icon("plus-circle")),
                                   shinydashboard::menuSubItem("Business Mapping",
                                                               tabName = "business_mapping",
                                                               icon = icon("map-marked-alt")),
                                   shinydashboard::menuSubItem("Business Directory",
                                                               tabName = "business_directory",
                                                               icon = icon("building"))
          ),

          # Permit Management
          shinydashboard::menuItem("Permit Management",
                                   icon = icon("certificate"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("Permit Applications",
                                                               tabName = "permit_applications",
                                                               icon = icon("file-alt")),
                                   shinydashboard::menuSubItem("Permit Renewals",
                                                               tabName = "permit_renewals",
                                                               icon = icon("redo")),
                                   shinydashboard::menuSubItem("Permit Status",
                                                               tabName = "permit_status",
                                                               icon = icon("check-circle"))
          ),

          # Payments & Revenue
          shinydashboard::menuItem("Payments",
                                   tabName = "payments",
                                   icon = icon("credit-card"),
                                   badgeLabel = "M-Pesa",
                                   badgeColor = "green"),

          # Compliance & Intelligence
          shinydashboard::menuItem("Compliance Engine",
                                   tabName = "compliance",
                                   icon = icon("brain"),
                                   badgeLabel = "AI",
                                   badgeColor = "purple"),

          # Inspections
          shinydashboard::menuItem("Inspections",
                                   icon = icon("search"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("Schedule Inspection",
                                                               tabName = "schedule_inspection",
                                                               icon = icon("calendar-plus")),
                                   shinydashboard::menuSubItem("Inspection Reports",
                                                               tabName = "inspection_reports",
                                                               icon = icon("clipboard-list")),
                                   shinydashboard::menuSubItem("Field App",
                                                               tabName = "field_app",
                                                               icon = icon("mobile-alt"))
          ),

          # Reports & Analytics
          shinydashboard::menuItem("Reports & Analytics",
                                   icon = icon("chart-bar"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("Revenue Reports",
                                                               tabName = "revenue_reports",
                                                               icon = icon("money-bill-wave")),
                                   shinydashboard::menuSubItem("Performance Analytics",
                                                               tabName = "performance_analytics",
                                                               icon = icon("chart-line")),
                                   shinydashboard::menuSubItem("Automated Reports",
                                                               tabName = "automated_reports",
                                                               icon = icon("file-pdf"))
          ),

          # Admin & Management
          shinydashboard::menuItem("Admin Panel",
                                   icon = icon("users-cog"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("User Management",
                                                               tabName = "user_management",
                                                               icon = icon("users")),
                                   shinydashboard::menuSubItem("Role Management",
                                                               tabName = "role_management",
                                                               icon = icon("user-shield")),
                                   shinydashboard::menuSubItem("System Settings",
                                                               tabName = "system_settings",
                                                               icon = icon("cogs"))
          ),

          # AI Assistant
          shinydashboard::menuItem("AI Assistant",
                                   tabName = "chatbot",
                                   icon = icon("robot"),
                                   badgeLabel = "LLM",
                                   badgeColor = "yellow"),

          # API & Integrations
          shinydashboard::menuItem("API & Integrations",
                                   tabName = "api_layer",
                                   icon = icon("plug")),

          # Security & Audit
          shinydashboard::menuItem("Security & Audit",
                                   icon = icon("shield-alt"),
                                   startExpanded = FALSE,
                                   shinydashboard::menuSubItem("Audit Logs",
                                                               tabName = "audit_logs",
                                                               icon = icon("history")),
                                   shinydashboard::menuSubItem("Security Monitor",
                                                               tabName = "security_monitor",
                                                               icon = icon("eye")),
                                   shinydashboard::menuSubItem("Data Export",
                                                               tabName = "data_export",
                                                               icon = icon("download"))
          ),

          # Database Admin (Existing)
          shinydashboard::menuItem("Database Admin",
                                   tabName = "db_admin",
                                   icon = icon("database"),
                                   badgeLabel = "Dev",
                                   badgeColor = "red")
        )
      ),

      # Main Content
      shinydashboard::dashboardBody(

        # Custom CSS
        tags$head(
          tags$style(HTML("
            .main-header .navbar {
              background-color: #2E8B57 !important;
            }
            .main-header .logo {
              background-color: #228B22 !important;
            }
            .sidebar-menu > li.active > a {
              background-color: #2E8B57 !important;
            }
            .content-wrapper {
              background-color: #f4f4f4;
            }
            .info-box {
              background: #fff;
              border-radius: 5px;
              box-shadow: 0 1px 3px rgba(0,0,0,.12), 0 1px 2px rgba(0,0,0,.24);
            }
            .status-badge {
              padding: 5px 10px;
              border-radius: 15px;
              color: white;
              font-weight: bold;
            }
            .status-pending { background-color: #f39c12; }
            .status-active { background-color: #27ae60; }
            .status-expired { background-color: #e74c3c; }
          "))
        ),

        shinydashboard::tabItems(

          # 1. Dashboard (Main Overview)
          shinydashboard::tabItem(tabName = "dashboard",
                                  fluidRow(
                                    shinydashboard::valueBoxOutput("total_businesses", width = 3),
                                    shinydashboard::valueBoxOutput("active_permits", width = 3),
                                    shinydashboard::valueBoxOutput("monthly_revenue", width = 3),
                                    shinydashboard::valueBoxOutput("compliance_rate", width = 3)
                                  ),
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Business Permit Overview",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 8,
                                      DT::dataTableOutput("dashboard_business_summary")
                                    ),
                                    shinydashboard::box(
                                      title = "Quick Actions",
                                      status = "success",
                                      solidHeader = TRUE,
                                      width = 4,
                                      actionButton("quick_register", "Register New Business",
                                                   class = "btn-success btn-lg btn-block",
                                                   icon = icon("plus")),
                                      br(),
                                      actionButton("quick_payment", "Process Payment",
                                                   class = "btn-primary btn-lg btn-block",
                                                   icon = icon("credit-card")),
                                      br(),
                                      actionButton("quick_inspection", "Schedule Inspection",
                                                   class = "btn-warning btn-lg btn-block",
                                                   icon = icon("search")),
                                      br(),
                                      actionButton("quick_report", "Generate Report",
                                                   class = "btn-info btn-lg btn-block",
                                                   icon = icon("file-pdf"))
                                    )
                                  ),
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Revenue Trends",
                                      status = "info",
                                      solidHeader = TRUE,
                                      width = 6,
                                      plotOutput("revenue_trend_chart")
                                    ),
                                    shinydashboard::box(
                                      title = "Recent Activities",
                                      status = "warning",
                                      solidHeader = TRUE,
                                      width = 6,
                                      DT::dataTableOutput("recent_activities")
                                    )
                                  )
          ),

          # 2. Register Business Module
          shinydashboard::tabItem(tabName = "register_business",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Business Registration Form",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 8,
                                      h3("📝 Digital Business Registration"),
                                      p("Complete business permit application with real-time validation and fee calculation."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("📱 Mobile-first application form"),
                                                 tags$li("🔍 KRA PIN auto-validation"),
                                                 tags$li("📍 GPS geolocation tagging"),
                                                 tags$li("💰 Dynamic fee calculation"),
                                                 tags$li("📄 Instant PDF permit generation with QR code"),
                                                 tags$li("✅ Real-time business verification")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    ),
                                    shinydashboard::box(
                                      title = "Registration Statistics",
                                      status = "success",
                                      solidHeader = TRUE,
                                      width = 4,
                                      h4("Today's Registrations"),
                                      h2("0", style = "color: #27ae60;"),
                                      hr(),
                                      h4("This Month"),
                                      h2("0", style = "color: #3498db;"),
                                      hr(),
                                      h4("Success Rate"),
                                      h2("--", style = "color: #f39c12;")
                                    )
                                  )
          ),

          # 3. Business Mapping Module
          shinydashboard::tabItem(tabName = "business_mapping",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "GIS Business Mapping",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🗺️ Interactive Business Maps"),
                                      p("Visualize registered and unregistered businesses across Kericho County."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🗺️ Interactive Leaflet maps"),
                                                 tags$li("🔍 Filter by ward, street, and business sector"),
                                                 tags$li("📍 Google Places API integration"),
                                                 tags$li("📱 Mobile field app for geo-tagging"),
                                                 tags$li("🎯 Inspection route optimization"),
                                                 tags$li("📊 Spatial analytics and heatmaps")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 4. Business Directory
          shinydashboard::tabItem(tabName = "business_directory",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Business Directory Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🏢 Complete Business Directory"),
                                      p("Search, filter, and manage all registered businesses in Kericho County."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🔍 Advanced search and filtering"),
                                                 tags$li("📊 Business profile management"),
                                                 tags$li("📁 Document upload and storage"),
                                                 tags$li("📞 Contact management"),
                                                 tags$li("🏷️ Business categorization"),
                                                 tags$li("📈 Business performance tracking")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 5. Payments Module
          shinydashboard::tabItem(tabName = "payments",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Payment Processing Center",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 8,
                                      h3("💳 M-Pesa & Payment Integration"),
                                      p("Real-time payment processing with M-Pesa STK push and reconciliation."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("📱 M-Pesa STK push integration"),
                                                 tags$li("💰 Real-time payment verification"),
                                                 tags$li("🧾 Automatic receipt generation"),
                                                 tags$li("📧 SMS/Email payment confirmations"),
                                                 tags$li("🔄 Payment reconciliation dashboard"),
                                                 tags$li("📊 Revenue analytics and reporting")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    ),
                                    shinydashboard::box(
                                      title = "Payment Statistics",
                                      status = "success",
                                      solidHeader = TRUE,
                                      width = 4,
                                      h4("Today's Collections"),
                                      h2("KES 0", style = "color: #27ae60;"),
                                      hr(),
                                      h4("This Month"),
                                      h2("KES 0", style = "color: #3498db;"),
                                      hr(),
                                      h4("Success Rate"),
                                      h2("--", style = "color: #f39c12;")
                                    )
                                  )
          ),

          # 6. Compliance Engine Module
          shinydashboard::tabItem(tabName = "compliance",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "AI-Driven Compliance Intelligence",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🧠 Machine Learning Compliance Engine"),
                                      p("Predict defaulters, analyze behavioral patterns, and generate smart alerts."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🤖 Risk scoring model using tidymodels"),
                                                 tags$li("📊 Behavioral clustering analysis"),
                                                 tags$li("⚠️ Smart alert system for high-risk businesses"),
                                                 tags$li("📈 Predictive analytics dashboard"),
                                                 tags$li("🎯 Targeted intervention strategies"),
                                                 tags$li("📋 Compliance trend analysis")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 7. Reports Module
          shinydashboard::tabItem(tabName = "revenue_reports",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Automated Reporting System",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("📑 Quarto-Based Report Generation"),
                                      p("Automated daily, weekly, and monthly reports with PDF/HTML export."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("📄 Quarto-based PDF/HTML reports"),
                                                 tags$li("⏰ Automated scheduling system"),
                                                 tags$li("📧 Email distribution to stakeholders"),
                                                 tags$li("📊 Performance metrics and KPIs"),
                                                 tags$li("📈 Revenue vs. projection analysis"),
                                                 tags$li("🎯 Custom report builder")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 8. Admin Panel Module
          shinydashboard::tabItem(tabName = "user_management",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Role-Based Administration",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("👥 User & Role Management"),
                                      p("Comprehensive admin panel with role-based access control and audit logging."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("👤 User management interface"),
                                                 tags$li("🛡️ Role-based permission system"),
                                                 tags$li("📋 Activity and audit logs"),
                                                 tags$li("🎫 Internal ticketing system"),
                                                 tags$li("⚡ Real-time system monitoring"),
                                                 tags$li("🔧 System configuration management")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 9. Chatbot Module
          shinydashboard::tabItem(tabName = "chatbot",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "LLM-Powered AI Assistant",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🤖 Multilingual Chatbot Assistant"),
                                      p("AI-powered assistant using ellmer + ragnar for citizen and staff support."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🤖 LLM integration with ellmer package"),
                                                 tags$li("🌍 Multilingual support (English, Kiswahili)"),
                                                 tags$li("❓ FAQ automation for citizens"),
                                                 tags$li("📚 Staff training and support"),
                                                 tags$li("🔍 Document search with ragnar"),
                                                 tags$li("💬 Real-time chat interface")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 10. API Layer Module
          shinydashboard::tabItem(tabName = "api_layer",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Open API Ecosystem",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🔗 RESTful API Integration"),
                                      p("Secure API endpoints for mobile apps, ERP systems, and third-party integrations."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🔌 RESTful endpoints with plumber"),
                                                 tags$li("🔐 API authentication and rate limiting"),
                                                 tags$li("📱 Mobile app integration endpoints"),
                                                 tags$li("💼 ERP system connectivity"),
                                                 tags$li("🔔 Webhook support for real-time updates"),
                                                 tags$li("📖 Interactive API documentation")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 11. Security & Audit Module
          shinydashboard::tabItem(tabName = "audit_logs",
                                  fluidRow(
                                    shinydashboard::box(
                                      title = "Security & Audit Management",
                                      status = "primary",
                                      solidHeader = TRUE,
                                      width = 12,
                                      h3("🛡️ Comprehensive Security & Audit System"),
                                      p("Advanced security monitoring, audit trails, and anomaly detection."),
                                      tags$div(class = "alert alert-info",
                                               tags$strong("Features to implement:"),
                                               tags$ul(
                                                 tags$li("🔐 Enhanced authentication system"),
                                                 tags$li("📋 Tamper-proof audit logging"),
                                                 tags$li("🔍 Anomaly detection algorithms"),
                                                 tags$li("⚠️ Real-time security alerts"),
                                                 tags$li("📊 Security dashboard and monitoring"),
                                                 tags$li("💾 Secure data export for auditors")
                                               )
                                      ),
                                      tags$hr(),
                                      p("📊 Module Status: ",
                                        tags$span("Not Implemented", class = "status-badge status-pending"))
                                    )
                                  )
          ),

          # 12. Database Admin (Existing - Complete)
          shinydashboard::tabItem(tabName = "db_admin",
                                  mod_database_admin_ui("database_admin")
          ),

          # Additional placeholder tabs for sub-modules
          shinydashboard::tabItem(tabName = "permit_applications",
                                  shinydashboard::box(
                                    title = "Permit Applications",
                                    status = "primary",
                                    solidHeader = TRUE,
                                    width = 12,
                                    h3("📋 Permit Application Management"),
                                    p("Handle new permit applications with automated workflow.")
                                  )
          ),

          shinydashboard::tabItem(tabName = "permit_renewals",
                                  shinydashboard::box(
                                    title = "Permit Renewals",
                                    status = "primary",
                                    solidHeader = TRUE,
                                    width = 12,
                                    h3("🔄 Permit Renewal System"),
                                    p("Streamlined permit renewal process with automatic reminders.")
                                  )
          ),

          shinydashboard::tabItem(tabName = "schedule_inspection",
                                  shinydashboard::box(
                                    title = "Schedule Inspection",
                                    status = "primary",
                                    solidHeader = TRUE,
                                    width = 12,
                                    h3("📅 Inspection Scheduling"),
                                    p("Smart inspection scheduling with route optimization.")
                                  )
          ),

          shinydashboard::tabItem(tabName = "field_app",
                                  shinydashboard::box(
                                    title = "Field Inspection App",
                                    status = "primary",
                                    solidHeader = TRUE,
                                    width = 12,
                                    h3("📱 Mobile Field Application"),
                                    p("Mobile-optimized interface for field inspections.")
                                  )
          )
        )
      )
    )
  )
}

#' Add external Resources to the Application
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
      app_title = 'SmartLicenSync'
    )
  )
}
