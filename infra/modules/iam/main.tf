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

# ---------------------------------------------------------------------------
# X-Ray Write Policy
# Attached to both task roles so app containers can send traces to X-Ray.
# PutTraceSegments: send trace data, PutTelemetryRecords: send sampling stats.
# GetSamplingRules/GetSamplingTargets: X-Ray SDK fetches dynamic sampling rules.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "xray_write" {
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "xray_write" {
  name        = "${var.project_name}-${var.environment_name}-xray-write"
  description = "Allows ECS task containers to send traces and telemetry to X-Ray"
  policy      = data.aws_iam_policy_document.xray_write.json
}

resource "aws_iam_role_policy_attachment" "web_task_xray" {
  role       = aws_iam_role.web_task.name
  policy_arn = aws_iam_policy.xray_write.arn
}

resource "aws_iam_role_policy_attachment" "api_task_xray" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.xray_write.arn
}

# ---------------------------------------------------------------------------
# Current AWS account ID — used to construct scoped resource ARNs below
# so policies grant least-privilege rather than wildcarding account.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Secrets Manager Read — Web Task Role
#
# Scoped to: {project}/{env}/web/* — ready for any web-specific secrets
# added in the future (API keys, third-party service credentials, etc.).
# Currently no web secrets exist; policy is a forward-looking placeholder.
# The web container does NOT have access to the RDS secret (least privilege).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "web_task_secrets" {
  statement {
    sid    = "SecretsManagerReadWeb"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Scoped to web-namespace secrets only — API and RDS secrets excluded
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment_name}/web/*",
    ]
  }
}

resource "aws_iam_policy" "web_task_secrets" {
  name        = "${var.project_name}-${var.environment_name}-web-secrets-read"
  description = "Allows Next.js web container to read its own Secrets Manager secrets"
  policy      = data.aws_iam_policy_document.web_task_secrets.json
}

resource "aws_iam_role_policy_attachment" "web_task_secrets" {
  role       = aws_iam_role.web_task.name
  policy_arn = aws_iam_policy.web_task_secrets.arn
}

# ---------------------------------------------------------------------------
# Secrets Manager Read — API Task Role
#
# Scoped to the specific RDS root password secret ARN — the API container
# reads this at startup to retrieve the database password, then connects
# to RDS using standard pg password authentication.
# The ARN is passed in from the rds module output so it's always accurate.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "api_task_secrets" {
  statement {
    sid    = "SecretsManagerReadRDS"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Locked to the exact RDS secret — no wildcard on secrets
    resources = [var.rds_secret_arn]
  }
}

resource "aws_iam_policy" "api_task_secrets" {
  name        = "${var.project_name}-${var.environment_name}-api-secrets-read"
  description = "Allows NestJS API container to read the RDS root password from Secrets Manager"
  policy      = data.aws_iam_policy_document.api_task_secrets.json
}

resource "aws_iam_role_policy_attachment" "api_task_secrets" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.api_task_secrets.arn
}

# ---------------------------------------------------------------------------
# Parameter Store Read — Web Task Role
#
# Scoped to /app/web/* — grants access to all web-service config entries.
# GetParameter: read a single parameter by name.
# GetParameters: read multiple parameters in one API call (batch fetch).
# GetParametersByPath: read all parameters under a prefix (used at startup).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "web_task_ssm" {
  statement {
    sid    = "SSMReadWeb"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    # All /app/web/ parameters — scoped by path prefix
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/app/web/*",
    ]
  }

  # Needed to decrypt SecureString parameters (even if using standard strings,
  # adding this now avoids a second IAM change if strings are upgraded to SecureString)
  statement {
    sid    = "KMSDecryptWebSSM"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_policy" "web_task_ssm" {
  name        = "${var.project_name}-${var.environment_name}-web-ssm-read"
  description = "Allows Next.js web container to read /app/web/* Parameter Store entries"
  policy      = data.aws_iam_policy_document.web_task_ssm.json
}

resource "aws_iam_role_policy_attachment" "web_task_ssm" {
  role       = aws_iam_role.web_task.name
  policy_arn = aws_iam_policy.web_task_ssm.arn
}

# ---------------------------------------------------------------------------
# Parameter Store Read — API Task Role
#
# Scoped to /app/api/* — grants access to all API-service config entries
# including db_host, db_port, db_name, and log_level.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "api_task_ssm" {
  statement {
    sid    = "SSMReadAPI"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/app/api/*",
    ]
  }

  statement {
    sid    = "KMSDecryptAPISSM"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_policy" "api_task_ssm" {
  name        = "${var.project_name}-${var.environment_name}-api-ssm-read"
  description = "Allows NestJS API container to read /app/api/* Parameter Store entries"
  policy      = data.aws_iam_policy_document.api_task_ssm.json
}

resource "aws_iam_role_policy_attachment" "api_task_ssm" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.api_task_ssm.arn
}

# ---------------------------------------------------------------------------
# RDS IAM Authentication — API Task Role
#
# Allows the NestJS API to authenticate to RDS using IAM tokens as an
# alternative to the Secrets Manager password. Currently the app uses
# password auth (retrieved from Secrets Manager); this policy is included
# as preparation for future migration to IAM database authentication.
#
# Resource format: arn:aws:rds-db:{region}:{account}:dbuser:{resource_id}/{db_username}
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "api_task_rds_connect" {
  statement {
    sid    = "RDSIAMConnect"
    effect = "Allow"
    actions = [
      "rds-db:connect",
    ]
    # Scoped to the specific RDS instance and DB username
    resources = [
      "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${var.rds_instance_resource_id}/${var.db_username}",
    ]
  }
}

resource "aws_iam_policy" "api_task_rds_connect" {
  name        = "${var.project_name}-${var.environment_name}-api-rds-connect"
  description = "Allows NestJS API container to authenticate to RDS via IAM (preparation for IAM auth migration)"
  policy      = data.aws_iam_policy_document.api_task_rds_connect.json
}

resource "aws_iam_role_policy_attachment" "api_task_rds_connect" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.api_task_rds_connect.arn
}

# ---------------------------------------------------------------------------
# S3 Read/Write — Web Task Role
#
# Scoped to buckets following the project naming convention:
#   {project_name}-{environment_name}-*
# Application S3 buckets (assets, uploads) are deferred for a future
# checkpoint. This policy will take effect automatically once those
# buckets are created with the correct naming prefix.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "web_task_s3" {
  statement {
    sid    = "S3ListBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment_name}-*",
    ]
  }

  statement {
    sid    = "S3ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment_name}-*/*",
    ]
  }
}

resource "aws_iam_policy" "web_task_s3" {
  name        = "${var.project_name}-${var.environment_name}-web-s3-readwrite"
  description = "Allows Next.js web container to read/write objects in project S3 buckets"
  policy      = data.aws_iam_policy_document.web_task_s3.json
}

resource "aws_iam_role_policy_attachment" "web_task_s3" {
  role       = aws_iam_role.web_task.name
  policy_arn = aws_iam_policy.web_task_s3.arn
}

# ---------------------------------------------------------------------------
# S3 Read/Write — API Task Role
#
# Same naming-convention scope as web task. API may store processed files,
# export reports, or read uploaded assets forwarded from the web service.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "api_task_s3" {
  statement {
    sid    = "S3ListBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment_name}-*",
    ]
  }

  statement {
    sid    = "S3ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment_name}-*/*",
    ]
  }
}

resource "aws_iam_policy" "api_task_s3" {
  name        = "${var.project_name}-${var.environment_name}-api-s3-readwrite"
  description = "Allows NestJS API container to read/write objects in project S3 buckets"
  policy      = data.aws_iam_policy_document.api_task_s3.json
}

resource "aws_iam_role_policy_attachment" "api_task_s3" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.api_task_s3.arn
}
