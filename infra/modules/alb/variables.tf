variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the ALB into."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets for the ALB (must be in at least 2 AZs — AWS requirement)."
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}

# ---------------------------------------------------------------------------
# Cognito — ALB authenticate-cognito action
# ---------------------------------------------------------------------------

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN. Used in authenticate-cognito action on protected listener rules."
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito App Client ID. Used in authenticate-cognito action."
  type        = string
}

variable "cognito_user_pool_domain" {
  description = "Cognito Hosted UI domain prefix (e.g. aws-upskill-dev). Used in authenticate-cognito action."
  type        = string
}
