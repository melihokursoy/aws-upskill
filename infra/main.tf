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
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# ---------------------------------------------------------------------------
# VPC & Networking
# ---------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  environment_name     = var.environment_name
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  public_subnet_cidr_2 = var.public_subnet_cidr_2
  private_subnet_cidr  = var.private_subnet_cidr
  availability_zone    = var.availability_zone
  availability_zone_2  = var.availability_zone_2
  tags                 = local.common_tags
}

# ---------------------------------------------------------------------------
# ACM Certificate (HTTPS)
# ---------------------------------------------------------------------------

module "acm" {
  source = "./modules/acm"

  domain_name = var.domain_name
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# ECR — Container Registries
# ---------------------------------------------------------------------------

module "ecr" {
  source = "./modules/ecr"

  environment_name = var.environment_name
  project_name     = var.project_name
  tags             = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS — Fargate Cluster and CloudWatch Log Groups
# ---------------------------------------------------------------------------

module "ecs" {
  source = "./modules/ecs"

  environment_name   = var.environment_name
  project_name       = var.project_name
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

module "alb" {
  source = "./modules/alb"

  environment_name  = var.environment_name
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
  tags              = local.common_tags
}
