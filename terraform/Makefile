# Terraform wrapper Makefile
# Usage: make <target> ENV=<dev|staging|prod>
#
# Examples:
#   make init    ENV=dev
#   make plan    ENV=dev
#   make apply   ENV=staging
#   make destroy ENV=dev

ENV         ?= dev
ENV_DIR     := environments/$(ENV)
BACKEND_CFG := $(ENV_DIR)/backend.hcl
TFVARS      := $(ENV_DIR)/terraform.tfvars
TF_PLAN     := .plans/$(ENV).tfplan

.DEFAULT_GOAL := help

##@ Setup

.PHONY: init
init: ## Initialise Terraform for ENV
	@echo "==> Initialising $(ENV) environment"
	mkdir -p .plans
	terraform init \
		-backend-config=$(BACKEND_CFG) \
		-reconfigure

##@ Core

.PHONY: plan
plan: ## Generate and save execution plan for ENV
	@echo "==> Planning $(ENV) environment"
	terraform plan \
		-var-file=$(TFVARS) \
		-out=$(TF_PLAN)

.PHONY: apply
apply: ## Apply the saved plan for ENV (runs plan first if no saved plan)
	@echo "==> Applying $(ENV) environment"
	@if [ ! -f $(TF_PLAN) ]; then $(MAKE) plan ENV=$(ENV); fi
	terraform apply $(TF_PLAN)
	@rm -f $(TF_PLAN)

.PHONY: destroy
destroy: ## Destroy all resources for ENV (requires CONFIRM=yes)
	@[ "$(CONFIRM)" = "yes" ] || { echo "Set CONFIRM=yes to destroy $(ENV)"; exit 1; }
	@echo "==> Destroying $(ENV) environment"
	terraform destroy -var-file=$(TFVARS) -auto-approve

##@ Quality

.PHONY: fmt
fmt: ## Format all Terraform files
	terraform fmt -recursive

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files (CI-safe)
	terraform fmt -recursive -check

.PHONY: validate
validate: ## Validate Terraform configuration
	terraform validate

.PHONY: lint
lint: fmt-check validate ## Run all linting checks

##@ Documentation

.PHONY: docs
docs: ## Generate module documentation with terraform-docs
	@which terraform-docs >/dev/null 2>&1 || { echo "Install terraform-docs: https://terraform-docs.io"; exit 1; }
	terraform-docs markdown table --output-file README.md --output-mode inject .
	@for mod in modules/*/; do \
		terraform-docs markdown table --output-file README.md --output-mode inject $$mod; \
	done

##@ Utilities

.PHONY: clean
clean: ## Remove cached plans and .terraform directories
	rm -rf .plans .terraform terraform.tfstate.d

.PHONY: show
show: ## Show current state for ENV
	terraform show

.PHONY: output
output: ## Show all outputs for ENV
	terraform output

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m ENV=<dev|staging|prod>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
