# Core Configuration Variables
variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "clinicaldata"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,32}$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, max 32 chars."
  }
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for security monitoring"
  type        = bool
  default     = true
}

# Bastion Configuration
variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion host"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[234]\\.", var.bastion_instance_type))
    error_message = "Bastion should use t-family instances for cost efficiency."
  }
}

variable "admin_cidr" {
  description = "CIDR block for admin access to Bastion (RESTRICT THIS IN PROD!)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "Admin CIDR must be a valid CIDR block."
  }
}

# Private VM Configuration
variable "private_vm_instance_type" {
  description = "EC2 instance type for Private Data Processing VM"
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^t[234]\\.", var.private_vm_instance_type))
    error_message = "Private VM should use t-family instances for cost efficiency."
  }
}

variable "enable_encryption_at_rest" {
  description = "Enable EBS encryption for all volumes"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for compliance"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "Name of EC2 key pair for SSH access"
  type        = string
  default     = "clinicaldata-key"
}

# Tagging for compliance
variable "compliance_tags" {
  description = "Additional tags for compliance tracking"
  type        = map(string)
  default = {
    CostCenter     = "Medical"
    DataResidency  = "US"
    BackupRequired = "true"
  }
}
