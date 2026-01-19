# Shared Invite Management Targets
# Usage: Include this file in your project Makefile
#
# Required variables (set before include):
#   COMPOSE_DEV - Docker compose command with dev override
#   REDIS_SERVICE - Redis service name
#   BASE_URL - Base URL for invite links
#
# Optional variables:
#   EXPIRES - Invite expiration (default: 24h)
#   LABEL - Invite label (default: Demo)
#   MAX_USES - Max uses per invite (default: 1)
#
# Example:
#   COMPOSE_DEV := docker compose -p jira-demo -f docker-compose.yml -f docker-compose.dev.yml
#   REDIS_SERVICE := redis
#   BASE_URL := http://localhost:8080
#   include ../demo-platform-shared/makefile-includes/invites.mk

# Default values
EXPIRES ?= 24h
LABEL ?= Demo
MAX_USES ?= 1

# Invite management targets
.PHONY: invite invite-local invite-list invite-revoke invite-cleanup

## Generate production invite
invite:
	@echo "Generating invite..."
	@TOKEN=$$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32); \
	EXPIRES_AT=$$(date -v+$(EXPIRES) -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -d "+$(EXPIRES)" -u +"%Y-%m-%dT%H:%M:%SZ"); \
	echo "Token: $$TOKEN"; \
	echo "Expires: $$EXPIRES_AT"; \
	$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli SET "invite:$$TOKEN" \
		"{\"token\":\"$$TOKEN\",\"createdAt\":\"$$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"expiresAt\":\"$$EXPIRES_AT\",\"maxUses\":$(MAX_USES),\"useCount\":0,\"status\":\"active\",\"label\":\"$(LABEL)\"}" \
		EX 604800; \
	echo ""; \
	echo "Invite URL: $(BASE_URL)/?invite=$$TOKEN"

## Generate local development invite
invite-local: BASE_URL := http://localhost:8080
invite-local: invite

## List all active invites
invite-list:
	@echo "Active invites:"
	@$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli KEYS "invite:*" | while read key; do \
		if [ -n "$$key" ]; then \
			data=$$($(COMPOSE_DEV) exec -T $(REDIS_SERVICE) redis-cli GET "$$key"); \
			token=$$(echo "$$data" | jq -r '.token // empty' 2>/dev/null); \
			status=$$(echo "$$data" | jq -r '.status // "unknown"' 2>/dev/null); \
			expires=$$(echo "$$data" | jq -r '.expiresAt // "unknown"' 2>/dev/null); \
			label=$$(echo "$$data" | jq -r '.label // "none"' 2>/dev/null); \
			uses=$$(echo "$$data" | jq -r '.useCount // 0' 2>/dev/null); \
			max=$$(echo "$$data" | jq -r '.maxUses // 1' 2>/dev/null); \
			if [ -n "$$token" ]; then \
				echo "  $$token - Status: $$status, Uses: $$uses/$$max, Expires: $$expires, Label: $$label"; \
			fi; \
		fi; \
	done

## Revoke an invite (TOKEN=xxx)
invite-revoke:
ifndef TOKEN
	$(error TOKEN is required. Usage: make invite-revoke TOKEN=xxx)
endif
	@echo "Revoking invite: $(TOKEN)"
	@data=$$($(COMPOSE_DEV) exec -T $(REDIS_SERVICE) redis-cli GET "invite:$(TOKEN)"); \
	if [ -z "$$data" ] || [ "$$data" = "nil" ]; then \
		echo "Invite not found"; \
		exit 1; \
	fi; \
	updated=$$(echo "$$data" | jq '.status = "revoked"'); \
	$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli SET "invite:$(TOKEN)" "$$updated"; \
	echo "Invite revoked"

## Cleanup expired invites
invite-cleanup:
	@echo "Cleaning up expired invites..."
	@count=0; \
	$(COMPOSE_DEV) exec $(REDIS_SERVICE) redis-cli KEYS "invite:*" | while read key; do \
		if [ -n "$$key" ]; then \
			data=$$($(COMPOSE_DEV) exec -T $(REDIS_SERVICE) redis-cli GET "$$key"); \
			expires=$$(echo "$$data" | jq -r '.expiresAt // empty' 2>/dev/null); \
			if [ -n "$$expires" ]; then \
				expires_ts=$$(date -d "$$expires" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$$expires" +%s 2>/dev/null); \
				now_ts=$$(date +%s); \
				if [ "$$expires_ts" -lt "$$now_ts" ]; then \
					$(COMPOSE_DEV) exec -T $(REDIS_SERVICE) redis-cli DEL "$$key" > /dev/null; \
					count=$$((count + 1)); \
				fi; \
			fi; \
		fi; \
	done; \
	echo "Cleaned up $$count expired invites"
