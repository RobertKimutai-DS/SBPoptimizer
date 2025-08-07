# SBPoptimizer Makefile

.PHONY: help dev prod test clean backup restore install check

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install R package dependencies
	Rscript -e "if (!require('devtools')) install.packages('devtools'); devtools::install_deps(dependencies = TRUE)"

dev: ## Start development environment
	docker-compose up -d postgres_dev adminer
	@echo "Development environment started"
	@echo "PostgreSQL: localhost:5432"
	@echo "Adminer: http://localhost:8080"
	@echo "Run 'make init-db' to set up the database"

prod: ## Start production environment
	docker-compose up -d postgres_prod
	@echo "Production environment started"
	@echo "PostgreSQL: localhost:5433"

init-db: ## Initialize database schema
	Rscript dev/run_db_setup.R

reset-db: ## Reset database (WARNING: deletes all data)
	@read -p "Are you sure you want to reset the database? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		Rscript dev/reset_database.R; \
	fi

backup: ## Create database backup
	@echo "Creating database backup..."
	Rscript dev/create_backup.R

test: ## Run tests
	Rscript -e "devtools::test()"

check: ## Check package
	Rscript -e "devtools::check(args = '--no-manual')"

clean: ## Stop and remove all containers
	docker-compose down
	docker system prune -f

run: ## Run the Shiny application
	Rscript -e "devtools::load_all(); SBPoptimizer::run_app()"

logs: ## Show database logs
	docker-compose logs -f postgres_dev

status: ## Check service status
	docker-compose ps
