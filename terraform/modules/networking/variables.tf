variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "enable_flow_logs" {
  type = bool
}

variable "aws_region" {
  type = string
}

variable "compliance_tags" {
  type = map(string)
}
