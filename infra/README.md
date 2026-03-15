# Infrastructure

Terraform configuration for provisioning AWS infrastructure. All resources are managed as code — no manual AWS Console changes.

## Structure

```
infra/
├── main.tf              # Root module — wires all child modules together
├── variables.tf         # Input variables (all values come from envs/*.tfvars)
├── outputs.tf           # Root outputs (single source of truth for all resource IDs)
├── backend.tf           # S3 + DynamoDB remote state configuration
├── .gitignore           # Excludes state files, .terraform/, terraform.tfvars
├── envs/
│   ├── dev.tfvars          # Development environment values
│   ├── dev.backend.hcl     # Dev state file key (dev/terraform.tfstate)
│   ├── staging.tfvars      # Staging environment values
│   └── staging.backend.hcl # Staging state file key (staging/terraform.tfstate)
├── scripts/
│   ├── deploy.sh                # Terraform deploy wrapper (plan/apply/destroy)
│   ├── build-and-push-ecr.sh   # Build Docker image and push to ECR
│   └── push-ecr.sh             # Push pre-built image to ECR
└── modules/
    ├── vpc/             # VPC, subnets, IGW, NAT Gateway, route tables
    ├── alb/             # Application Load Balancer + HTTPS listeners
    ├── acm/             # ACM certificate for HTTPS
    ├── ecr/             # Elastic Container Registry repositories
    ├── ecs/             # ECS Fargate cluster and services
    ├── autoscaling/     # Target tracking auto-scaling policies
    ├── rds/             # PostgreSQL RDS database
    ├── s3/              # S3 buckets
    ├── iam/             # IAM roles and policies
    └── monitoring/      # CloudWatch log groups, alarms, dashboards
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- Docker (for building and pushing images)

## One-Time Backend Setup

Before first use, create the remote state resources (outside Terraform):

```bash
# Create S3 state bucket
aws s3api create-bucket --bucket terraform-aws-upskill-state --region us-east-1
aws s3api put-bucket-versioning --bucket terraform-aws-upskill-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket terraform-aws-upskill-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket terraform-aws-upskill-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-aws-upskill-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Deploying

```bash
# Deploy dev environment
./infra/scripts/deploy.sh dev

# Deploy staging environment
./infra/scripts/deploy.sh staging

# Plan only (no apply)
./infra/scripts/deploy.sh dev plan

# Destroy an environment
./infra/scripts/deploy.sh dev destroy
```

## Manual Terraform Commands

Each environment gets its own isolated state file via `-backend-config`:

```bash
cd infra

# Dev
terraform init -backend-config="envs/dev.backend.hcl"
terraform plan -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"
terraform destroy -var-file="envs/dev.tfvars"

# Staging
terraform init -backend-config="envs/staging.backend.hcl"
terraform plan -var-file="envs/staging.tfvars"
terraform apply -var-file="envs/staging.tfvars"
terraform destroy -var-file="envs/staging.tfvars"
```

> Note: Run `terraform init -reconfigure -backend-config="envs/<env>.backend.hcl"` when switching between environments.

## Environments

Both dev and staging are single-AZ for cost optimization. VPC CIDRs are kept separate so they do not overlap.

| Setting | Dev | Staging |
|---|---|---|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| Min tasks | 2 | 2 |
| Max tasks | 4 | 4 |
| Log retention | 7 days | 7 days |
| Monthly budget | $50 | $75 |

See `docs/terraform-infrastructure.md` and `docs/terraform-deployment.md` for full details.
