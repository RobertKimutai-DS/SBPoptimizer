#' Database Connection Utilities
#'
#' This module contains utilities for database connections and operations
#'
#' @name db_utils
NULL

#' Database Connection Utilities
#'
#' This module contains utilities for database connections and operations
#'
#' @name db_utils
NULL

#' Get Database Configuration
#'
#' @param config_name Configuration environment name
#' @return List with database configuration
#' @export
#' @importFrom config get
get_db_config <- function(config_name = Sys.getenv("GOLEM_CONFIG_ACTIVE", "default")) {
  config::get("db", config = config_name, file = app_sys("golem-config.yml"))
}

#' Create Database Connection Pool
#'
#' @param config_name Configuration environment name
#' @return Database connection pool object
#' @export
#' @importFrom pool dbPool
#' @importFrom RPostgres Postgres
create_db_pool <- function(config_name = Sys.getenv("GOLEM_CONFIG_ACTIVE", "default")) {
  db_config <- get_db_config(config_name)

  pool::dbPool(
    drv = RPostgres::Postgres(),
    host = db_config$host,
    port = db_config$port,
    dbname = db_config$dbname,
    user = db_config$user,
    password = db_config$password,
    minSize = 1,
    maxSize = db_config$pool_size %||% 5,
    idleTimeout = db_config$pool_timeout %||% 60
  )
}

#' Initialize Database Connection
#'
#' @param config_name Configuration environment name
#' @return Database connection pool
#' @export
#' @importFrom DBI dbGetQuery
#' @importFrom pool poolCheckout poolReturn
initialize_db <- function(config_name = Sys.getenv("GOLEM_CONFIG_ACTIVE", "default")) {
  tryCatch({
    pool <- create_db_pool(config_name)

    # Test connection
    conn <- pool::poolCheckout(pool)
    DBI::dbGetQuery(conn, "SELECT 1 as test")
    pool::poolReturn(conn)

    message("Database connection initialized successfully")
    return(pool)
  }, error = function(e) {
    stop(paste("Failed to initialize database connection:", e$message))
  })
}

#' Parse SQL statements respecting dollar-quoted strings
#'
#' @param sql_content Full SQL content as string
#' @return Vector of SQL statements
#' @keywords internal
parse_sql_statements <- function(sql_content) {
  # Remove comments
  sql_content <- gsub("--[^\r\n]*", "", sql_content)

  # Split by semicolon, but be careful with dollar-quoted strings
  statements <- list()
  current_statement <- ""
  in_dollar_quote <- FALSE
  dollar_tag <- ""

  lines <- strsplit(sql_content, "\n")[[1]]

  for (line in lines) {
    line <- trimws(line)
    if (nchar(line) == 0) next

    # Check for dollar-quoted string start/end
    if (grepl("\\$[^$]*\\$", line)) {
      if (!in_dollar_quote) {
        # Starting dollar quote
        dollar_match <- regmatches(line, regexpr("\\$[^$]*\\$", line))
        dollar_tag <- dollar_match[1]
        in_dollar_quote <- TRUE
      } else if (grepl(paste0("\\", dollar_tag), line, fixed = TRUE)) {
        # Ending dollar quote
        in_dollar_quote <- FALSE
        dollar_tag <- ""
      }
    }

    current_statement <- paste(current_statement, line, sep = "\n")

    # If we hit a semicolon and we're not in a dollar-quoted block
    if (grepl(";\\s*$", line) && !in_dollar_quote) {
      statements <- append(statements, current_statement)
      current_statement <- ""
    }
  }

  # Add any remaining statement
  if (nchar(trimws(current_statement)) > 0) {
    statements <- append(statements, current_statement)
  }

  return(statements)
}

#' Execute SQL File with Better Parsing
#'
#' @param pool Database connection pool
#' @param sql_file Path to SQL file
#' @export
#' @importFrom readr read_file
#' @importFrom DBI dbExecute
execute_sql_file <- function(pool, sql_file) {
  if (!file.exists(sql_file)) {
    stop(paste("SQL file not found:", sql_file))
  }

  sql_content <- readr::read_file(sql_file)

  # Better parsing for PostgreSQL functions with $ delimiters
  # Split on semicolons but respect $ quoted blocks
  statements <- parse_sql_statements(sql_content)

  for (stmt in statements) {
    stmt <- trimws(stmt)
    if (nzchar(stmt) && !grepl("^\\s*--", stmt)) {
      tryCatch({
        DBI::dbExecute(pool, stmt)
      }, error = function(e) {
        warning(paste("Error executing statement:", e$message))
        warning(paste("Statement:", substr(stmt, 1, 100), "..."))
      })
    }
  }
}

