# .tflint configuration for security and code quality
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "terraform" {
  enabled = true
  version = "0.5.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# Enable all AWS provider rules
rule "aws_instance_invalid_type" {
  enabled = true
}

# Terraform syntax rules
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

# Enforce required provider version constraint
rule "terraform_required_providers" {
  enabled = true
}

# Optional: Disable rules that are too strict
# Uncomment to disable specific rules:
# rule "aws_resource_missing_tags" {
#   enabled = false  # We handle tagging via modules
# }
