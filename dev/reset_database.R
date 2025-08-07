# dev/reset_database.R
#!/usr/bin/env Rscript
#' Reset Database Script
#'
#' WARNING: This will delete all data!

cat("=== DATABASE RESET WARNING ===\n")
cat("This will completely delete all data in the database!\n")
cat("Are you sure you want to continue? (yes/no): ")

# In non-interactive mode, skip the prompt
if (interactive()) {
  response <- readline()
  if (tolower(response) != "yes") {
    cat("Database reset cancelled.\n")
    quit(status = 0)
  }
}

cat("Resetting database...\n")

# Stop and remove containers
cat("Stopping Docker containers...\n")
system("docker-compose down", ignore.stdout = TRUE)

# Remove volumes (this deletes all data)
cat("Removing database volumes...\n")
system("docker volume rm sbpoptimizer_postgres_dev_data 2>/dev/null", ignore.stdout = TRUE)
system("docker volume rm sbpoptimizer_postgres_prod_data 2>/dev/null", ignore.stdout = TRUE)

# Restart containers
cat("Restarting PostgreSQL container...\n")
system("docker-compose up -d postgres_dev", ignore.stdout = TRUE)

# Wait for database to be ready
cat("Waiting for database to initialize...")
for (i in 1:30) {
  cat(".")
  Sys.sleep(2)

  # Test connection
  test_result <- tryCatch({
    if (!require("devtools", quietly = TRUE)) {
      stop("devtools package required")
    }
    devtools::load_all()
    pool <- create_db_pool("default")
    result <- DBI::dbGetQuery(pool, "SELECT 1")
    pool::poolClose(pool)
    TRUE
  }, error = function(e) FALSE)

  if (test_result) break
}

if (!test_result) {
  cat("\nFailed to connect to database after 60 seconds\n")
  quit(status = 1)
}

cat("\nDatabase connection re-established!\n")

# Reinitialize database
cat("Re-initializing database schema...\n")

# Load the package
devtools::load_all()

# Initialize database connection
db_pool <- initialize_db("default")

# Run migrations
run_migrations(db_pool)

# Verify setup
health <- check_db_health(db_pool)

if (health$status == "healthy") {
  cat("✓ Database reset and setup completed successfully!\n")
  cat("Database Statistics:\n")
  cat("  - Users:", health$table_counts$users, "\n")
  cat("  - Businesses:", health$table_counts$businesses, "\n")
  cat("  - Permits:", health$table_counts$permits, "\n")
} else {
  cat("✗ Database setup verification failed:\n")
  cat("  Error:", health$error, "\n")
}

# Close connection
pool::poolClose(db_pool)

cat("\nDatabase has been reset and re-initialized!\n")

# dev/create_backup.R
#!/usr/bin/env Rscript
#' Create Database Backup Script

library(lubridate)

cat("Creating database backup...\n")

# Create backup directory if it doesn't exist
backup_dir <- "backups"
if (!dir.exists(backup_dir)) {
  dir.create(backup_dir, recursive = TRUE)
}

# Generate backup filename with timestamp
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
backup_file <- file.path(backup_dir, paste0("sbp_backup_", timestamp, ".sql"))

# Database configuration (development by default)
db_config <- list(
  host = "localhost",
  port = 5432,
  user = "sbp_user",
  password = "sbp_password_dev",
  dbname = "sbpoptimizer_dev"
)

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

cat("Executing backup command...\n")

# Execute backup
result <- system(cmd, intern = FALSE)

if (result == 0 && file.exists(backup_file) && file.size(backup_file) > 0) {
  file_size <- round(file.size(backup_file) / 1024 / 1024, 2)
  cat("✓ Backup created successfully!\n")
  cat("  File:", backup_file, "\n")
  cat("  Size:", file_size, "MB\n")
  cat("  Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
} else {
  cat("✗ Backup failed!\n")
  if (file.exists(backup_file)) {
    unlink(backup_file)  # Remove empty/failed backup file
  }
  quit(status = 1)
}

# dev/restore_backup.R
#!/usr/bin/env Rscript
#' Restore Database Backup Script

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  backup_file <- Sys.getenv("BACKUP_FILE")
  if (backup_file == "") {
    cat("Usage: Rscript dev/restore_backup.R <backup_file>\n")
    cat("   or: BACKUP_FILE=path/to/backup.sql Rscript dev/restore_backup.R\n")
    quit(status = 1)
  }
} else {
  backup_file <- args[1]
}

