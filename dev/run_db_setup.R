#!/usr/bin/env Rscript
#' Database Setup Script
#'
#' Run this script to set up the database for development

# Load necessary packages
if (!require("devtools")) install.packages("devtools")
devtools::load_all()

cat("Starting database setup for SBPoptimizer...\n")

# Check if Docker is running
docker_status <- system("docker ps", ignore.stdout = TRUE, ignore.stderr = TRUE)
if (docker_status != 0) {
  cat("Docker is not running. Please start Docker first.\n")
  cat("Run: docker-compose up -d postgres_dev\n")
  quit(status = 1)
}

# Start Docker containers if not running
cat("Starting PostgreSQL container...\n")
system("docker-compose up -d postgres_dev", ignore.stdout = TRUE)

# Wait for database to be ready
cat("Waiting for database to be ready...")
for (i in 1:30) {
  cat(".")
  Sys.sleep(2)

  # Test connection
  test_result <- tryCatch({
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

cat("\nDatabase connection established!\n")

# Initialize database connection
cat("Initializing database connection...\n")
db_pool <- initialize_db("default")

# Run migrations
cat("Running database migrations...\n")
run_migrations(db_pool)

# Verify setup
cat("Verifying database setup...\n")
health <- check_db_health(db_pool)

if (health$status == "healthy") {
  cat("✓ Database setup completed successfully!\n")
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

cat("\nDatabase setup complete!\n")
cat("You can now access:\n")
cat("  - PostgreSQL: localhost:5432\n")
cat("  - Adminer: http://localhost:8080\n")
cat("  - Credentials: sbp_user / sbp_password_dev\n")
cat("\nTo start the application, run: devtools::load_all(); run_app()\n")
