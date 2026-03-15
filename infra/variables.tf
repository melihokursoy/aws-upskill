# ---------------------------------------------------------------------------
# Root Module Variables
# All environment-specific values come from envs/dev.tfvars or envs/staging.tfvars
# No hardcoded environment names anywhere in this codebase
# ---------------------------------------------------------------------------

variable "environment_name" {
  description = "Deployment environment name (dev or staging). Passed via -var-file."
  type        = string

  validation {
    condition     = contains(["dev", "staging"], var.environment_name)
    error_message = "environment_name must be 'dev' or 'staging'."
  }
}

variable "region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "owner" {
  description = "Team or individual responsible for this infrastructure (used in tags)."
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier for billing and cost allocation tags."
  type        = string
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the primary public subnet (ALB, NAT Gateway)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  description = "CIDR block for the secondary public subnet (ALB requires 2 AZs — no workloads deployed here)."
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zone_2" {
  description = "Second availability zone for the ALB secondary public subnet."
  type        = string
  default     = "us-east-1b"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (ECS tasks, RDS)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for single-AZ deployment (dev/staging cost optimization)."
  type        = string
  default     = "us-east-1a"
}

# ---------------------------------------------------------------------------
# Domain & HTTPS
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom domain name for this environment (e.g. dev.yourdomain.com). Used for ACM certificate."
  type        = string
}

# ---------------------------------------------------------------------------
# ECS Task Sizing & Scaling
# ---------------------------------------------------------------------------

variable "task_cpu" {
  description = "CPU units for each ECS task (512 = 0.5 vCPU, 1024 = 1 vCPU)."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory in MiB for each ECS task."
  type        = number
  default     = 1024
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

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Cost / Budgets
# ---------------------------------------------------------------------------

variable "monthly_budget_amount" {
  description = "Monthly AWS budget limit for this environment in USD."
  type        = number
}

variable "budget_alert_email" {
  description = "Email address to receive budget alert notifications."
  type        = string
}
