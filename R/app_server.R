#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Initialize database connection
  db_pool <- initialize_db()

  # Ensure pool is closed when session ends
  session$onSessionEnded(function() {
    if (!is.null(db_pool)) {
      pool::poolClose(db_pool)
    }
  })

  # Initialize database operations
  user_ops <- UserOperations$new(db_pool)
  business_ops <- BusinessOperations$new(db_pool)
  permit_ops <- PermitOperations$new(db_pool)
  payment_ops <- PaymentOperations$new(db_pool)
  inspection_ops <- InspectionOperations$new(db_pool)
  compliance_ops <- ComplianceOperations$new(db_pool)

  # Reactive values for user session
  values <- reactiveValues(
    user = NULL,
    current_business = NULL,
    last_activity = Sys.time()
  )

  # Database administration module
  mod_database_admin_server("database_admin", db_pool)

  # Example: Dashboard data
  output$business_summary <- DT::renderDataTable({
    business_ops$get_business_summary()
  }, options = list(scrollX = TRUE))

  output$payment_stats <- renderText({
    stats <- payment_ops$get_payment_statistics()
    paste0(
      "Total Payments: ", stats$total_payments, "\n",
      "Successful: ", stats$successful_payments, "\n",
      "Total Collected: KES ", format(stats$total_amount_collected, big.mark = ",")
    )
  })

  # Make database operations available to other modules
  session$userData$db_pool <- db_pool
  session$userData$user_ops <- user_ops
  session$userData$business_ops <- business_ops
  session$userData$permit_ops <- permit_ops
  session$userData$payment_ops <- payment_ops
  session$userData$inspection_ops <- inspection_ops
  session$userData$compliance_ops <- compliance_ops
  session$userData$values <- values
}
