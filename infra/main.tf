# ---------------------------------------------------------------------------
# Root Module
#
# Orchestrates all infrastructure modules. Environment-specific values
# come from envs/dev.tfvars or envs/staging.tfvars — no hardcoded names.
# ---------------------------------------------------------------------------

locals {
  # Common tags applied to every AWS resource via provider default_tags.
  # Resources can be filtered in AWS Console by any of these tags.
  common_tags = {
    Environment = var.environment_name
    Project     = var.project_name
    ManagedBy   = "terraform"
    CreatedAt   = timestamp()
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# ---------------------------------------------------------------------------
# VPC & Networking
# ---------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  environment_name    = var.environment_name
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  tags                = local.common_tags
}
