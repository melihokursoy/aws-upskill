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
