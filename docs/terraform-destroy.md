# Infrastructure Teardown Guide

## Overview

This guide covers how to safely destroy the AWS infrastructure for any environment using Terraform.

All resources are configured to allow clean destruction:

- ECR repositories: `force_delete = true` (deletes images before destroying)
- RDS instance: `deletion_protection = false` (allows immediate deletion)
- No S3 application buckets to worry about (deferred feature)

---

## Prerequisites

- AWS CLI configured with credentials for the target account
- Terraform initialized for the target environment
- No active CI/CD pipelines deploying to the environment

---

## Steps to Destroy an Environment

### 1. Initialize Terraform for the target environment

```bash
cd infra
terraform init -backend-config="envs/<env>.backend.hcl" -reconfigure
```

### 2. Run a plan to see what will be destroyed

```bash
terraform plan -destroy -var-file="envs/<env>.tfvars"
```

Review the output and confirm all expected resources are listed.

### 3. Run destroy

```bash
terraform destroy -var-file="envs/<env>.tfvars"
```

Type `yes` when prompted. Or use the deploy script:

```bash
./infra/scripts/deploy.sh <env> destroy
```

The deploy script requires you to type the environment name to confirm before proceeding.

### 4. Verify cleanup

After destroy completes, verify no orphaned resources remain:

```bash
# ECS clusters
aws ecs list-clusters --region us-east-1

# VPCs tagged with the environment
aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Environment,Values=<env>"

# RDS instances
aws rds describe-db-instances --region us-east-1

# Load balancers
aws elbv2 describe-load-balancers --region us-east-1

# ECR repositories
aws ecr describe-repositories --region us-east-1

# IAM roles with project prefix
aws iam list-roles --query 'Roles[?contains(RoleName, `aws-upskill-<env>`)]'

# CloudWatch log groups
aws logs describe-log-groups --region us-east-1 \
  --log-group-name-prefix "/aws/ecs"
```

Or run the connectivity test script — it will fail with clear errors if resources are gone:

```bash
# Will error on terraform output reads if state is empty, confirming clean destroy
./infra/scripts/test-connectivity.sh <env>
```

---

## Expected Destroy Duration

| Resource           | Approximate Time |
| ------------------ | ---------------- |
| ECS services       | 1–2 min          |
| RDS instance       | 3–5 min          |
| ALB                | 1 min            |
| NAT Gateway        | 1 min            |
| VPC / subnets      | < 30s            |
| IAM roles/policies | < 30s            |
| ECR repositories   | < 30s            |
| **Total**          | **~7–10 min**    |

---

## What Is NOT Destroyed

The following resources exist outside the Terraform-managed state and must be cleaned up manually if needed:

- **Terraform state backend** — S3 bucket and DynamoDB table (managed by `infra/scripts/teardown-state-backend.sh`)
- **Cloudflare DNS records** — CNAME pointing to ALB, ACM validation records

---

## Recovering from a Failed Destroy

If `terraform destroy` fails partway through:

1. Re-run `terraform destroy` — Terraform is idempotent and will retry only the remaining resources
2. If a resource is stuck (e.g. a security group with lingering dependencies), check the AWS Console for what's holding it and remove manually
3. After manual cleanup, run `terraform state rm <resource>` to remove it from state if Terraform can't delete it

---

## Staging Environment

Staging has not been deployed yet. When it is, the same process applies:

```bash
cd infra
terraform init -backend-config="envs/staging.backend.hcl" -reconfigure
terraform destroy -var-file="envs/staging.tfvars"
```

> **Note:** Re-creating staging after destroy requires a manual DNS step in Cloudflare to add the ACM validation CNAME before `terraform apply` will complete — the ACM certificate validation blocks until DNS is set.
