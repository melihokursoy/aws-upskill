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
# IAM — Task Execution Role and Service Task Roles
# ---------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  environment_name = var.environment_name
  project_name     = var.project_name
  tags             = local.common_tags
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

# ---------------------------------------------------------------------------
# Auto-Scaling — Target tracking for ECS services
# ---------------------------------------------------------------------------

module "autoscaling" {
  source = "./modules/autoscaling"

  environment_name = var.environment_name
  project_name     = var.project_name
  cluster_name     = module.ecs.cluster_name
  web_service_name = module.ecs.web_service_name
  api_service_name = module.ecs.api_service_name
  min_task_count   = var.min_task_count
  max_task_count   = var.max_task_count
}

# ---------------------------------------------------------------------------
# Monitoring — CloudWatch alarms and dashboard
# ---------------------------------------------------------------------------

module "monitoring" {
  source = "./modules/monitoring"

  environment_name = var.environment_name
  project_name     = var.project_name
  region           = var.region
  tags             = local.common_tags
  cluster_name     = module.ecs.cluster_name
  web_service_name = module.ecs.web_service_name
  api_service_name = module.ecs.api_service_name
  alb_arn_suffix   = module.alb.alb_arn_suffix
  min_task_count   = var.min_task_count
}

# ---------------------------------------------------------------------------
# RDS — PostgreSQL Database
# ---------------------------------------------------------------------------

module "rds" {
  source = "./modules/rds"

  environment_name = var.environment_name
  project_name     = var.project_name
  tags             = local.common_tags

  # Networking
  vpc_id                      = module.vpc.vpc_id
  private_subnet_id           = module.vpc.private_subnet_id
  availability_zone           = var.availability_zone
  ecs_tasks_security_group_id = module.ecs.ecs_tasks_security_group_id

  # Database config
  db_name           = var.db_name
  db_instance_class = var.db_instance_class
}

# ---------------------------------------------------------------------------
# ECS — Fargate Cluster, Task Definitions, Services
# ---------------------------------------------------------------------------

module "ecs" {
  source = "./modules/ecs"

  environment_name   = var.environment_name
  project_name       = var.project_name
  region             = var.region
  log_retention_days = var.log_retention_days
  tags               = local.common_tags

  # Networking
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_subnet_id
  alb_security_group_id = module.alb.alb_security_group_id

  # Load balancer target groups
  web_target_group_arn = module.alb.web_target_group_arn
  api_target_group_arn = module.alb.api_target_group_arn

  # IAM roles
  execution_role_arn = module.iam.execution_role_arn
  web_task_role_arn  = module.iam.web_task_role_arn
  api_task_role_arn  = module.iam.api_task_role_arn

  # Container images (ECR repository URLs — tag appended inside task definition)
  web_image = module.ecr.repository_urls["web"]
  api_image = module.ecr.repository_urls["api-order"]

  # Task sizing and scaling
  task_cpu       = var.task_cpu
  task_memory    = var.task_memory
  min_task_count = var.min_task_count
}
