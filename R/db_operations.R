#' Database Operations
#'
#' CRUD operations for database entities
#'
#' @name db_operations
NULL

#' Base Database Operations Class
#'
#' @description R6 class providing basic database operations
#' @export
#' @importFrom R6 R6Class
#' @importFrom DBI dbWriteTable dbExecute dbGetQuery
#' @importFrom dplyr tbl
#' @importFrom glue glue
DBOperations <- R6::R6Class(
  "DBOperations",
  public = list(
    #' @field pool Database connection pool
    pool = NULL,

    #' Initialize the database operations class
    #' @param pool Database connection pool object
    initialize = function(pool) {
      self$pool <- pool
    },

    #' Get a database table as a dplyr tbl object
    #' @param table_name Character string of table name
    #' @return A dplyr tbl object
    get_table = function(table_name) {
      dplyr::tbl(self$pool, table_name)
    },

    #' Insert a record into a table
    #' @param table_name Character string of table name
    #' @param data Data frame with record data
    insert_record = function(table_name, data) {
      DBI::dbWriteTable(
        self$pool,
        table_name,
        data,
        append = TRUE,
        row.names = FALSE
      )
    },

    #' Update a record in a table
    #' @param table_name Character string of table name
    #' @param id Record ID to update
    #' @param data Named list of columns and values to update
    #' @param id_column Character string of ID column name
    update_record = function(table_name, id, data, id_column = paste0(table_name, "_id")) {
      # Remove id column from data if present
      data[[id_column]] <- NULL

      if (length(data) == 0) {
        stop("No data to update")
      }

      set_clause <- paste0(
        names(data),
        " = $",
        seq_along(data),
        collapse = ", "
      )

      sql <- glue::glue(
        "UPDATE {table_name} SET {set_clause} WHERE {id_column} = ${length(data) + 1}"
      )

      DBI::dbExecute(self$pool, sql, params = c(unlist(data), id))
    },

    #' Delete a record from a table
    #' @param table_name Character string of table name
    #' @param id Record ID to delete
    #' @param id_column Character string of ID column name
    delete_record = function(table_name, id, id_column = paste0(table_name, "_id")) {
      sql <- glue::glue("DELETE FROM {table_name} WHERE {id_column} = $1")
      DBI::dbExecute(self$pool, sql, params = list(id))
    }
  )
)

#' User Operations Class
#'
#' @description R6 class for user management operations
#' @export
UserOperations <- R6::R6Class(
  "UserOperations",
  inherit = DBOperations,
  public = list(
    #' Create a new user
    #' @param name User's full name
    #' @param email User's email address
    #' @param phone User's phone number (optional)
    #' @param password_hash Hashed password
    #' @param role User role (admin, officer, inspector, finance)
    create_user = function(name, email, phone = NULL, password_hash, role = "officer") {
      user_data <- data.frame(
        name = name,
        email = email,
        phone = phone,
        password_hash = password_hash,
        role = role,
        stringsAsFactors = FALSE
      )

      self$insert_record("users", user_data)
    },

    #' Get user by email
    #' @param email User's email address
    #' @return Data frame with user information
    get_user_by_email = function(email) {
      self$get_table("users") %>%
        dplyr::filter(email == !!email) %>%
        dplyr::collect()
    },

    #' Get user by ID
    #' @param user_id User ID
    #' @return Data frame with user information
    get_user_by_id = function(user_id) {
      self$get_table("users") %>%
        dplyr::filter(user_id == !!user_id) %>%
        dplyr::collect()
    },

    #' Authenticate user
    #' @param email User's email
    #' @param password_hash Hashed password to verify
    #' @return User data frame if authenticated, NULL otherwise
    authenticate_user = function(email, password_hash) {
      user <- self$get_user_by_email(email)

      if (nrow(user) > 0 && user$is_active[1]) {
        # Simple password check (implement proper bcrypt verification in production)
        if (user$password_hash[1] == password_hash) {
          return(user[1, ])
        }
      }

      return(NULL)
    },

    #' Update user last activity
    #' @param user_id User ID
    update_user_activity = function(user_id) {
      DBI::dbExecute(
        self$pool,
        "UPDATE users SET created_at = CURRENT_TIMESTAMP WHERE user_id = $1",
        params = list(user_id)
      )
    }
  )
)

