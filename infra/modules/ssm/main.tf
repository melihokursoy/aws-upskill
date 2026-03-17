# ---------------------------------------------------------------------------
# SSM Parameter Store Module
#
# Stores non-sensitive application configuration for both services.
# All values are sourced from Terraform outputs — no magic strings.
#
# Path convention:
#   /app/web/*  — Next.js web service configuration
#   /app/api/*  — NestJS API service configuration
#
# IAM policies in the iam/ module grant each ECS task role read access
# to its own path prefix only (least-privilege).
#
# Parameter type: String (non-sensitive config values).
# Sensitive values (passwords, keys) go in Secrets Manager instead.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Web Service Parameters
# ---------------------------------------------------------------------------

# API endpoint URL used by Next.js for server-side API calls.
# Points to the ALB DNS with https scheme and /api path prefix.
resource "aws_ssm_parameter" "web_api_endpoint" {
  name        = "/app/web/api_endpoint"
  description = "API service base URL for Next.js server-side requests. Sourced from ALB DNS output."
  type        = "String"
  value       = "https://${var.alb_dns_name}/api"

  tags = merge(var.tags, {
    Name    = "/app/web/api_endpoint"
    Service = "web"
  })
}

resource "aws_ssm_parameter" "web_log_level" {
  name        = "/app/web/log_level"
  description = "Log verbosity for the Next.js web service (info, debug, warn, error)."
  type        = "String"
  value       = var.log_level

  tags = merge(var.tags, {
    Name    = "/app/web/log_level"
    Service = "web"
  })
}

# ---------------------------------------------------------------------------
# API Service Parameters
#
# DB connection details are stored here so the NestJS API can fetch them
# at startup via GetParametersByPath("/app/api"). The DB password is NOT
# here — it lives in Secrets Manager (see rds module).
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "api_db_host" {
  name        = "/app/api/db_host"
  description = "RDS PostgreSQL endpoint. Sourced from rds module output."
  type        = "String"
  value       = var.rds_db_host

  tags = merge(var.tags, {
    Name    = "/app/api/db_host"
    Service = "api"
  })
}

resource "aws_ssm_parameter" "api_db_port" {
  name        = "/app/api/db_port"
  description = "RDS PostgreSQL port (5432)."
  type        = "String"
  value       = tostring(var.rds_db_port)

  tags = merge(var.tags, {
    Name    = "/app/api/db_port"
    Service = "api"
  })
}

resource "aws_ssm_parameter" "api_db_name" {
  name        = "/app/api/db_name"
  description = "PostgreSQL database name. Sourced from rds module output."
  type        = "String"
  value       = var.rds_db_name

  tags = merge(var.tags, {
    Name    = "/app/api/db_name"
    Service = "api"
  })
}

resource "aws_ssm_parameter" "api_log_level" {
  name        = "/app/api/log_level"
  description = "Log verbosity for the NestJS API service (info, debug, warn, error)."
  type        = "String"
  value       = var.log_level

  tags = merge(var.tags, {
    Name    = "/app/api/log_level"
    Service = "api"
  })
}

# ---------------------------------------------------------------------------
# Cognito Parameters
#
# Stored under /app/cognito/* so both services can read them with a single
# GetParametersByPath call. Non-sensitive — stored as String, not SecureString.
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name        = "/app/cognito/user_pool_id"
  description = "Cognito User Pool ID. Sourced from cognito module output."
  type        = "String"
  value       = var.cognito_user_pool_id

  tags = merge(var.tags, {
    Name    = "/app/cognito/user_pool_id"
    Service = "cognito"
  })
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name        = "/app/cognito/client_id"
  description = "Cognito App Client ID. Sourced from cognito module output."
  type        = "String"
  value       = var.cognito_client_id

  tags = merge(var.tags, {
    Name    = "/app/cognito/client_id"
    Service = "cognito"
  })
}

resource "aws_ssm_parameter" "cognito_issuer_url" {
  name        = "/app/cognito/issuer_url"
  description = "Cognito OIDC issuer URL. Sourced from cognito module output."
  type        = "String"
  value       = var.cognito_issuer_url

  tags = merge(var.tags, {
    Name    = "/app/cognito/issuer_url"
    Service = "cognito"
  })
}

resource "aws_ssm_parameter" "cognito_domain" {
  name        = "/app/cognito/domain"
  description = "Full Cognito Hosted UI URL. Sourced from cognito module output."
  type        = "String"
  value       = var.cognito_domain_url

  tags = merge(var.tags, {
    Name    = "/app/cognito/domain"
    Service = "cognito"
  })
}
