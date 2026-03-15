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

variable "alb_security_group_id" {
  description = "ALB security group ID — ECS tasks allow inbound only from this SG."
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