#' Business Operations Class
#'
#' @description R6 class for business management operations
#' @export
BusinessOperations <- R6::R6Class(
  "BusinessOperations",
  inherit = DBOperations,
  public = list(
    #' Create a new business
    #' @param owner_id User ID of business owner
    #' @param kra_pin KRA PIN number
    #' @param name Business name
    #' @param category Business category
    #' @param size Business size (Small, Medium, Large)
    #' @param location Business location
    #' @param latitude GPS latitude (optional)
    #' @param longitude GPS longitude (optional)
    #' @param ward Administrative ward
    create_business = function(owner_id, kra_pin, name, category, size, location, latitude = NULL, longitude = NULL, ward) {
      business_data <- data.frame(
        owner_id = owner_id,
        kra_pin = kra_pin,
        name = name,
        category = category,
        size = size,
        location = location,
        latitude = latitude,
        longitude = longitude,
        ward = ward,
        stringsAsFactors = FALSE
      )

      self$insert_record("businesses", business_data)
    },

    #' Get businesses by owner
    #' @param owner_id User ID of owner
    #' @return Data frame of businesses
    get_businesses_by_owner = function(owner_id) {
      self$get_table("businesses") %>%
        dplyr::filter(owner_id == !!owner_id, status == "active") %>%
        dplyr::arrange(dplyr::desc(created_at)) %>%
        dplyr::collect()
    },

    #' Get business summary with permit information
    #' @param business_id Business ID (optional, if NULL returns all)
    #' @return Data frame with business and permit summary
    get_business_summary = function(business_id = NULL) {
      if (is.null(business_id)) {
        # Query without parameters
        DBI::dbGetQuery(
          self$pool,
          "SELECT
            b.business_id,
            b.name as business_name,
            b.kra_pin,
            b.category,
            b.size,
            b.location,
            b.ward,
            b.status as business_status,
            p.permit_id,
            p.permit_year,
            p.status as permit_status,
            p.fee_amount,
            p.issue_date,
            p.expiry_date,
            CASE
              WHEN p.expiry_date < CURRENT_DATE THEN 'Expired'
              WHEN p.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
              ELSE 'Valid'
            END as permit_status_desc
          FROM businesses b
          LEFT JOIN permits p ON b.business_id = p.business_id AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
          WHERE b.status = 'active'
          ORDER BY b.name"
        )
      } else {
        # Query with parameters
        DBI::dbGetQuery(
          self$pool,
          "SELECT
            b.business_id,
            b.name as business_name,
            b.kra_pin,
            b.category,
            b.size,
            b.location,
            b.ward,
            b.status as business_status,
            p.permit_id,
            p.permit_year,
            p.status as permit_status,
            p.fee_amount,
            p.issue_date,
            p.expiry_date,
            CASE
              WHEN p.expiry_date < CURRENT_DATE THEN 'Expired'
              WHEN p.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
              ELSE 'Valid'
            END as permit_status_desc
          FROM businesses b
          LEFT JOIN permits p ON b.business_id = p.business_id AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
          WHERE b.status = 'active' AND b.business_id = $1
          ORDER BY b.name",
          params = list(business_id)
        )
      }
    },

    #' Search businesses
    #' @param search_term Search term for name or KRA PIN (optional)
    #' @param ward Ward filter (optional)
    #' @param category Category filter (optional)
    #' @param size Size filter (optional)
    #' @return Data frame of matching businesses
    search_businesses = function(search_term = NULL, ward = NULL, category = NULL, size = NULL) {
      sql <- "SELECT b.*, p.permit_year, p.status as permit_status
              FROM businesses b
              LEFT JOIN permits p ON b.business_id = p.business_id AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
              WHERE b.status = 'active'"
      params <- list()
      param_count <- 0

      if (!is.null(search_term)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND (b.name ILIKE $", param_count, " OR b.kra_pin ILIKE $", param_count, ")", sep = "")
        params <- append(params, paste0("%", search_term, "%"))
      }

      if (!is.null(ward)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND b.ward = $", param_count, sep = "")
        params <- append(params, ward)
      }

      if (!is.null(category)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND b.category = $", param_count, sep = "")
        params <- append(params, category)
      }

      if (!is.null(size)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND b.size = $", param_count, sep = "")
        params <- append(params, size)
      }

      sql <- paste(sql, "ORDER BY b.name")

      DBI::dbGetQuery(self$pool, sql, params = params)
    },

    #' Get business statistics
    #' @return Data frame with business statistics
    get_business_statistics = function() {
      DBI::dbGetQuery(
        self$pool,
        "SELECT
          COUNT(*) as total_businesses,
          COUNT(CASE WHEN p.status = 'issued' THEN 1 END) as active_permits,
          COUNT(CASE WHEN p.expiry_date < CURRENT_DATE THEN 1 END) as expired_permits,
          COUNT(CASE WHEN p.expiry_date < CURRENT_DATE + INTERVAL '30 days' AND p.expiry_date >= CURRENT_DATE THEN 1 END) as expiring_soon,
          COUNT(CASE WHEN b.size = 'Small' THEN 1 END) as small_businesses,
          COUNT(CASE WHEN b.size = 'Medium' THEN 1 END) as medium_businesses,
          COUNT(CASE WHEN b.size = 'Large' THEN 1 END) as large_businesses
        FROM businesses b
        LEFT JOIN permits p ON b.business_id = p.business_id AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
        WHERE b.status = 'active'"
      )
    }
  )
)