#' Run Database Migrations
#'
#' @param pool Database connection pool
#' @export
run_migrations <- function(pool) {
  sql_dir <- app_sys("sql")
  if (!dir.exists(sql_dir)) {
    stop("SQL directory not found. Expected: ", sql_dir)
  }

  sql_files <- list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE)
  sql_files <- sort(sql_files)  # Execute in order

  if (length(sql_files) == 0) {
    warning("No SQL files found in: ", sql_dir)
    return()
  }

  for (sql_file in sql_files) {
    message(paste("Executing:", basename(sql_file)))
    execute_sql_file(pool, sql_file)
  }

  message("Database migrations completed successfully")
}

#' Check Database Health
#'
#' @param pool Database connection pool
#' @return List with health check results
#' @export
#' @importFrom DBI dbGetQuery
check_db_health <- function(pool) {
  tryCatch({
    # Test basic connection
    result <- DBI::dbGetQuery(pool, "SELECT 1 as test")

    # Get table counts
    user_count <- DBI::dbGetQuery(pool, "SELECT COUNT(*) as count FROM users")$count
    business_count <- DBI::dbGetQuery(pool, "SELECT COUNT(*) as count FROM businesses")$count
    permit_count <- DBI::dbGetQuery(pool, "SELECT COUNT(*) as count FROM permits")$count

    list(
      status = "healthy",
      connection_test = TRUE,
      table_counts = list(
        users = user_count,
        businesses = business_count,
        permits = permit_count
      ),
      check_time = Sys.time()
    )
  }, error = function(e) {
    list(
      status = "unhealthy",
      error = e$message,
      check_time = Sys.time()
    )
  })
}

#' Create Database Backup
#'
#' @param pool Database connection pool (not used, but kept for consistency)
#' @param backup_dir Directory to store backups
#' @param config_name Configuration name to get database details
#' @return Path to backup file or NULL if failed
#' @export
create_database_backup <- function(pool = NULL, backup_dir = "backups", config_name = "default") {
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE)
  }

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_file <- file.path(backup_dir, paste0("sbp_backup_", timestamp, ".sql"))

  # Get database configuration
  db_config <- get_db_config(config_name)

  # Create pg_dump command
  cmd <- sprintf(
    'PGPASSWORD="%s" pg_dump -h %s -p %s -U %s -d %s > "%s"',
    db_config$password,
    db_config$host,
    db_config$port,
    db_config$user,
    db_config$dbname,
    backup_file
  )

  tryCatch({
    result <- system(cmd, intern = FALSE)
    if (result == 0 && file.exists(backup_file) && file.size(backup_file) > 0) {
      message(paste("Backup created:", backup_file))
      return(backup_file)
    } else {
      return(NULL)
    }
  }, error = function(e) {
    message(paste("Backup failed:", e$message))
    return(NULL)
  })
}

#' Restore Database from Backup
#'
#' @param pool Database connection pool (not used, but kept for consistency)
#' @param backup_file Path to backup file
#' @param config_name Configuration name to get database details
#' @return TRUE if successful, FALSE otherwise
#' @export
restore_database_backup <- function(pool = NULL, backup_file, config_name = "default") {
  if (!file.exists(backup_file)) {
    stop("Backup file does not exist")
  }

  db_config <- get_db_config(config_name)

  # Create psql command
  cmd <- sprintf(
    'PGPASSWORD="%s" psql -h %s -p %s -U %s -d %s < "%s"',
    db_config$password,
    db_config$host,
    db_config$port,
    db_config$user,
    db_config$dbname,
    backup_file
  )

  tryCatch({
    result <- system(cmd, intern = FALSE)
    return(result == 0)
  }, error = function(e) {
    message(paste("Restore failed:", e$message))
    return(FALSE)
  })
}
