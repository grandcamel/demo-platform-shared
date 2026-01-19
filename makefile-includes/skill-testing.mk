# Shared Skill Testing Targets
# Usage: Include this file in your project Makefile
#
# Required variables (set before include):
#   DEMO_CONTAINER_IMAGE - Docker image for demo container
#   TELEMETRY_NETWORK - Docker network for telemetry
#   SCENARIOS_DIR - Path to scenarios directory
#
# Optional variables:
#   SCENARIO - Scenario name (default: page)
#   PROMPT_INDEX - Prompt index for single prompt test (default: all)
#   MAX_ITERATIONS - Max refinement iterations (default: 3)
#   VERBOSE - Enable verbose output (default: false)
#
# Example:
#   DEMO_CONTAINER_IMAGE := jira-demo-container:latest
#   TELEMETRY_NETWORK := jira-demo-telemetry-network
#   SCENARIOS_DIR := demo-container/scenarios
#   include ../demo-platform-shared/makefile-includes/skill-testing.mk

# Default values
SCENARIO ?= page
PROMPT_INDEX ?=
MAX_ITERATIONS ?= 3
VERBOSE ?= false

# Skill testing targets
.PHONY: test-skill test-skill-mock test-skill-dev refine-skill list-scenarios

## Run skill test with live API
test-skill:
	@echo "Running skill test for scenario: $(SCENARIO)"
	$(call skill_test_run,)

## Run skill test with mock API (fast, no API calls)
test-skill-mock:
	@echo "Running mock skill test for scenario: $(SCENARIO)"
	$(call skill_test_run,MOCK_MODE=true)

## Run skill test for development (single prompt, fast iteration)
test-skill-dev:
	@echo "Running dev skill test for scenario: $(SCENARIO), prompt: $(PROMPT_INDEX)"
	$(call skill_test_run_dev)

## Run skill refinement loop (iterative fix until passing)
refine-skill:
	@echo "Running skill refinement for scenario: $(SCENARIO)"
	$(call skill_refine_run)

## List available scenarios
list-scenarios:
	@echo "Available scenarios:"
	@ls -1 $(SCENARIOS_DIR)/*.prompts 2>/dev/null | xargs -I{} basename {} .prompts | sort

# Internal macros
define skill_test_run
	docker run --rm \
		--network $(TELEMETRY_NETWORK) \
		-e SCENARIO=$(SCENARIO) \
		$(if $(1),-e $(1)) \
		$(if $(filter true,$(VERBOSE)),-e VERBOSE=true) \
		$(DEMO_CONTAINER_IMAGE)
endef

define skill_test_run_dev
	docker run --rm \
		--network $(TELEMETRY_NETWORK) \
		-e SCENARIO=$(SCENARIO) \
		$(if $(PROMPT_INDEX),-e PROMPT_INDEX=$(PROMPT_INDEX)) \
		-e DEV_MODE=true \
		$(if $(filter true,$(VERBOSE)),-e VERBOSE=true) \
		$(DEMO_CONTAINER_IMAGE)
endef

define skill_refine_run
	@iteration=1; \
	while [ $$iteration -le $(MAX_ITERATIONS) ]; do \
		echo "Refinement iteration $$iteration/$(MAX_ITERATIONS)"; \
		if $(MAKE) test-skill SCENARIO=$(SCENARIO); then \
			echo "Skill test passed!"; \
			exit 0; \
		fi; \
		echo "Test failed, refining..."; \
		iteration=$$((iteration + 1)); \
	done; \
	echo "Max iterations reached without passing"; \
	exit 1
endef