#' Permit Operations Class
#'
#' @description R6 class for permit management operations
#' @export
PermitOperations <- R6::R6Class(
  "PermitOperations",
  inherit = DBOperations,
  public = list(
    #' Create a new permit
    #' @param business_id Business ID
    #' @param permit_year Permit year
    #' @param fee_amount Fee amount
    #' @param issue_date Issue date (defaults to today)
    #' @param expiry_date Expiry date (defaults to end of permit year)
    create_permit = function(business_id, permit_year, fee_amount, issue_date = Sys.Date(), expiry_date = NULL) {
      if (is.null(expiry_date)) {
        expiry_date <- as.Date(paste0(permit_year, "-12-31"))
      }

      permit_data <- data.frame(
        business_id = business_id,
        permit_year = permit_year,
        fee_amount = fee_amount,
        status = "issued",
        issue_date = issue_date,
        expiry_date = expiry_date,
        stringsAsFactors = FALSE
      )

      self$insert_record("permits", permit_data)
    },

    #' Get permits by business
    #' @param business_id Business ID
    #' @return Data frame of permits
    get_permits_by_business = function(business_id) {
      self$get_table("permits") %>%
        dplyr::filter(business_id == !!business_id) %>%
        dplyr::arrange(dplyr::desc(permit_year)) %>%
        dplyr::collect()
    },

    #' Get expiring permits
    #' @param days_ahead Number of days ahead to check (default 30)
    #' @return Data frame of expiring permits
    get_expiring_permits = function(days_ahead = 30) {
      DBI::dbGetQuery(
        self$pool,
        "SELECT p.*, b.name as business_name, b.kra_pin
         FROM permits p
         JOIN businesses b ON p.business_id = b.business_id
         WHERE p.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '1 day' * $1
         AND p.status = 'issued'
         ORDER BY p.expiry_date",
        params = list(days_ahead)
      )
    },

    #' Calculate permit fee based on business size and category
    #' @param business_size Business size (Small, Medium, Large)
    #' @param business_category Business category
    #' @return Numeric fee amount
    calculate_permit_fee = function(business_size, business_category) {
      # Simple fee calculation logic
      base_fees <- list(
        "Small" = list("Retail" = 5000, "Services" = 7500, "default" = 10000),
        "Medium" = list("Retail" = 15000, "Services" = 20000, "default" = 25000),
        "Large" = list("Manufacturing" = 100000, "default" = 50000)
      )

      size_fees <- base_fees[[business_size]]
      if (is.null(size_fees)) return(5000)

      fee <- size_fees[[business_category]]
      if (is.null(fee)) fee <- size_fees[["default"]]

      return(fee)
    },

    #' Update permit status
    #' @param permit_id Permit ID
    #' @param status New status
    #' @param penalty_amount Penalty amount (default 0)
    update_permit_status = function(permit_id, status, penalty_amount = 0) {
      self$update_record("permits", permit_id, list(
        status = status,
        penalty_amount = penalty_amount
      ))
    }
  )
)