if (!file.exists(backup_file)) {
  cat("Error: Backup file not found:", backup_file, "\n")
  quit(status = 1)
}

cat("Restoring database from backup:", backup_file, "\n")

# Database configuration
db_config <- list(
  host = "localhost",
  port = 5432,
  user = "sbp_user",
  password = "sbp_password_dev",
  dbname = "sbpoptimizer_dev"
)

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

cat("Executing restore command...\n")

# Execute restore
result <- system(cmd, intern = FALSE)

if (result == 0) {
  cat("✓ Database restored successfully from:", backup_file, "\n")
} else {
  cat("✗ Database restore failed!\n")
  quit(status = 1)
}

# R/run_app.R (Update the existing one)
#' Run the Shiny Application
#'
#' @param ... arguments to pass to golem_opts.
#' See `?golem::get_golem_options` for more details.
#' @inheritParams shiny::shinyApp
#'
#' @export
#' @importFrom shiny shinyApp
#' @importFrom golem with_golem_options
run_app <- function(
    onStart = NULL,
    options = list(),
    enableBookmarking = NULL,
    uiPattern = "/",
    ...
) {
  with_golem_options(
    app = shinyApp(
      ui = app_ui,
      server = app_server,
      onStart = onStart,
      options = options,
      enableBookmarking = enableBookmarking,
      uiPattern = uiPattern
    ),
    golem_opts = list(...)
  )
}

# dev/02_dev.R (Update the existing Golem file)
# Building a Prod-Ready, Robust Shiny Application.
#
# README: each step of the dev files is optional, and you don't have to
# fill every dev scripts before getting started.
# 01_start.R should be filled at start.
# 02_dev.R should be used to keep track of your development during the project.
# 03_deploy.R should be used once you need to deploy your app.

###################################
#### CURRENT FILE: DEV SCRIPT #####
###################################

# Engineering

## Dependencies ----
## Add one line by package you want to add as dependency
usethis::use_package("DBI")
usethis::use_package("RPostgres")
usethis::use_package("pool")
usethis::use_package("config")
usethis::use_package("dplyr")
usethis::use_package("dbplyr")
usethis::use_package("glue")
usethis::use_package("purrr")
usethis::use_package("stringr")
usethis::use_package("lubridate")
usethis::use_package("jsonlite")
usethis::use_package("yaml")
usethis::use_package("DT")
usethis::use_package("shinydashboard")
usethis::use_package("plotly")
usethis::use_package("htmlwidgets")
usethis::use_package("R6")
usethis::use_package("readr")

## Add modules ----
## Create a module infrastructure in R/
golem::add_module(name = "database_admin") # Database administration
golem::add_module(name = "business_management") # Business CRUD operations
golem::add_module(name = "permit_management") # Permit management
golem::add_module(name = "payment_tracking") # Payment processing
golem::add_module(name = "inspection_scheduling") # Inspection management
golem::add_module(name = "compliance_scoring") # Compliance analytics
golem::add_module(name = "reporting_dashboard") # Reports and analytics

## Add helper functions ----
golem::add_utils("db_helpers") # Database helper functions
golem::add_utils("validation_helpers") # Data validation helpers
golem::add_utils("ui_helpers") # UI helper functions

## External resources
## Creates .js and .css files at inst/app/www
golem::add_js_file("script")
golem::add_js_handler("handlers")
golem::add_css_file("custom")

## Add internal datasets ----
## If you have data in your package
usethis::use_data_raw(name = "kenya_counties", open = FALSE)
usethis::use_data_raw(name = "business_categories", open = FALSE)

## Tests ----
## Add one line by test you want to create
usethis::use_test("app")
usethis::use_test("database")
usethis::use_test("business_operations")
usethis::use_test("permit_operations")

