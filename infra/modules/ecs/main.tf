# ---------------------------------------------------------------------------
# ECS Module
#
# Creates:
#   - ECS Fargate cluster (serverless — no EC2 instances to manage)
#   - CloudWatch Log Groups for each service and the ALB
#     /aws/ecs/web      — Next.js application logs
#     /aws/ecs/api      — NestJS API logs
#     /aws/alb/web-api  — ALB access logs
#
# IAM roles are created separately in the iam/ module (Checkpoint 8)
# and referenced by task definitions in the ecs/ module later.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ECS Fargate Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment_name}"

  # Enable Container Insights for enhanced ECS metrics in CloudWatch
  # Provides CPU, memory, network, and storage metrics per task
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-cluster"
  })
}

# Capacity provider — use FARGATE_SPOT for cost savings in dev/staging
# Tasks fall back to standard FARGATE if SPOT is unavailable
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1 # At least 1 task always on standard FARGATE for reliability
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups
# Organised by service — enables per-service log filtering and alarming.
# All logs queryable by correlation ID across services.
# ---------------------------------------------------------------------------

# Next.js web application logs
resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/ecs/web"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "/aws/ecs/web"
    Service = "web"
  })
}

# NestJS API logs
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/ecs/api"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "/aws/ecs/api"
    Service = "api"
  })
}

# ALB access logs — records every request through the load balancer
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/alb/web-api"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "/aws/alb/web-api"
    Service = "alb"
  })
}
