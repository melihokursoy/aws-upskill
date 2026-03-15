# ---------------------------------------------------------------------------
# IAM Module
#
# Defines three IAM roles for ECS Fargate:
#
#   1. ecs_task_execution  — Used by the ECS AGENT (not the app) to:
#                            - Pull container images from ECR
#                            - Write container stdout/stderr to CloudWatch Logs
#                            Assumed by: ecs-tasks.amazonaws.com
#                            Policy: AWS managed AmazonECSTaskExecutionRolePolicy
#
#   2. web_task            — Used by the NEXT.JS APPLICATION at runtime.
#                            Assumed by: ecs-tasks.amazonaws.com
#                            Permissions added in Checkpoint 8 (S3, Secrets Manager, etc.)
#
#   3. api_task            — Used by the NESTJS API at runtime.
#                            Assumed by: ecs-tasks.amazonaws.com
#                            Permissions added in Checkpoint 8 (RDS, S3, Secrets Manager, etc.)
#
# Distinction: execution_role is ECS infrastructure plumbing.
#              task roles are application-level permissions.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Task Execution Role
# Purpose: Allows ECS to pull images from ECR and stream logs to CloudWatch.
# This role is attached to every task definition — web and API.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-${var.environment_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-ecs-execution"
    Purpose = "ECS infrastructure - ECR pull and CloudWatch Logs write"
  })
}

# AWS-managed policy that grants ECR image pull and CloudWatch Logs write.
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# Web Service Task Role
# Purpose: Permissions for the Next.js app container at runtime.
# Checkpoint 8 will add: S3 read/write, Secrets Manager, Parameter Store.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "web_task" {
  name               = "${var.project_name}-${var.environment_name}-ecs-task-web"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-ecs-task-web"
    Purpose = "Next.js web app runtime permissions"
  })
}

# ---------------------------------------------------------------------------
# API Service Task Role
# Purpose: Permissions for the NestJS API container at runtime.
# Checkpoint 8 will add: RDS connect, S3, Secrets Manager, Parameter Store.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "api_task" {
  name               = "${var.project_name}-${var.environment_name}-ecs-task-api"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-ecs-task-api"
    Purpose = "NestJS API runtime permissions"
  })
}