# Documentation

## Vignette ----
usethis::use_vignette("SBPoptimizer")
devtools::build_vignettes()

## Code Coverage----
## Set the code coverage service ("codecov" or "coveralls")
usethis::use_coverage()

# Create a summary readme for the repository
usethis::use_readme_md(open = FALSE)

## CI ----
## Use this if you want to set up GitHub Actions
usethis::use_github_actions()

# Dockerfile ----
golem::add_dockerfile_with_renv()

## Docker compose for database
file.create("docker-compose.yml")

# You're now set! ----
# go to dev/03_deploy.R
rstudioapi::navigateToFile("dev/03_deploy.R")

# Additional helper script for development
# dev/dev_helpers.R
#!/usr/bin/env Rscript
#' Development Helper Functions

#' Quick start development environment
dev_start <- function() {
  cat("Starting SBPoptimizer development environment...\n")

  # Load package
  devtools::load_all()

  # Start database
  system("make dev")

  # Wait a moment for DB to be ready
  Sys.sleep(5)

  # Initialize database
  source("dev/run_db_setup.R")

  cat("✓ Development environment ready!\n")
  cat("Run SBPoptimizer::run_app() to start the application\n")
}

#' Quick database reset for development
dev_reset_db <- function() {
  cat("Resetting development database...\n")
  source("dev/reset_database.R")
  cat("✓ Database reset complete!\n")
}

#' Load sample data for testing
load_sample_data <- function() {
  cat("Loading sample data...\n")

  # Load package first
  devtools::load_all()

  # Initialize database connection
  db_pool <- initialize_db("default")

  # Create sample businesses
  business_ops <- BusinessOperations$new(db_pool)
  permit_ops <- PermitOperations$new(db_pool)

  # Sample business data
  sample_businesses <- data.frame(
    owner_id = c(2, 2, 2),
    kra_pin = c("A111111111Z", "A222222222Z", "A333333333Z"),
    name = c("Green Valley Restaurant", "Tech Hub Solutions", "Mama Jane Salon"),
    category = c("Restaurant", "Technology", "Beauty Services"),
    size = c("Small", "Medium", "Small"),
    location = c("Kiambu Road", "Westlands", "Eastleigh"),
    latitude = c(-1.2500, -1.2630, -1.2921),
    longitude = c(36.8000, 36.8063, 36.8219),
    ward = c("Kiambu Ward", "Westlands Ward", "Eastleigh Ward")
  )

  for (i in 1:nrow(sample_businesses)) {
    business_ops$create_business(
      owner_id = sample_businesses$owner_id[i],
      kra_pin = sample_businesses$kra_pin[i],
      name = sample_businesses$name[i],
      category = sample_businesses$category[i],
      size = sample_businesses$size[i],
      location = sample_businesses$location[i],
      latitude = sample_businesses$latitude[i],
      longitude = sample_businesses$longitude[i],
      ward = sample_businesses$ward[i]
    )
  }

  # Get created businesses
  businesses <- business_ops$get_table("businesses") %>%
    filter(kra_pin %in% c("A111111111Z", "A222222222Z", "A333333333Z")) %>%
    collect()

  # Create permits for each business
  for (i in 1:nrow(businesses)) {
    fee <- permit_ops$calculate_permit_fee(
      sample_businesses$size[i],
      sample_businesses$category[i]
    )

    permit_ops$create_permit(
      business_id = businesses$business_id[i],
      permit_year = 2024,
      fee_amount = fee
    )
  }

  pool::poolClose(db_pool)

  cat("✓ Sample data loaded successfully!\n")
  cat("Added", nrow(sample_businesses), "businesses with permits\n")
}

# Export functions if sourced
if (!interactive()) {
  # This script is being sourced, export functions to global environment
  assign("dev_start", dev_start, envir = .GlobalEnv)
  assign("dev_reset_db", dev_reset_db, envir = .GlobalEnv)
  assign("load_sample_data", load_sample_data, envir = .GlobalEnv)
}
