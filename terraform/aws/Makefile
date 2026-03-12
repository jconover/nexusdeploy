# Terraform wrapper Makefile — AWS
# Usage: make <target> ENV=<dev|staging|prod>
#
# Examples:
#   make init    ENV=dev
#   make plan    ENV=dev
#   make apply   ENV=staging
#   make destroy ENV=dev CONFIRM=yes

ENV         ?=
ENV_DIR     := environments/$(ENV)
BACKEND_CFG := $(ENV_DIR)/backend.hcl
TFVARS      := $(ENV_DIR)/terraform.tfvars
TF_PLAN     := .plans/$(ENV).tfplan

.DEFAULT_GOAL := help

# Guard: require ENV to be set for targets that need it
check-env:
ifndef ENV
	$(error ENV is not set. Usage: make <target> ENV=<dev|staging|prod>)
endif

##@ Setup

.PHONY: init
init: check-env ## Initialise Terraform for ENV
	@echo "==> Initialising $(ENV) environment"
	mkdir -p .plans
	terraform init \
		-backend-config=$(BACKEND_CFG) \
		-reconfigure

##@ Core

.PHONY: plan
plan: check-env ## Generate and save execution plan for ENV
	@echo "==> Planning $(ENV) environment"
	terraform plan \
		-var-file=$(TFVARS) \
		-out=$(TF_PLAN)

.PHONY: apply
apply: check-env ## Apply the saved plan for ENV (runs plan first if no saved plan)
	@echo "==> Applying $(ENV) environment"
	@if [ ! -f $(TF_PLAN) ]; then $(MAKE) plan ENV=$(ENV); fi
	terraform apply $(TF_PLAN)
	@rm -f $(TF_PLAN)

.PHONY: destroy
destroy: check-env ## Destroy all resources for ENV (requires CONFIRM=yes)
	@[ "$(CONFIRM)" = "yes" ] || { echo "Set CONFIRM=yes to destroy $(ENV)"; exit 1; }
	@echo "==> Destroying $(ENV) environment"
	terraform destroy -var-file=$(TFVARS) -auto-approve

##@ Quality

.PHONY: fmt
fmt: ## Format all Terraform files
	terraform fmt -recursive modules/ environments/

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files (CI-safe)
	terraform fmt -recursive -check modules/ environments/

.PHONY: validate
validate: check-env ## Validate Terraform configuration (requires init first)
	terraform validate

.PHONY: lint
lint: fmt-check validate ## Run all linting checks

##@ Utilities

.PHONY: output
output: check-env ## Show all outputs for ENV
	terraform output

.PHONY: clean
clean: ## Remove .terraform directories and cached plans
	find . -type d -name '.terraform' -exec rm -rf {} + 2>/dev/null; rm -rf .plans; true

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m ENV=<dev|staging|prod>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
