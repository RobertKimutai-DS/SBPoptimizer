#' Database Administration Module
#'
#' @description A Shiny module for database administration tasks
#'
#' @param id character Module ID
#'
#' @rdname mod_database_admin
#'
#' @keywords internal
#' @export
#' @importFrom shiny NS tagList fluidRow verbatimTextOutput actionButton br h4 textAreaInput observeEvent req renderText moduleServer
#' @importFrom shinydashboard box
#' @importFrom DT dataTableOutput renderDataTable datatable
mod_database_admin_ui <- function(id){
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::fluidRow(
      shinydashboard::box(
        title = "Database Status",
        status = "primary",
        solidHeader = TRUE,
        width = 6,
        shiny::verbatimTextOutput(ns("db_status")),
        shiny::br(),
        shiny::actionButton(ns("refresh_status"), "Refresh Status", class = "btn-info btn-sm"),
        shiny::actionButton(ns("run_migrations"), "Run Migrations", class = "btn-warning btn-sm"),
        shiny::actionButton(ns("create_backup"), "Create Backup", class = "btn-success btn-sm")
      ),
      shinydashboard::box(
        title = "Quick Statistics",
        status = "info",
        solidHeader = TRUE,
        width = 6,
        DT::dataTableOutput(ns("quick_stats")),
        shiny::br(),
        shiny::actionButton(ns("refresh_stats"), "Refresh Stats", class = "btn-info btn-sm")
      )
    ),
    shiny::fluidRow(
      shinydashboard::box(
        title = "SQL Query Console",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        shiny::tags$div(
          class = "form-group",
          shiny::tags$label("SQL Query:"),
          shiny::tags$textarea(
            id = ns("sql_query"),
            class = "form-control",
            rows = "5",
            placeholder = "SELECT * FROM users LIMIT 10;",
            "SELECT COUNT(*) as total_users FROM users;"
          )
        ),
        shiny::actionButton(ns("execute_query"), "Execute Query", class = "btn-primary"),
        shiny::br(), shiny::br(),
        DT::dataTableOutput(ns("query_results"))
      )
    ),
    shiny::fluidRow(
      shinydashboard::box(
        title = "Table Management",
        status = "warning",
        solidHeader = TRUE,
        width = 12,
        shiny::selectInput(ns("selected_table"), "Select Table:",
                           choices = c("users", "businesses", "permits", "payments", "inspections", "compliance_scores"),
                           selected = "users"),
        DT::dataTableOutput(ns("table_data")),
        shiny::br(),
        shiny::actionButton(ns("refresh_table"), "Refresh Table", class = "btn-info btn-sm")
      )
    )
  )
}

