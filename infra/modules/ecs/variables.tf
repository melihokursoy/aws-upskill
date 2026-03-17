variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "region" {
  description = "AWS region (used for CloudWatch Logs driver configuration)."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID for the ECS task security group."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID where ECS tasks run."
  type        = string
}

# ---------------------------------------------------------------------------
# Load Balancer
# ---------------------------------------------------------------------------

variable "web_target_group_arn" {
  description = "ARN of the ALB target group for the web service."
  type        = string
}

variable "api_target_group_arn" {
  description = "ARN of the ALB target group for the API service."
  type        = string
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role (used by the ECS agent to pull images and write logs)."
  type        = string
}

variable "web_task_role_arn" {
  description = "ARN of the task role for the web service (assumed by the Next.js container)."
  type        = string
}

variable "api_task_role_arn" {
  description = "ARN of the task role for the API service (assumed by the NestJS container)."
  type        = string
}

# ---------------------------------------------------------------------------
# Container Images
# ---------------------------------------------------------------------------

variable "web_image" {
  description = "ECR repository URL for the web service image (tag appended by task definition)."
  type        = string
}

variable "api_image" {
  description = "ECR repository URL for the api-order service image (tag appended by task definition)."
  type        = string
}

# ---------------------------------------------------------------------------
# Task Sizing
# ---------------------------------------------------------------------------

variable "task_cpu" {
  description = "CPU units for each ECS task (1 vCPU = 1024 units)."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory in MiB for each ECS task."
  type        = number
  default     = 1024
}

# ---------------------------------------------------------------------------
# Scaling
# ---------------------------------------------------------------------------

variable "min_task_count" {
  description = "Minimum (desired) number of ECS tasks per service."
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Environment Variables — Web Service
# Injected into the web task definition container at runtime.
# All values sourced from Terraform outputs — no hardcoded strings.
# ---------------------------------------------------------------------------

variable "api_endpoint" {
  description = "Base URL for the API service. Web container uses this for server-side API calls. Sourced from ALB DNS output."
  type        = string
}

# ---------------------------------------------------------------------------
# Environment Variables — API Service
# Injected into the API task definition container at runtime.
# The DB password is NOT passed as an env var — the app retrieves it from
# Secrets Manager at startup using DB_PASSWORD_SECRET_ARN.
# ---------------------------------------------------------------------------

variable "db_host" {
  description = "RDS PostgreSQL endpoint address. Sourced from rds module output."
  type        = string
}

variable "db_port" {
  description = "RDS PostgreSQL port (5432). Sourced from rds module output."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "PostgreSQL database name. Sourced from rds module output."
  type        = string
}

variable "db_user" {
  description = "RDS master username. Default matches the rds module default."
  type        = string
  default     = "postgres"
}

variable "db_password_secret_arn" {
  description = "Secrets Manager secret ARN for the RDS root password. App retrieves the password at runtime — never passed as a plaintext env var."
  type        = string
}
