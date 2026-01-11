# ClinicalDataBridge Infrastructure - Main Configuration
# 
# This configuration deploys a secure, two-tier medical data processing environment:
# - Public Subnet: Bastion (Jump) host with restricted SSH access
# - Private Subnet: Data Processing VM with no public IP (air-gapped)
# - NAT Gateway: Secure outbound internet access for Private VM
# 
# Design Principles:
# 1. Security-first architecture (least privilege)
# 2. HIPAA compliance considerations
# 3. Defense-in-depth with layered security
# 4. Comprehensive audit logging
# 5. Encryption at rest and in transit

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  enable_flow_logs    = var.enable_flow_logs
  aws_region          = var.aws_region
  compliance_tags     = var.compliance_tags
}

# Bastion Module
module "bastion" {
  source = "../../modules/bastion"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  subnet_id            = module.networking.public_subnet_id
  instance_type        = var.bastion_instance_type
  admin_cidr           = var.admin_cidr
  ssh_key_name         = var.ssh_key_name
  enable_monitoring    = var.enable_detailed_monitoring
  compliance_tags      = var.compliance_tags

  depends_on = [module.networking]
}

# Private VM Module
module "private_vm" {
  source = "../../modules/private_vm"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  subnet_id                = module.networking.private_subnet_id
  instance_type            = var.private_vm_instance_type
  bastion_security_group   = module.bastion.security_group_id
  ssh_key_name             = var.ssh_key_name
  enable_encryption        = var.enable_encryption_at_rest
  enable_monitoring        = var.enable_detailed_monitoring
  compliance_tags          = var.compliance_tags

  depends_on = [module.networking, module.bastion]
}
