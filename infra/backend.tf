# ---------------------------------------------------------------------------
# Remote State Backend
#
# State is stored in S3 (NOT in this project folder) and shared across the team.
# DynamoDB provides state locking to prevent concurrent apply conflicts.
#
# Prerequisites (one-time setup, done outside Terraform):
#   1. Create S3 bucket: terraform-{project_name}-state
#      - Enable versioning
#      - Enable server-side encryption (AES-256)
#      - Block all public access
#   2. Create DynamoDB table: terraform-{project_name}-locks
#      - Partition key: LockID (String)
#
# Team members need IAM permissions:
#   - s3:GetObject, s3:PutObject, s3:DeleteObject on the state bucket
#   - dynamodb:GetItem, dynamodb:PutItem, dynamodb:DeleteItem on the lock table
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    # Shared backend settings. The `key` (state file path) is intentionally
    # omitted here — it is passed per-environment at init time via:
    #   terraform init -backend-config="envs/dev.backend.hcl"
    #   terraform init -backend-config="envs/staging.backend.hcl"
    #
    # This gives each environment its own isolated state file:
    #   s3://terraform-aws-upskill-state/dev/terraform.tfstate
    #   s3://terraform-aws-upskill-state/staging/terraform.tfstate
    #
    # Terraform backend config does not support variable interpolation,
    # so this partial-config pattern is the correct approach.
    bucket         = "terraform-aws-upskill-state"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-aws-upskill-locks"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}
