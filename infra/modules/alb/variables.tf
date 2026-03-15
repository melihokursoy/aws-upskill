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