#' @rdname mod_database_admin
#' @export
#' @keywords internal
#' @importFrom shiny moduleServer reactiveValues observeEvent req renderText showNotification
#' @importFrom DBI dbGetQuery dbExecute
mod_database_admin_server <- function(id, db_pool){
  shiny::moduleServer(id, function(input, output, session){
    ns <- session$ns

    # Reactive values
    values <- shiny::reactiveValues(
      db_health = NULL,
      query_result = NULL,
      table_data = NULL,
      stats_data = NULL
    )

    # Database health check
    get_db_health <- shiny::reactive({
      tryCatch({
        check_db_health(db_pool)
      }, error = function(e) {
        list(status = "error", error = e$message, check_time = Sys.time())
      })
    })

    # Display database status
    output$db_status <- shiny::renderText({
      health <- get_db_health()

      if (health$status == "healthy") {
        paste0(
          "Status: HEALTHY ✓\n",
          "Connection: Active\n",
          "Users: ", health$table_counts$users, "\n",
          "Businesses: ", health$table_counts$businesses, "\n",
          "Permits: ", health$table_counts$permits, "\n",
          "Last Check: ", format(health$check_time, "%Y-%m-%d %H:%M:%S")
        )
      } else {
        paste0(
          "Status: ERROR ✗\n",
          "Error: ", health$error, "\n",
          "Last Check: ", format(health$check_time, "%Y-%m-%d %H:%M:%S")
        )
      }
    })

    # Quick statistics
    get_quick_stats <- shiny::reactive({
      tryCatch({
        business_ops <- BusinessOperations$new(db_pool)
        payment_ops <- PaymentOperations$new(db_pool)
        inspection_ops <- InspectionOperations$new(db_pool)

        bus_stats <- business_ops$get_business_statistics()
        pay_stats <- payment_ops$get_payment_statistics()
        insp_stats <- inspection_ops$get_inspection_statistics()

        data.frame(
          Metric = c("Total Businesses", "Active Permits", "Expired Permits",
                     "Total Payments", "Payment Success Rate", "Total Inspections"),
          Value = c(
            bus_stats$total_businesses,
            bus_stats$active_permits %||% 0,
            bus_stats$expired_permits %||% 0,
            pay_stats$total_payments,
            if(pay_stats$total_payments > 0) paste0(round((pay_stats$successful_payments / pay_stats$total_payments) * 100, 1), "%") else "0%",
            insp_stats$total_inspections
          )
        )
      }, error = function(e) {
        data.frame(Metric = "Error", Value = e$message)
      })
    })

    output$quick_stats <- DT::renderDataTable({
      shiny::req(input$refresh_stats || TRUE)
      get_quick_stats()
    }, options = list(pageLength = 10, searching = FALSE, paging = FALSE, info = FALSE))

    # Refresh actions
    shiny::observeEvent(input$refresh_status, {
      output$db_status <- shiny::renderText({
        health <- get_db_health()

        if (health$status == "healthy") {
          paste0(
            "Status: HEALTHY ✓\n",
            "Connection: Active\n",
            "Users: ", health$table_counts$users, "\n",
            "Businesses: ", health$table_counts$businesses, "\n",
            "Permits: ", health$table_counts$permits, "\n",
            "Last Check: ", format(health$check_time, "%Y-%m-%d %H:%M:%S")
          )
        } else {
          paste0(
            "Status: ERROR ✗\n",
            "Error: ", health$error, "\n",
            "Last Check: ", format(health$check_time, "%Y-%m-%d %H:%M:%S")
          )
        }
      })
    })

    shiny::observeEvent(input$refresh_stats, {
      output$quick_stats <- DT::renderDataTable({
        get_quick_stats()
      }, options = list(pageLength = 10, searching = FALSE, paging = FALSE, info = FALSE))
    })

    # Execute SQL query
    shiny::observeEvent(input$execute_query, {
      shiny::req(input$sql_query)

      query <- trimws(input$sql_query)
      if (nchar(query) == 0) {
        shiny::showNotification("Please enter a SQL query", type = "warning")
        return()
      }

      # Security check - only allow SELECT statements
      if (!grepl("^SELECT", toupper(query))) {
        shiny::showNotification("Only SELECT queries are allowed for security", type = "error")
        return()
      }

      tryCatch({
        result <- DBI::dbGetQuery(db_pool, query)
        values$query_result <- result
        shiny::showNotification("Query executed successfully!", type = "success")
      }, error = function(e) {
        shiny::showNotification(paste("Query error:", e$message), type = "error")
        values$query_result <- data.frame(Error = e$message)
      })
    })

    # Display query results
    output$query_results <- DT::renderDataTable({
      shiny::req(values$query_result)
      values$query_result
    }, options = list(scrollX = TRUE, pageLength = 15))

    # Table data display
    output$table_data <- DT::renderDataTable({
      shiny::req(input$selected_table)

      tryCatch({
        DBI::dbGetQuery(db_pool, paste("SELECT * FROM", input$selected_table, "LIMIT 100"))
      }, error = function(e) {
        data.frame(Error = paste("Failed to load table:", e$message))
      })
    }, options = list(scrollX = TRUE, pageLength = 10))

    # Refresh table
    shiny::observeEvent(input$refresh_table, {
      output$table_data <- DT::renderDataTable({
        shiny::req(input$selected_table)

        tryCatch({
          DBI::dbGetQuery(db_pool, paste("SELECT * FROM", input$selected_table, "LIMIT 100"))
        }, error = function(e) {
          data.frame(Error = paste("Failed to load table:", e$message))
        })
      }, options = list(scrollX = TRUE, pageLength = 10))
    })

    # Run migrations
    shiny::observeEvent(input$run_migrations, {
      tryCatch({
        run_migrations(db_pool)
        shiny::showNotification("Migrations completed successfully!", type = "success")
      }, error = function(e) {
        shiny::showNotification(paste("Migration error:", e$message), type = "error")
      })
    })

    # Create backup
    shiny::observeEvent(input$create_backup, {
      tryCatch({
        backup_file <- create_database_backup(db_pool)
        if (!is.null(backup_file)) {
          shiny::showNotification("Backup created successfully!", type = "success")
        } else {
          shiny::showNotification("Backup failed!", type = "error")
        }
      }, error = function(e) {
        shiny::showNotification(paste("Backup error:", e$message), type = "error")
      })
    })
  })
}
