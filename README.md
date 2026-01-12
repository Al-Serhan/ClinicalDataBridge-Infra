# ClinicalDataBridge Infrastructure

Production-ready OpenTofu infrastructure for deploying a secure, HIPAA-compliant medical data processing environment on AWS.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Security Features](#security-features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Accessing Infrastructure](#accessing-infrastructure)
- [Configuration](#configuration)
- [Security Best Practices](#security-best-practices)
- [Monitoring](#monitoring)
- [Cost Estimates](#cost-estimates)
- [Troubleshooting](#troubleshooting)

---

## Overview

This repo contains OpenTofu configuration for deploying a secure, two-tier medical data processing infrastructure. The design follows security-first principles with HIPAA compliance considerations built-in.
The following code has been tested and deployed in a personal AWS account. Just follow the steps below using your own credentials if you want to test this yourself.

**Key Features:**
- Two-tier architecture (public bastion + air-gapped private VM)
- End-to-end encryption (at rest and in transit)
- VPC Flow Logs for audit trails
- CloudWatch monitoring and alerting
- Pre-commit hooks for code quality and security scanning
- Modular, reusable infrastructure code

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS VPC (10.0.0.0/16)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────────────┐ │
│  │  PUBLIC SUBNET       │  │  PRIVATE SUBNET              │ │
│  │  (10.0.0.0/24)       │  │  (10.0.1.0/24)               │ │
│  │                      │  │                              │ │
│  │  ┌────────────────┐  │  │  ┌──────────────────────┐    │ │
│  │  │  Bastion Host  │  │  │  │ Data Processing VM   │    │ │
│  │  │  (Jump Server) │──┼──┼> │ (NO PUBLIC IP)       │    │ │
│  │  │  - SSH Access  │  │  │  │ - Air-gapped         │    │ │
│  │  └────────────────┘  │  │  │ - Encrypted Storage  │    │ │
│  │                      │  │  └──────────────────────┘    │ │
│  │  NAT Gateway    ────────────────────────┐              │ │
│  │                      │  │               │              │ │
│  └──────────────────────┘  └───────────────┼──────────────┘ │
│           │                                │                │
│     Internet Gateway              VPC Flow Logs             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Components:**
- **Public Subnet**: Bastion host with restricted SSH access (admin IP only)
- **Private Subnet**: Data processing VM with no public IP (air-gapped)
- **NAT Gateway**: Secure outbound internet access for updates
- **VPC Flow Logs**: Network traffic audit trail
- **Security Groups**: Explicit allow rules (least privilege)

---

## Security Features

**Network Security:**
- Two-tier architecture isolating sensitive workloads
- Bastion accessible only from specific admin CIDR
- Private VM has no public IP (air-gapped from internet)
- Security groups with explicit allow rules only
- VPC Flow Logs enabled for all network traffic

**Data Protection:**
- EBS encryption with customer-managed KMS keys
- IMDSv2 required (prevents metadata exploits)
- SSH key-based authentication only (no passwords)
- Separate encrypted data volumes for sensitive data

**Compliance & Monitoring:**
- HIPAA-ready tagging and configuration
- CloudWatch detailed monitoring
- CloudWatch alarms for critical events
- AIDE file integrity monitoring
- Comprehensive audit logging

**Code Quality:**
- Pre-commit hooks (fmt, validate, tflint, tfsec, checkov)
- Security scanning before every commit
- Variable validation and input constraints
- Modular, testable infrastructure code

---

## Prerequisites

**Required Tools:**
- [OpenTofu](https://opentofu.org/) >= 1.0 or [Terraform](https://www.terraform.io/) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) v2
- AWS account with appropriate IAM permissions
- SSH key pair created in AWS

**Recommended Tools:**
- [tflint](https://github.com/terraform-linters/tflint) - Terraform linter
- [tfsec](https://aquasecurity.github.io/tfsec/) - Security scanner
- [checkov](https://www.checkov.io/) - Compliance checker
- [pre-commit](https://pre-commit.com/) - Git hooks framework

**Installation (macOS/Linux):**

```bash
# macOS with Homebrew
brew install opentofu awscliv2 tflint tfsec checkov terraform-docs pre-commit

# Linux (Ubuntu/Debian)
# Follow installation guides for each tool from their respective websites
```

---

## Quick Start

### 1. AWS Setup

```bash
# Configure AWS CLI
aws configure --profile <IAM-USER-HERE>
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)

# Verify credentials
aws sts get-caller-identity --profile <IAM-USER-HERE>

# Create your SSH key pair
mkdir -p ~/.ssh
aws ec2 create-key-pair --key-name clinicaldata-key --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/clinicaldata-key.pem
chmod 600 ~/.ssh/clinicaldata-key.pem
```

### 2. Configure Environment

Create your environment configuration file from the example template:

```bash
# Copy the example configuration to create your own
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Edit with your settings
nano terraform/environments/dev/terraform.tfvars
```

Edit `terraform/environments/dev/terraform.tfvars` and set your values:

```hcl
# IMPORTANT: Update this with your actual IP address
admin_cidr = "YOUR_IP_ADDRESS/32"  # e.g., "203.0.113.42/32"

# Find your IP address at: https://checkip.amazonaws.com
```

**Required Variables:**
- `admin_cidr`: Your IP address or network CIDR for Bastion SSH access
- `ssh_key_name`: Name of your EC2 key pair (created in AWS)

**Optional Variables** (have defaults):
- `environment`: "dev" or "prod"
- `bastion_instance_type`: "t3.micro" (cost-effective for bastion)
- `private_vm_instance_type`: "t3.small" (adjustable for workload)

### 3. Deploy Infrastructure

```bash
# Run all quality checks
make test

# Initialize development environment
make init ENV=dev

# Create execution plan
make plan ENV=dev

# Review the plan carefully, then apply
make apply ENV=dev
```

### 4. Access Your Infrastructure

```bash
# Get Bastion IP from outputs
cd terraform/environments/dev
tofu output bastion_public_ip

# SSH to Bastion
ssh -i ~/.ssh/clinicaldata-key.pem ec2-user@<BASTION_IP>

# From Bastion, access Private VM
ssh ec2-user@<PRIVATE_VM_PRIVATE_IP>
```

---

## Project Structure

```
ClinicalDataBridge-Infra/
├── terraform/
│   ├── environments/
│   │   ├── dev/                      # Development environment
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   ├── variables.tf
│   │   │   ├── versions.tf
│   │   │   └── terraform.tfvars      # Dev configuration
│   │   └── prod/                     # Production environment
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       ├── variables.tf
│   │       ├── versions.tf
│   │       └── terraform.tfvars      # Prod configuration
│   └── modules/
│       ├── networking/               # VPC, subnets, NAT, Flow Logs
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   └── variables.tf
│       ├── bastion/                  # Jump host
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   ├── variables.tf
│       │   └── user_data.sh          # Security hardening script
│       └── private_vm/               # Data processing VM
│           ├── main.tf
│           ├── outputs.tf
│           ├── variables.tf
│           └── user_data.sh          # Security hardening + AIDE
├── .pre-commit-config.yaml           # Code quality gates
├── .tflint.hcl                       # Linting rules
├── .gitignore                        # Protects sensitive files
├── Makefile                          # Automation commands
├── requirements-dev.txt              # Python dev dependencies
└── README.md                         # This file
```

---

## Usage

### Makefile Commands

```bash
# Development workflow
make init ENV=dev          # Initialize Terraform
make validate ENV=dev      # Validate configuration
make fmt                   # Format Terraform code
make lint ENV=dev          # Run tflint
make security-check        # Run tfsec security scan
make plan ENV=dev          # Create execution plan
make apply ENV=dev         # Apply infrastructure changes
make test                  # Run all quality checks

# Clean up
make destroy ENV=dev       # Destroy infrastructure (DANGEROUS!)
make clean                 # Clean Terraform cache

# Production deployment
make init ENV=prod
make plan ENV=prod
make apply ENV=prod
```

### Manual Terraform/OpenTofu Commands

```bash
# Navigate to environment directory
cd terraform/environments/dev

# Initialize
tofu init

# Plan changes
tofu plan

# Apply changes
tofu apply

# Show outputs
tofu output

# Destroy (careful!)
tofu destroy
```

---

## Accessing Infrastructure

### SSH to Bastion

```bash
# Direct SSH
ssh -i ~/.ssh/clinicaldata-key.pem ec2-user@<BASTION_IP>
```

### SSH to Private VM (via Bastion Jump Host)

```bash
# Option 1: SSH with ProxyJump
ssh -i ~/.ssh/clinicaldata-key.pem \
    -J ec2-user@<BASTION_IP> \
    ec2-user@<PRIVATE_VM_IP>

# Option 2: Configure SSH config (~/.ssh/config)
Host bastion
  HostName <BASTION_IP>
  User ec2-user
  IdentityFile ~/.ssh/clinicaldata-key.pem

Host private-vm
  HostName <PRIVATE_VM_IP>
  User ec2-user
  IdentityFile ~/.ssh/clinicaldata-key.pem
  ProxyJump bastion

# Then simply: ssh private-vm
```

---

## Configuration

### Key Variables

Located in `terraform/environments/{env}/terraform.tfvars`:

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"dev"` or `"prod"` |
| `aws_region` | AWS region | `"us-east-1"` |
| `vpc_cidr` | VPC CIDR block | `"10.0.0.0/16"` |
| `admin_cidr` | Admin IP for SSH access | `"203.0.113.42/32"` |
| `bastion_instance_type` | Bastion EC2 type | `"t3.micro"` |
| `private_vm_instance_type` | Private VM EC2 type | `"t3.small"` |
| `ssh_key_name` | AWS EC2 key pair name | `"clinicaldata-key"` |
| `enable_encryption_at_rest` | EBS encryption | `true` |
| `enable_detailed_monitoring` | CloudWatch monitoring | `true` |

### Terraform Outputs

After deployment, retrieve information:
tofu init
