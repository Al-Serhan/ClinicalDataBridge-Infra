variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod) for resource naming and tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion host will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID where the bastion host will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host (e.g., t3.micro)"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into the bastion host (use your IP address)"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for bastion host access"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring for the bastion host"
  type        = bool
}

variable "compliance_tags" {
  description = "Map of compliance and regulatory tags to apply to resources"
  type        = map(string)
}