#' Payment Operations Class
#'
#' @description R6 class for payment management operations
#' @export
PaymentOperations <- R6::R6Class(
  "PaymentOperations",
  inherit = DBOperations,
  public = list(
    #' Create a new payment
    #' @param permit_id Permit ID
    #' @param amount Payment amount
    #' @param payment_method Payment method (mpesa, cash, bank)
    #' @param mpesa_code M-Pesa transaction code (optional)
    #' @param status Payment status (default pending)
    create_payment = function(permit_id, amount, payment_method, mpesa_code = NULL, status = "pending") {
      payment_data <- data.frame(
        permit_id = permit_id,
        amount = amount,
        payment_method = payment_method,
        mpesa_code = mpesa_code,
        status = status,
        stringsAsFactors = FALSE
      )

      self$insert_record("payments", payment_data)
    },

    #' Get payments by permit
    #' @param permit_id Permit ID
    #' @return Data frame of payments
    get_payments_by_permit = function(permit_id) {
      self$get_table("payments") %>%
        dplyr::filter(permit_id == !!permit_id) %>%
        dplyr::arrange(dplyr::desc(paid_at)) %>%
        dplyr::collect()
    },

    #' Get payment summary
    #' @return Data frame with payment summary
    get_payment_summary = function() {
      DBI::dbGetQuery(
        self$pool,
        "SELECT
          pay.payment_id,
          b.business_id,
          b.name as business_name,
          p.permit_year,
          pay.amount,
          pay.payment_method,
          pay.status as payment_status,
          pay.paid_at,
          p.fee_amount
        FROM payments pay
        JOIN permits p ON pay.permit_id = p.permit_id
        JOIN businesses b ON p.business_id = b.business_id
        ORDER BY pay.paid_at DESC"
      )
    },

    #' Update payment status
    #' @param payment_id Payment ID
    #' @param status New payment status
    #' @param receipt_url Receipt URL (optional)
    update_payment_status = function(payment_id, status, receipt_url = NULL) {
      update_data <- list(status = status)
      if (!is.null(receipt_url)) {
        update_data$receipt_url <- receipt_url
      }

      self$update_record("payments", payment_id, update_data)
    },

    #' Get payment statistics
    #' @param start_date Start date for filtering (optional)
    #' @param end_date End date for filtering (optional)
    #' @return Data frame with payment statistics
    get_payment_statistics = function(start_date = NULL, end_date = NULL) {
      if (is.null(start_date) && is.null(end_date)) {
        # Query without parameters
        DBI::dbGetQuery(
          self$pool,
          "SELECT
            COUNT(*) as total_payments,
            COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_payments,
            COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_payments,
            COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_payments,
            COALESCE(SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END), 0) as total_amount_collected,
            COUNT(CASE WHEN payment_method = 'mpesa' THEN 1 END) as mpesa_payments,
            COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) as cash_payments,
            COUNT(CASE WHEN payment_method = 'bank' THEN 1 END) as bank_payments
          FROM payments"
        )
      } else {
        # Query with parameters
        DBI::dbGetQuery(
          self$pool,
          "SELECT
            COUNT(*) as total_payments,
            COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_payments,
            COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_payments,
            COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_payments,
            COALESCE(SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END), 0) as total_amount_collected,
            COUNT(CASE WHEN payment_method = 'mpesa' THEN 1 END) as mpesa_payments,
            COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) as cash_payments,
            COUNT(CASE WHEN payment_method = 'bank' THEN 1 END) as bank_payments
          FROM payments
          WHERE paid_at BETWEEN $1 AND $2",
          params = list(start_date, end_date)
        )
      }
    }
  )
)

#' Inspection Operations Class
#'
#' @description R6 class for inspection management operations
#' @export
InspectionOperations <- R6::R6Class(
  "InspectionOperations",
  inherit = DBOperations,
  public = list(
    #' Create a new inspection
    #' @param business_id Business ID
    #' @param inspector_id Inspector user ID
    #' @param notes Inspection notes (optional)
    #' @param status Inspection status
    #' @param photo_url Photo URL (optional)
    #' @param latitude GPS latitude (optional)
    #' @param longitude GPS longitude (optional)
    create_inspection = function(business_id, inspector_id, notes = NULL, status, photo_url = NULL, latitude = NULL, longitude = NULL) {
      inspection_data <- data.frame(
        business_id = business_id,
        inspector_id = inspector_id,
        notes = notes,
        status = status,
        photo_url = photo_url,
        latitude = latitude,
        longitude = longitude,
        stringsAsFactors = FALSE
      )

      self$insert_record("inspections", inspection_data)
    },

    #' Get inspections by business
    #' @param business_id Business ID
    #' @return Data frame of inspections
    get_inspections_by_business = function(business_id) {
      DBI::dbGetQuery(
        self$pool,
        "SELECT i.*, u.name as inspector_name
         FROM inspections i
         JOIN users u ON i.inspector_id = u.user_id
         WHERE i.business_id = $1
         ORDER BY i.inspected_at DESC",
        params = list(business_id)
      )
    },

    #' Get inspections by inspector
    #' @param inspector_id Inspector user ID
    #' @param start_date Start date filter (optional)
    #' @param end_date End date filter (optional)
    #' @return Data frame of inspections
    get_inspections_by_inspector = function(inspector_id, start_date = NULL, end_date = NULL) {
      if (is.null(start_date) && is.null(end_date)) {
        DBI::dbGetQuery(
          self$pool,
          "SELECT i.*, b.name as business_name, u.name as inspector_name
           FROM inspections i
           JOIN businesses b ON i.business_id = b.business_id
           JOIN users u ON i.inspector_id = u.user_id
           WHERE i.inspector_id = $1
           ORDER BY i.inspected_at DESC",
          params = list(inspector_id)
        )
      } else {
        DBI::dbGetQuery(
          self$pool,
          "SELECT i.*, b.name as business_name, u.name as inspector_name
           FROM inspections i
           JOIN businesses b ON i.business_id = b.business_id
           JOIN users u ON i.inspector_id = u.user_id
           WHERE i.inspector_id = $1 AND i.inspected_at BETWEEN $2 AND $3
           ORDER BY i.inspected_at DESC",
          params = list(inspector_id, start_date, end_date)
        )
      }
    },

    #' Get inspection statistics
    #' @return Data frame with inspection statistics
    get_inspection_statistics = function() {
      DBI::dbGetQuery(
        self$pool,
        "SELECT
          COUNT(*) as total_inspections,
          COUNT(CASE WHEN status = 'visited' THEN 1 END) as visited,
          COUNT(CASE WHEN status = 'not_found' THEN 1 END) as not_found,
          COUNT(CASE WHEN status = 'noncompliant' THEN 1 END) as noncompliant,
          COUNT(DISTINCT inspector_id) as active_inspectors
        FROM inspections"
      )
    }
  )
)

