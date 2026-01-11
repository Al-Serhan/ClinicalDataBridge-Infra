variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "admin_cidr" {
  type      = string
  sensitive = true
}

variable "ssh_key_name" {
  type = string
}

variable "enable_monitoring" {
  type = bool
}

variable "compliance_tags" {
  type = map(string)
}
