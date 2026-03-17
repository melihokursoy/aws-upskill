variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "region" {
  description = "AWS region — used to construct resource ARNs for scoped IAM policies."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}

# ---------------------------------------------------------------------------
# RDS — for API task role policies
# ---------------------------------------------------------------------------

variable "rds_secret_arn" {
  description = "Secrets Manager secret ARN for the RDS root password. API task role is granted read access."
  type        = string
}

variable "rds_instance_resource_id" {
  description = "RDS instance resource ID (e.g. db-XXXXXXXX). Used to scope the rds-db:connect IAM policy."
  type        = string
}

variable "db_username" {
  description = "RDS master username. Used to scope the rds-db:connect IAM policy to this user."
  type        = string
  default     = "postgres"
}
