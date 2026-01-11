# Makefile for ClinicalDataBridge Infrastructure

.PHONY: help init validate plan apply destroy fmt lint test security-check clean

help:
	@echo "ClinicalDataBridge Infrastructure Management"
	@echo "==========================================="
	@echo ""
	@echo "Usage: make [target] ENV=dev"
	@echo ""
	@echo "Available targets:"
	@echo "  init              - Initialize terraform (required first)"
	@echo "  validate          - Validate terraform configuration"
	@echo "  fmt               - Format terraform files"
	@echo "  lint              - Run tflint for linting"
	@echo "  security-check    - Run tfsec for security vulnerabilities"
	@echo "  plan              - Create execution plan"
	@echo "  apply             - Apply infrastructure changes"
	@echo "  destroy           - Destroy infrastructure (DANGEROUS!)"
	@echo "  test              - Run all checks"
	@echo "  clean             - Clean terraform cache"
	@echo ""
	@echo "Example: make plan ENV=dev"

ENV ?= dev
TF_DIR = terraform/environments/$(ENV)
TF_VARS = -var-file=$(TF_DIR)/terraform.tfvars

init:
	@echo "Initializing OpenTofu for $(ENV) environment..."
	cd $(TF_DIR) && tofu init

validate:
	@echo "Validating OpenTofu configuration for $(ENV)..."
	cd $(TF_DIR) && tofu validate

fmt:
	@echo "Formatting terraform files..."
	tofu fmt -recursive terraform/

lint:
	@echo "Running tflint..."
	cd $(TF_DIR) && tflint --init && tflint

security-check:
	@echo "Running tfsec security checks..."
	tfsec terraform/ --format sarif

plan:
	@echo "Creating execution plan for $(ENV)..."
	cd $(TF_DIR) && tofu plan -out=tfplan

apply:
	@echo "Applying infrastructure changes for $(ENV)..."
	@echo "WARNING: This will create/modify AWS resources!"
	cd $(TF_DIR) && tofu apply tfplan

destroy:
	@echo "DESTROYING infrastructure for $(ENV)!"
	@echo "THIS IS IRREVERSIBLE!"
	@read -p "Type 'yes' to confirm: " confirm && \
	[ "$$confirm" = "yes" ] && \
	cd $(TF_DIR) && tofu destroy || echo "Cancelled"

test: fmt lint security-check validate
	@echo "All checks passed!"

clean:
	@echo "Cleaning terraform cache..."
	find terraform -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find terraform -name "*.tfplan" -delete
	find terraform -name ".terraform.lock.hcl" -delete
	@echo "Clean complete"

.DEFAULT_GOAL := help
