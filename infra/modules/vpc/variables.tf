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
  description = "CIDR block for the first public subnet (ALB, primary AZ)."
  type        = string
}

variable "public_subnet_cidr_2" {
  description = "CIDR block for the second public subnet (ALB requires 2 AZs). No resources deployed here — ALB requirement only."
  type        = string
}

variable "availability_zone_2" {
  description = "Second availability zone for the ALB secondary public subnet."
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
