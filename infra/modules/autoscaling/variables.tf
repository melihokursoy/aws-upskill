variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name (used to construct the resource_id for App Auto Scaling)."
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

variable "min_task_count" {
  description = "Minimum number of ECS tasks per service."
  type        = number
  default     = 2
}

variable "max_task_count" {
  description = "Maximum number of ECS tasks per service."
  type        = number
  default     = 4
}
