# ---------------------------------------------------------------------------
# Cognito Module Variables
# ---------------------------------------------------------------------------

variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "region" {
  description = "AWS region the User Pool is deployed in (used to construct issuer URL)."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "allow_self_registration" {
  description = "When true, users can sign up themselves via the Hosted UI. When false, only admins can create users."
  type        = bool
  default     = true
}

variable "app_domain" {
  description = "Custom domain name for this environment (e.g. dev.aws-upskill.codecrib.co.uk). Used to construct Cognito callback and logout URLs."
  type        = string
}
