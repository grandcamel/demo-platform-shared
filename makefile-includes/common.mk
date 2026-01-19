# Shared Common Makefile Targets
# Usage: Include this file in your project Makefile
#
# Required variables (set before include):
#   PROJECT_NAME - Project name for compose project
#   COMPOSE_FILE - Path to docker-compose.yml
#
# Optional variables:
#   COMPOSE_DEV_FILE - Path to docker-compose.dev.yml
#   REDIS_SERVICE - Redis service name (default: redis)
#
# Example:
#   PROJECT_NAME := jira-demo
#   COMPOSE_FILE := docker-compose.yml
#   COMPOSE_DEV_FILE := docker-compose.dev.yml
#   include ../demo-platform-shared/makefile-includes/common.mk

# Default values
COMPOSE_DEV_FILE ?= docker-compose.dev.yml
REDIS_SERVICE ?= redis

# Compose command with project name
COMPOSE := docker compose -p $(PROJECT_NAME) -f $(COMPOSE_FILE)
COMPOSE_DEV := docker compose -p $(PROJECT_NAME) -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE)

# Development targets
.PHONY: dev dev-down dev-restart dev-logs status

## Start development environment
dev:
	@echo "Starting $(PROJECT_NAME) development environment..."
	$(COMPOSE_DEV) up -d
	@echo "Development environment started!"
	@echo "Access at http://localhost:8080"

## Stop development environment
dev-down:
	@echo "Stopping $(PROJECT_NAME) development environment..."
	$(COMPOSE_DEV) down
	@echo "Development environment stopped!"

## Restart development environment
dev-restart: dev-down dev

## View development logs
dev-logs:
	$(COMPOSE_DEV) logs -f

## Check service status
status:
	$(COMPOSE_DEV) ps

# Production targets
.PHONY: deploy deploy-down

## Deploy production environment
deploy:
	@echo "Deploying $(PROJECT_NAME)..."
	$(COMPOSE) up -d
	@echo "Deployment complete!"

## Stop production environment
deploy-down:
	@echo "Stopping $(PROJECT_NAME)..."
	$(COMPOSE) down

# Utility targets
.PHONY: logs logs-queue logs-errors health clean

## View all service logs
logs:
	$(COMPOSE_DEV) logs -f

## View queue-manager logs
logs-queue:
	$(COMPOSE_DEV) logs -f queue-manager

## View error logs only
logs-errors:
	$(COMPOSE_DEV) logs -f 2>&1 | grep -i "error\|fail\|exception"

## Health check
health:
	@curl -s http://localhost:3000/health | jq . || echo "Health check failed"

## Clean up containers and volumes
clean:
	@echo "Cleaning up $(PROJECT_NAME)..."
	$(COMPOSE_DEV) down -v --remove-orphans
	@echo "Cleanup complete!"

# Redis utilities
.PHONY: redis-cli redis-flush

## Connect to Redis CLI
redis-cli:
	$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli

## Flush Redis database (use with caution)
redis-flush:
	@echo "WARNING: This will delete all Redis data!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli FLUSHALL

# Linting targets
.PHONY: lint lint-js lint-py lint-fix

## Run all linters
lint: lint-js lint-py

## Run JavaScript linter
lint-js:
	@echo "Running ESLint..."
	cd queue-manager && npm run lint

## Run Python linter
lint-py:
	@echo "Running Ruff..."
	ruff check scripts/ || true

## Auto-fix lint issues
lint-fix:
	cd queue-manager && npm run lint:fix
	ruff check --fix scripts/ || true
