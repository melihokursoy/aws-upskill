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

# ---------------------------------------------------------------------------
# ECS Task Security Group
#
# One shared security group for all ECS tasks.
# Inbound:  port 3300 (web) and 3301 (api) from ALB security group only.
# Outbound: all traffic allowed (ECR pulls, CloudWatch, external APIs).
# ---------------------------------------------------------------------------

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment_name}-ecs-tasks"
  description = "ECS tasks - inbound from ALB only, all outbound"
  vpc_id      = var.vpc_id

  # No inline ingress rules — cross-module rules (ALB → ECS tasks) are defined
  # as aws_security_group_rule resources in the root module (infra/main.tf).
  # This gives Terraform visibility into the dependency so it can delete the
  # rules before either security group during terraform destroy.

  # Outbound — ECR image pulls, CloudWatch Logs, Secrets Manager, internet
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-ecs-tasks"
  })
}

# ---------------------------------------------------------------------------
# Web Task Definition (Next.js — port 3300)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.project_name}-${var.environment_name}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Required for Fargate
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.web_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "${var.web_image}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3300
          protocol      = "tcp"
        }
      ]

      environment = [
        # Runtime identity — never hardcoded, always from Terraform variables
        { name = "NODE_ENV", value = "production" },
        { name = "ENVIRONMENT", value = var.environment_name },
        { name = "REGION", value = var.region },
        # Network
        { name = "PORT", value = "3300" },
        { name = "HOSTNAME", value = "0.0.0.0" },
        # Observability
        { name = "LOG_GROUP", value = aws_cloudwatch_log_group.web.name },
        # API integration — web service calls the API through the ALB
        { name = "API_ENDPOINT", value = var.api_endpoint },
        # Cognito — used for sign-in/sign-out redirects and auth-aware rendering
        { name = "COGNITO_CLIENT_ID", value = var.cognito_client_id },
        { name = "COGNITO_DOMAIN", value = var.cognito_domain_url },
        { name = "NEXT_PUBLIC_APP_URL", value = var.app_url },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Container-level health check (independent of ALB health check)
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O- http://localhost:3300/nextapi/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-web"
    Service = "web"
  })
}

# ---------------------------------------------------------------------------
# API Task Definition (NestJS — port 3301)
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.api_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.api_image}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3301
          protocol      = "tcp"
        }
      ]

      environment = [
        # Runtime identity
        { name = "NODE_ENV", value = "production" },
        { name = "ENVIRONMENT", value = var.environment_name },
        { name = "REGION", value = var.region },
        # Network
        { name = "PORT", value = "3301" },
        # Observability
        { name = "LOG_GROUP", value = aws_cloudwatch_log_group.api.name },
        # Database — host/port/name as plain env vars; password retrieved from Secrets Manager at runtime
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_user },
        # DB_PASSWORD_SECRET_ARN retained so app can reference the ARN if needed
        { name = "DB_PASSWORD_SECRET_ARN", value = var.db_password_secret_arn },
        # Parameter Store prefix — app fetches config values under /app/api/* at startup
        { name = "PARAMETER_STORE_PREFIX", value = "/app/api" },
        # Cognito — used for JWT validation (issuer, audience) and user pool access
        { name = "COGNITO_USER_POOL_ID", value = var.cognito_user_pool_id },
        { name = "COGNITO_CLIENT_ID", value = var.cognito_client_id },
        { name = "COGNITO_ISSUER_URL", value = var.cognito_issuer_url },
      ]

      secrets = [
        # Extract the "password" key from the JSON secret {"username":...,"password":...}
        # Syntax: <secret-arn>:<json-key>::  (ECS JSON key extraction)
        { name = "DB_PASSWORD", valueFrom = "${var.db_password_secret_arn}:password::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O- http://localhost:3301/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-api"
    Service = "api"
  })
}

# ---------------------------------------------------------------------------
# Web ECS Service — Rolling Deployment
#
# Rolling strategy:
#   minimumHealthyPercent = 50  → at least 1 of 2 tasks stays healthy during deploy
#   maximumPercent        = 100 → no extra tasks spun up (stays at desired_count)
#   health_check_grace_period   → gives container time to start before ALB checks it
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "web" {
  name            = "${var.project_name}-${var.environment_name}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.min_task_count

  # Use capacity provider strategy instead of launch_type so FARGATE_SPOT is
  # actually used for scale-out tasks. launch_type overrides the cluster's
  # capacity provider configuration and prevents FARGATE_SPOT from being selected.
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1 # 1 base task always on standard FARGATE for reliability
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4 # Scale-out tasks go to SPOT for cost savings
  }

  # Rolling deployment — ECS stops one old task, starts one new task at a time
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds  = 120

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false # Tasks run in private subnet, use NAT for outbound
  }

  load_balancer {
    target_group_arn = var.web_target_group_arn
    container_name   = "web"
    container_port   = 3300
  }

  # Ensure log group exists before the service starts writing to it
  depends_on = [aws_cloudwatch_log_group.web]

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-web"
    Service = "web"
  })
}

# ---------------------------------------------------------------------------
# API ECS Service — Rolling Deployment
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-${var.environment_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.min_task_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds  = 120

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = 3301
  }

  depends_on = [aws_cloudwatch_log_group.api]

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-api"
    Service = "api"
  })
}
