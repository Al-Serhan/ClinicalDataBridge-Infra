# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.networking.vpc_cidr
}

# Subnet Outputs
output "public_subnet_id" {
  description = "Public subnet ID for Bastion"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID for Data Processing VM"
  value       = module.networking.private_subnet_id
}

# Bastion Outputs
output "bastion_public_ip" {
  description = "Public IP address of Bastion host"
  value       = module.bastion.public_ip
  sensitive   = false
}

output "bastion_instance_id" {
  description = "Instance ID of Bastion host"
  value       = module.bastion.instance_id
}

# Private VM Outputs
output "private_vm_private_ip" {
  description = "Private IP address of Data Processing VM"
  value       = module.private_vm.private_ip
  sensitive   = false
}

output "private_vm_instance_id" {
  description = "Instance ID of Private VM"
  value       = module.private_vm.instance_id
}

# Security Group Outputs
output "bastion_security_group_id" {
  description = "Security group ID for Bastion"
  value       = module.bastion.security_group_id
}

output "private_vm_security_group_id" {
  description = "Security group ID for Private VM"
  value       = module.private_vm.security_group_id
}

# NAT Gateway Info
output "nat_gateway_id" {
  description = "NAT Gateway ID for Private VM internet access"
  value       = module.networking.nat_gateway_id
}

# Important Security Notes
output "security_recommendations" {
  description = "Important security configuration notes"
  value = <<-EOT
    SECURITY CHECKLIST:
    1. All instances use security groups with explicit allow rules
    2. Private VM has no public IP (air-gapped from internet)
    3. SSH access to Bastion is restricted to admin_cidr
    4. All data at rest is encrypted (EBS encryption enabled)
    5. VPC Flow Logs enabled for audit trail
    6. Enable remote state backend (S3 + DynamoDB) before production
    7. Enable MFA for AWS console access
    8. Review and rotate SSH keys regularly
    9. Enable CloudTrail for API audit logging
    10. Configure CloudWatch alarms for security events
  EOT
}
