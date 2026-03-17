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

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID for the RDS security group."
  type        = string
}

variable "private_subnet_id" {
  description = "Primary private subnet ID (AZ1 — RDS instance runs here)."
  type        = string
}

variable "private_subnet_id_2" {
  description = "Secondary private subnet ID (AZ2 — required by AWS DB subnet group, RDS instance does not run here)."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for single-AZ RDS deployment."
  type        = string
}

# ---------------------------------------------------------------------------
# Database Configuration
# ---------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the initial database to create in the RDS instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "postgres"
}

variable "db_instance_class" {
  description = "RDS instance class. Use db.t3.micro for dev/staging cost optimization."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB for the RDS instance."
  type        = number
  default     = 20
}
