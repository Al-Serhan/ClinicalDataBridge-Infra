variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod) for resource naming and tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the private VM will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID where the VM will be deployed (no public IP)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the private VM (e.g., t3.small)"
  type        = string
}

variable "bastion_security_group" {
  description = "Security group ID of the bastion host for SSH access"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for VM access via bastion"
  type        = string
}

variable "enable_encryption" {
  description = "Enable EBS volume encryption with customer-managed KMS keys"
  type        = bool
}

variable "enable_monitoring" {
  description = "Enable CloudWatch detailed monitoring for the private VM"
  type        = bool
}

variable "compliance_tags" {
  description = "Map of compliance and regulatory tags to apply to resources"
  type        = map(string)
}
