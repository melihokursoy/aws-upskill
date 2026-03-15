variable "environment_name" {
  description = "Deployment environment name (dev or staging)."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (ALB)."
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (ECS tasks, RDS)."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for single-AZ deployment."
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
}