#' Compliance Operations Class
#'
#' @description R6 class for compliance scoring operations
#' @export
ComplianceOperations <- R6::R6Class(
  "ComplianceOperations",
  inherit = DBOperations,
  public = list(
    #' Update compliance score for a business
    #' @param business_id Business ID
    #' @param score Compliance score (0-1)
    #' @param model_version Model version string
    #' @param features_json Features used in scoring (optional)
    #' @param cluster_label Risk cluster label (optional)
    update_compliance_score = function(business_id, score, model_version, features_json = NULL, cluster_label = NULL) {
      # Check if compliance score exists
      existing <- DBI::dbGetQuery(
        self$pool,
        "SELECT score_id FROM compliance_scores WHERE business_id = $1",
        params = list(business_id)
      )

      if (nrow(existing) > 0) {
        # Update existing
        self$update_record("compliance_scores", existing$score_id[1], list(
          score = score,
          model_version = model_version,
          features_json = if (is.null(features_json)) NULL else jsonlite::toJSON(features_json),
          cluster_label = cluster_label,
          scored_at = Sys.time()
        ), "score_id")
      } else {
        # Insert new
        compliance_data <- data.frame(
          business_id = business_id,
          score = score,
          model_version = model_version,
          features_json = if (is.null(features_json)) NA else jsonlite::toJSON(features_json),
          cluster_label = cluster_label,
          stringsAsFactors = FALSE
        )
        self$insert_record("compliance_scores", compliance_data)
      }
    },

    #' Get compliance scores with filtering
    #' @param min_score Minimum score filter (optional)
    #' @param max_score Maximum score filter (optional)
    #' @param cluster_label Cluster label filter (optional)
    #' @return Data frame of compliance scores
    get_compliance_scores = function(min_score = NULL, max_score = NULL, cluster_label = NULL) {
      sql <- "SELECT cs.*, b.name as business_name, b.kra_pin, b.category, b.size
              FROM compliance_scores cs
              JOIN businesses b ON cs.business_id = b.business_id
              WHERE 1=1"
      params <- list()
      param_count <- 0

      if (!is.null(min_score)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND cs.score >= $", param_count, sep = "")
        params <- append(params, min_score)
      }

      if (!is.null(max_score)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND cs.score <= $", param_count, sep = "")
        params <- append(params, max_score)
      }

      if (!is.null(cluster_label)) {
        param_count <- param_count + 1
        sql <- paste(sql, "AND cs.cluster_label = $", param_count, sep = "")
        params <- append(params, cluster_label)
      }

      sql <- paste(sql, "ORDER BY cs.score DESC")

      DBI::dbGetQuery(self$pool, sql, params = params)
    },

    #' Get high-risk businesses
    #' @param threshold Risk threshold (default 0.3)
    #' @return Data frame of high-risk businesses
    get_high_risk_businesses = function(threshold = 0.3) {
      DBI::dbGetQuery(
        self$pool,
        "SELECT cs.*, b.name as business_name, b.kra_pin, b.location, b.ward
         FROM compliance_scores cs
         JOIN businesses b ON cs.business_id = b.business_id
         WHERE cs.score <= $1
         ORDER BY cs.score ASC",
        params = list(threshold)
      )
    }
  )
)
