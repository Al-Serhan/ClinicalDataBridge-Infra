terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state configuration for HIPAA compliance
  # Uncomment and configure after creating S3 backend bucket
  # backend "s3" {
  #   bucket         = "clinicaldata-tfstate-prod"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "clinicaldata-tfstate-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  # Add default tags for all resources (HIPAA compliance)
  default_tags {
    tags = {
      Project             = "ClinicalDataBridge"
      Environment         = var.environment
      ManagedBy           = "OpenTofu"
      DataClassification  = "PHI"
      ComplianceRequired  = "HIPAA"
    }
  }
}
