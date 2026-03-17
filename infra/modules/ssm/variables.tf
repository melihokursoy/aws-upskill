variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}

# ---------------------------------------------------------------------------
# Values sourced from other modules — no hardcoding allowed
# ---------------------------------------------------------------------------

variable "alb_dns_name" {
  description = "ALB DNS name. Used as the api_endpoint value for the web service."
  type        = string
}

variable "rds_db_host" {
  description = "RDS instance endpoint address. Stored as /app/api/db_host."
  type        = string
}

variable "rds_db_port" {
  description = "RDS instance port. Stored as /app/api/db_port."
  type        = number
}

variable "rds_db_name" {
  description = "RDS database name. Stored as /app/api/db_name."
  type        = string
}

# ---------------------------------------------------------------------------
# Application Config
# ---------------------------------------------------------------------------

variable "log_level" {
  description = "Log level for all services (info, debug, warn, error)."
  type        = string
  default     = "info"
}

# ---------------------------------------------------------------------------
# Cognito — stored in SSM so containers can read config at startup
# ---------------------------------------------------------------------------

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID. Stored at /app/cognito/user_pool_id."
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID. Stored at /app/cognito/client_id."
  type        = string
}

variable "cognito_issuer_url" {
  description = "Cognito OIDC issuer URL. Stored at /app/cognito/issuer_url."
  type        = string
}

variable "cognito_domain_url" {
  description = "Full Cognito Hosted UI URL. Stored at /app/cognito/domain."
  type        = string
}
