variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod) for resource naming and tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic auditing and compliance"
  type        = bool
}

variable "aws_region" {
  description = "AWS region where resources will be deployed (e.g., us-east-1)"
  type        = string
}

variable "compliance_tags" {
  description = "Map of compliance and regulatory tags to apply to resources"
  type        = map(string)
}
