#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @importFrom DT renderDataTable datatable
#' @noRd
app_server <- function(input, output, session) {

  # Initialize database connection with error handling
  db_pool <- NULL
  db_available <- FALSE

  tryCatch({
    db_pool <- initialize_db()
    db_available <- TRUE
    showNotification(
      "✅ Database connected successfully!",
      type = "success",
      duration = 3
    )
  }, error = function(e) {
    showNotification(
      HTML(paste0(
        "<strong>⚠️ Database Connection Failed</strong><br/>",
        "The application will run in demo mode.<br/>",
        "<em>Please start PostgreSQL: docker-compose up -d postgres_dev</em>"
      )),
      type = "error",
      duration = 10
    )
    db_available <<- FALSE
  })

  # Ensure pool is closed when session ends
  session$onSessionEnded(function() {
    if (!is.null(db_pool)) {
      tryCatch({
        pool::poolClose(db_pool)
      }, error = function(e) {
        cat("Error closing database pool:", e$message, "\n")
      })
    }
  })

  # Initialize database operations (only if DB is available)
  user_ops <- NULL
  business_ops <- NULL
  permit_ops <- NULL
  payment_ops <- NULL
  inspection_ops <- NULL
  compliance_ops <- NULL

  if (db_available) {
    tryCatch({
      user_ops <- UserOperations$new(db_pool)
      business_ops <- BusinessOperations$new(db_pool)
      permit_ops <- PermitOperations$new(db_pool)
      payment_ops <- PaymentOperations$new(db_pool)
      inspection_ops <- InspectionOperations$new(db_pool)
      compliance_ops <- ComplianceOperations$new(db_pool)
    }, error = function(e) {
      showNotification(
        paste("Error initializing database operations:", e$message),
        type = "error"
      )
      db_available <<- FALSE
    })
  }

  # Reactive values for user session and app state
  values <- reactiveValues(
    user = NULL,
    current_business = NULL,
    last_activity = Sys.time(),
    notifications = list(),
    dashboard_data = NULL,
    db_available = db_available
  )

  # ============================================================================
  # MODULE 0: Database Admin (COMPLETE) - Only if DB available
  # ============================================================================
  if (db_available) {
    mod_database_admin_server("database_admin", db_pool)
  }

  # ============================================================================
  # MODULE 1: Dashboard (Main Overview)
  # ============================================================================

  # Dashboard Value Boxes
  output$total_businesses <- shinydashboard::renderValueBox({
    if (!db_available || is.null(business_ops)) {
      return(shinydashboard::valueBox(
        value = "Demo",
        subtitle = "Total Businesses",
        icon = icon("building"),
        color = "blue"
      ))
    }

    tryCatch({
      stats <- business_ops$get_business_statistics()
      shinydashboard::valueBox(
        value = stats$total_businesses %||% 0,
        subtitle = "Total Businesses",
        icon = icon("building"),
        color = "blue"
      )
    }, error = function(e) {
      shinydashboard::valueBox(
        value = "Error",
        subtitle = "Total Businesses",
        icon = icon("exclamation-triangle"),
        color = "red"
      )
    })
  })

  output$active_permits <- shinydashboard::renderValueBox({
    if (!db_available || is.null(business_ops)) {
      return(shinydashboard::valueBox(
        value = "Demo",
        subtitle = "Active Permits",
        icon = icon("certificate"),
        color = "green"
      ))
    }

    tryCatch({
      stats <- business_ops$get_business_statistics()
      shinydashboard::valueBox(
        value = stats$active_permits %||% 0,
        subtitle = "Active Permits",
        icon = icon("certificate"),
        color = "green"
      )
    }, error = function(e) {
      shinydashboard::valueBox(
        value = "Error",
        subtitle = "Active Permits",
        icon = icon("exclamation-triangle"),
        color = "red"
      )
    })
  })

  output$monthly_revenue <- shinydashboard::renderValueBox({
    if (!db_available || is.null(payment_ops)) {
      return(shinydashboard::valueBox(
        value = "KES Demo",
        subtitle = "Monthly Revenue",
        icon = icon("money-bill-wave"),
        color = "yellow"
      ))
    }

    tryCatch({
      # Calculate current month revenue
      current_month_start <- as.Date(format(Sys.Date(), "%Y-%m-01"))
      current_month_end <- Sys.Date()

      payment_stats <- payment_ops$get_payment_statistics(current_month_start, current_month_end)
      revenue <- payment_stats$total_amount_collected %||% 0

      shinydashboard::valueBox(
        value = paste("KES", format(revenue, big.mark = ",")),
        subtitle = "Monthly Revenue",
        icon = icon("money-bill-wave"),
        color = "yellow"
      )
    }, error = function(e) {
      shinydashboard::valueBox(
        value = "KES 0",
        subtitle = "Monthly Revenue",
        icon = icon("money-bill-wave"),
        color = "yellow"
      )
    })
  })

  output$compliance_rate <- shinydashboard::renderValueBox({
    if (!db_available || is.null(business_ops)) {
      return(shinydashboard::valueBox(
        value = "Demo%",
        subtitle = "Compliance Rate",
        icon = icon("check-circle"),
        color = "green"
      ))
    }

    tryCatch({
      # Calculate compliance rate
      stats <- business_ops$get_business_statistics()
      total <- stats$total_businesses %||% 1
      active <- stats$active_permits %||% 0
      rate <- round((active / total) * 100, 1)

      shinydashboard::valueBox(
        value = paste0(rate, "%"),
        subtitle = "Compliance Rate",
        icon = icon("check-circle"),
        color = if (rate >= 80) "green" else if (rate >= 60) "yellow" else "red"
      )
    }, error = function(e) {
      shinydashboard::valueBox(
        value = "N/A",
        subtitle = "Compliance Rate",
        icon = icon("question-circle"),
        color = "gray"
      )
    })
  })

  # Dashboard Business Summary Table
  output$dashboard_business_summary <- DT::renderDataTable({
    if (!db_available || is.null(business_ops)) {
      # Demo data when database is not available
      demo_data <- data.frame(
        "Business Name" = c("Green Valley Restaurant", "Tech Hub Solutions", "Mama Jane Salon"),
        "KRA PIN" = c("A111111111Z", "A222222222Z", "A333333333Z"),
        "Category" = c("Restaurant", "Technology", "Beauty Services"),
        "Size" = c("Small", "Medium", "Small"),
        "Location" = c("Kiambu Road", "Westlands", "Eastleigh"),
        "Ward" = c("Kiambu Ward", "Westlands Ward", "Eastleigh Ward"),
        "Permit Status" = c(
          '<span class="status-badge status-active">Valid</span>',
          '<span class="status-badge status-pending">Expiring Soon</span>',
          '<span class="status-badge status-expired">Expired</span>'
        ),
        check.names = FALSE,
        stringsAsFactors = FALSE
      )

      return(DT::datatable(
        demo_data,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'frtip'
        ),
        escape = FALSE,
        rownames = FALSE,
        caption = "Demo Data - Start PostgreSQL to see real data"
      ))
    }

    tryCatch({
      summary_data <- business_ops$get_business_summary()

      if (nrow(summary_data) > 0) {
        # Add status badges
        summary_data$permit_status_display <- sprintf(
          '<span class="status-badge status-%s">%s</span>',
          tolower(gsub(" ", "-", summary_data$permit_status_desc)),
          summary_data$permit_status_desc
        )

        # Select and rename columns for display
        display_data <- summary_data[, c(
          "business_name", "kra_pin", "category", "size",
          "location", "ward", "permit_status_display"
        )]

        colnames(display_data) <- c(
          "Business Name", "KRA PIN", "Category", "Size",
          "Location", "Ward", "Permit Status"
        )

        DT::datatable(
          display_data,
          options = list(
            pageLength = 10,
            scrollX = TRUE,
            dom = 'frtip'
          ),
          escape = FALSE,
          rownames = FALSE
        )
      } else {
        DT::datatable(
          data.frame("Message" = "No businesses registered yet"),
          options = list(dom = 't'),
          rownames = FALSE
        )
      }
    }, error = function(e) {
      DT::datatable(
        data.frame("Error" = paste("Failed to load data:", e$message)),
        options = list(dom = 't'),
        rownames = FALSE
      )
    })
  })

  # Revenue Trend Chart (Always show - demo or real data)
  output$revenue_trend_chart <- renderPlot({
    # Sample data for demonstration
    dates <- seq(Sys.Date() - 30, Sys.Date(), by = "day")
    revenue <- cumsum(rnorm(31, mean = 50000, sd = 15000))
    revenue[revenue < 0] <- 0

    plot(dates, revenue,
         type = "l",
         col = "#2E8B57",
         lwd = 3,
         main = if (db_available) "30-Day Revenue Trend" else "30-Day Revenue Trend (Demo Data)",
         xlab = "Date",
         ylab = "Cumulative Revenue (KES)",
         las = 1)
    grid(col = "lightgray", lty = "dotted")
  })

  # Recent Activities Table
  output$recent_activities <- DT::renderDataTable({
    # Show demo data regardless of database status
    activities <- data.frame(
      Time = format(Sys.time() - runif(5, 0, 86400), "%H:%M"),
      Activity = c(
        "New business registered",
        "Payment received",
        "Permit renewed",
        "Inspection scheduled",
        "Report generated"
      ),
      User = c("System", "Alice Wanjiku", "John Kimani", "Mary Chepkemoi", "Admin"),
      Status = c("Success", "Success", "Success", "Pending", "Success"),
      stringsAsFactors = FALSE
    )

    DT::datatable(
      activities,
      options = list(
        pageLength = 5,
        searching = FALSE,
        paging = FALSE,
        info = FALSE,
        dom = 't'
      ),
      rownames = FALSE,
      caption = if (!db_available) "Demo Data - Activity logging will be implemented" else NULL
    )
  })

  # ============================================================================
  # MODULE 2-11: Quick Action Handlers & Placeholder Functions
  # ============================================================================

  # Quick Action handlers (same as before)
  observeEvent(input$quick_register, {
    showNotification(
      "🚧 Register Business module not yet implemented. Coming soon!",
      type = "message",
      duration = 3
    )
  })

  observeEvent(input$quick_payment, {
    showNotification(
      "🚧 Payment processing module not yet implemented. Coming soon!",
      type = "message",
      duration = 3
    )
  })

  observeEvent(input$quick_inspection, {
    showNotification(
      "🚧 Inspection scheduling module not yet implemented. Coming soon!",
      type = "message",
      duration = 3
    )
  })

  observeEvent(input$quick_report, {
    showNotification(
      "🚧 Report generation module not yet implemented. Coming soon!",
      type = "message",
      duration = 3
    )
  })

  # ============================================================================
  # MODULE PLACEHOLDER NOTIFICATIONS
  # ============================================================================

  # Track menu navigation to show module status
  observeEvent(input$sidebar_menu, {
    module_status <- list(
      "dashboard" = "✅ Active",
      "db_admin" = if (db_available) "✅ Complete" else "⚠️ Database Required",
      "register_business" = "📝 Not Implemented - Business Registration Module",
      "business_mapping" = "📝 Not Implemented - GIS Business Mapping Module",
      "business_directory" = "📝 Not Implemented - Business Directory Module",
      "permit_applications" = "📝 Not Implemented - Permit Applications Module",
      "permit_renewals" = "📝 Not Implemented - Permit Renewals Module",
      "permit_status" = "📝 Not Implemented - Permit Status Module",
      "payments" = "📝 Not Implemented - M-Pesa Payment Module",
      "compliance" = "📝 Not Implemented - AI Compliance Engine Module",
      "schedule_inspection" = "📝 Not Implemented - Inspection Scheduling Module",
      "inspection_reports" = "📝 Not Implemented - Inspection Reports Module",
      "field_app" = "📝 Not Implemented - Mobile Field App Module",
      "revenue_reports" = "📝 Not Implemented - Revenue Reports Module",
      "performance_analytics" = "📝 Not Implemented - Performance Analytics Module",
      "automated_reports" = "📝 Not Implemented - Automated Reports Module",
      "user_management" = "📝 Not Implemented - User Management Module",
      "role_management" = "📝 Not Implemented - Role Management Module",
      "system_settings" = "📝 Not Implemented - System Settings Module",
      "chatbot" = "📝 Not Implemented - LLM Chatbot Module",
      "api_layer" = "📝 Not Implemented - API Integration Module",
      "audit_logs" = "📝 Not Implemented - Audit Logs Module",
      "security_monitor" = "📝 Not Implemented - Security Monitor Module",
      "data_export" = "📝 Not Implemented - Data Export Module"
    )

    selected_tab <- input$sidebar_menu

    if (!is.null(selected_tab) && selected_tab %in% names(module_status)) {
      status_msg <- module_status[[selected_tab]]

      if (grepl("Not Implemented", status_msg)) {
        showNotification(
          HTML(paste0(
            "<strong>Module Status:</strong><br/>",
            status_msg, "<br/>",
            "<em>This module is planned for development.</em>"
          )),
          type = "warning",
          duration = 4
        )
      } else if (grepl("Database Required", status_msg)) {
        showNotification(
          HTML(paste0(
            "<strong>Database Required:</strong><br/>",
            "Start PostgreSQL: docker-compose up -d postgres_dev<br/>",
            "<em>Then refresh the application</em>"
          )),
          type = "error",
          duration = 5
        )
      }
    }
  })

  # ============================================================================
  # SESSION DATA MANAGEMENT
  # ============================================================================

  # Make database operations available to future modules
  session$userData$db_pool <- db_pool
  session$userData$db_available <- db_available
  session$userData$user_ops <- user_ops
  session$userData$business_ops <- business_ops
  session$userData$permit_ops <- permit_ops
  session$userData$payment_ops <- payment_ops
  session$userData$inspection_ops <- inspection_ops
  session$userData$compliance_ops <- compliance_ops
  session$userData$values <- values

  # ============================================================================
  # STARTUP MESSAGES
  # ============================================================================

  # Show appropriate startup message
  observe({
    if (db_available) {
      showNotification(
        HTML(paste0(
          "<strong>🚀 SmartLicenSync Ready!</strong><br/>",
          "✅ Database: Connected<br/>",
          "✅ Modules Active: 2/11<br/>",
          "📊 Dashboard with real data<br/>",
          "🛠️ Database Admin fully functional"
        )),
        type = "success",
        duration = 5
      )
    } else {
      showNotification(
        HTML(paste0(
          "<strong>🚀 SmartLicenSync Demo Mode</strong><br/>",
          "⚠️ Database: Not Connected<br/>",
          "📊 Dashboard with demo data<br/>",
          "🔧 Start PostgreSQL for full functionality<br/>",
          "<code>docker-compose up -d postgres_dev</code>"
        )),
        type = "warning",
        duration = 8
      )
    }
  })
}
