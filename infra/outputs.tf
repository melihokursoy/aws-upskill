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
# ECS Cluster
# ---------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN."
  value       = module.ecs.cluster_arn
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
