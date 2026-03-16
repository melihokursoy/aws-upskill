variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for budget naming."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag value to filter costs by (e.g. aws-upskill-dev)."
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget limit in USD."
  type        = number
}

variable "budget_alert_email" {
  description = "Email address to receive budget alert notifications."
  type        = string
}
