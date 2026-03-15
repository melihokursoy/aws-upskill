variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "region" {
  description = "AWS region (used in dashboard widget configuration)."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}

variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "web_service_name" {
  description = "ECS service name for the web application."
  type        = string
}

variable "api_service_name" {
  description = "ECS service name for the API application."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used in CloudWatch metric dimensions (e.g. app/my-alb/abc123)."
  type        = string
}

variable "min_task_count" {
  description = "Minimum task count — used as alarm threshold for task failure detection."
  type        = number
  default     = 2
}
