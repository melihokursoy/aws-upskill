# ---------------------------------------------------------------------------
# Root Module Outputs
#
# Aggregates outputs from all modules. These are the single source of truth
# for all infrastructure identifiers — no magic strings in application code.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Meta
# ---------------------------------------------------------------------------

output "region" {
  description = "AWS region this environment is deployed in."
  value       = var.region
}

output "environment_name" {
  description = "Environment name (dev or staging)."
  value       = var.environment_name
}

output "domain_name" {
  description = "Custom domain name for this environment."
  value       = var.domain_name
}

# ---------------------------------------------------------------------------
# VPC & Networking
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the primary public subnet (ALB, NAT Gateway)."
  value       = module.vpc.public_subnet_id
}

output "public_subnet_ids" {
  description = "IDs of both public subnets passed to the ALB."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_id" {
  description = "ID of the private subnet (ECS tasks and RDS live here)."
  value       = module.vpc.private_subnet_id
}

output "nat_gateway_ip" {
  description = "Elastic IP of the NAT Gateway (outbound IP for private subnet traffic)."
  value       = module.vpc.nat_gateway_ip
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------

output "ecr_repository_urls" {
  description = "Map of service folder name to ECR URL. Keys match app folder names under apps/ (e.g. 'web', 'api-order')."
  value       = module.ecr.repository_urls
}

output "ecr_registry_id" {
  description = "AWS account ID owning the ECR registries (used for docker login)."
  value       = module.ecr.registry_id
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = module.iam.execution_role_arn
}

output "web_task_role_arn" {
  description = "ARN of the web service task role."
  value       = module.iam.web_task_role_arn
}

output "api_task_role_arn" {
  description = "ARN of the API service task role."
  value       = module.iam.api_task_role_arn
}

# ---------------------------------------------------------------------------
# ECS Cluster & Services
# ---------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN."
  value       = module.ecs.cluster_arn
}

output "ecs_web_service_name" {
  description = "ECS service name for the web application."
  value       = module.ecs.web_service_name
}

output "ecs_api_service_name" {
  description = "ECS service name for the API application."
  value       = module.ecs.api_service_name
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID attached to ECS tasks."
  value       = module.ecs.ecs_tasks_security_group_id
}

output "ecs_web_task_definition_arn" {
  description = "ARN of the latest web task definition revision."
  value       = module.ecs.web_task_definition_arn
}

output "ecs_api_task_definition_arn" {
  description = "ARN of the latest API task definition revision."
  value       = module.ecs.api_task_definition_arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for infrastructure overview."
  value       = module.monitoring.dashboard_name
}

output "log_group_web" {
  description = "CloudWatch log group for web service (/aws/ecs/web)."
  value       = module.ecs.web_log_group_name
}

output "log_group_api" {
  description = "CloudWatch log group for API service (/aws/ecs/api)."
  value       = module.ecs.api_log_group_name
}

output "log_group_alb" {
  description = "CloudWatch log group for ALB access logs (/aws/alb/web-api)."
  value       = module.ecs.alb_log_group_name
}

# ---------------------------------------------------------------------------
# ACM Certificate
# ---------------------------------------------------------------------------

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate attached to the ALB HTTPS listener."
  value       = module.acm.certificate_arn
}

output "acm_validation_cnames" {
  description = "CNAME records to add to your DNS provider to validate the ACM certificate."
  value       = module.acm.validation_cnames
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  description = "ALB DNS name — create a CNAME record in your DNS provider pointing to this."
  value       = module.alb.alb_dns_name
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener (used to attach listener rules in ECS module)."
  value       = module.alb.https_listener_arn
}

output "web_target_group_arn" {
  description = "ARN of the web target group (ECS web service registers here)."
  value       = module.alb.web_target_group_arn
}

output "api_target_group_arn" {
  description = "ARN of the API target group (ECS API service registers here)."
  value       = module.alb.api_target_group_arn
}

output "alb_security_group_id" {
  description = "ALB security group ID (ECS task SGs must allow inbound from this)."
  value       = module.alb.alb_security_group_id
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

output "rds_db_endpoint" {
  description = "RDS PostgreSQL endpoint address. Pass to API service as DB_HOST."
  value       = module.rds.db_endpoint
}

output "rds_db_port" {
  description = "RDS PostgreSQL port (5432)."
  value       = module.rds.db_port
}

output "rds_db_name" {
  description = "Initial database name created in the RDS instance."
  value       = module.rds.db_name
}

output "rds_db_username" {
  description = "RDS master username."
  value       = module.rds.db_username
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = module.rds.rds_security_group_id
}

output "rds_root_password_secret_arn" {
  description = "Secrets Manager ARN for the RDS root password. API task IAM role needs read access."
  value       = module.rds.root_password_secret_arn
  sensitive   = true
}

output "rds_root_password_secret_name" {
  description = "Secrets Manager secret name: {project}/{env}/rds/postgres/root-password"
  value       = module.rds.root_password_secret_name
}

# ---------------------------------------------------------------------------
# SSM Parameter Store
# ---------------------------------------------------------------------------

output "ssm_web_api_endpoint" {
  description = "SSM parameter name for the web service API endpoint."
  value       = module.ssm.web_api_endpoint_name
}

output "ssm_web_log_level" {
  description = "SSM parameter name for the web service log level."
  value       = module.ssm.web_log_level_name
}

output "ssm_api_db_host" {
  description = "SSM parameter name for the API DB host."
  value       = module.ssm.api_db_host_name
}

output "ssm_api_db_port" {
  description = "SSM parameter name for the API DB port."
  value       = module.ssm.api_db_port_name
}

output "ssm_api_db_name" {
  description = "SSM parameter name for the API DB name."
  value       = module.ssm.api_db_name_name
}

output "ssm_api_log_level" {
  description = "SSM parameter name for the API log level."
  value       = module.ssm.api_log_level_name
}

# ---------------------------------------------------------------------------
# Cognito
# ---------------------------------------------------------------------------

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID. Used by seed-cognito.sh after terraform apply."
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN. Passed to ALB authenticate-cognito action."
  value       = module.cognito.user_pool_arn
}

output "cognito_client_id" {
  description = "Cognito App Client ID."
  value       = module.cognito.client_id
}

output "cognito_domain" {
  description = "Hosted UI domain prefix (e.g. upskill-dev). Passed to ALB. Note: aws- prefix is stripped by Cognito as it is reserved."
  value       = module.cognito.cognito_domain
}

output "cognito_domain_url" {
  description = "Full Hosted UI HTTPS URL for sign-in/sign-out links and SSM."
  value       = module.cognito.cognito_domain_url
}

output "cognito_issuer_url" {
  description = "Cognito OIDC issuer URL."
  value       = module.cognito.issuer_url
}

# ---------------------------------------------------------------------------
# Budgets
# ---------------------------------------------------------------------------

output "budget_name" {
  description = "Name of the AWS Budget for this environment."
  value       = module.budgets.budget_name
}
