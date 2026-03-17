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
│   ├── push-ecr.sh             # Push pre-built image to ECR
│   ├── force-cleanup.sh        # Manual unblock for stuck terraform destroy
│   └── test-connectivity.sh    # Post-deploy health check script
└── modules/
    ├── vpc/             # VPC, subnets, IGW, NAT Gateway, route tables
    ├── alb/             # Application Load Balancer + HTTPS listeners
    ├── acm/             # ACM certificate for HTTPS
    ├── ecr/             # Elastic Container Registry repositories
    ├── ecs/             # ECS Fargate cluster and services
    ├── autoscaling/     # Target tracking auto-scaling policies
    ├── rds/             # PostgreSQL RDS database
    ├── iam/             # IAM roles and policies
    ├── ssm/             # Parameter Store entries for app configuration
    ├── monitoring/      # CloudWatch log groups, alarms, dashboards
    └── budgets/         # AWS Budgets monthly cost alerts
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

| Setting        | Dev         | Staging     |
| -------------- | ----------- | ----------- |
| VPC CIDR       | 10.0.0.0/16 | 10.1.0.0/16 |
| Min tasks      | 2           | 2           |
| Max tasks      | 4           | 4           |
| Log retention  | 7 days      | 7 days      |
| Monthly budget | $50         | $75         |

See `docs/terraform-infrastructure.md` and `docs/terraform-deployment.md` for full details.

---

## Key Design Decisions

### No Magic Strings

No environment names, account IDs, ARNs, or resource names are hardcoded in Terraform code.
All environment-specific values come from `envs/dev.tfvars` or `envs/staging.tfvars`.
Resource names use `${var.project_name}-${var.environment_name}-*` interpolation throughout.
ARNs and IDs are always passed between modules via outputs — never copy-pasted strings.

### Cross-Module Security Group Rules

Security groups that reference a SG from another module use `aws_security_group_rule`
resources in the root module (`main.tf`) rather than inline `ingress` blocks inside modules.
Inline blocks using a cross-module SG ID are opaque strings to Terraform's dependency graph
and cause `DependencyViolation` errors during destroy. Root-module rules give Terraform
explicit edges so rules are deleted before either SG.

See `.claude/rules/terraform-security-groups.md` for the full rule.

### Separate `aws_route` Resources

Route tables have no inline `route` blocks. Routes are standalone `aws_route` resources.
This gives Terraform an explicit dependency edge: route deleted before IGW/NAT GW is
detached. Inline routes caused 10+ minute destroy stalls.

### No null_resource Provisioners

All destroy ordering is handled by Terraform's dependency graph and built-in provider
waiters (`aws_ecs_service` waits for INACTIVE state, `aws_db_instance` waits for deletion).
`null_resource` destroy provisioners caused double-delete race conditions and have been removed.

---

## Outputs Reference

After `terraform apply`, run `terraform output` to see all values. Key outputs:

| Output                          | Description                                    |
| ------------------------------- | ---------------------------------------------- |
| `alb_dns_name`                  | ALB hostname — use as DNS CNAME target         |
| `acm_validation_cnames`         | DNS records needed to validate ACM certificate |
| `ecs_cluster_name`              | ECS cluster name                               |
| `ecr_repository_urls`           | Map of ECR URLs keyed by service name          |
| `rds_endpoint`                  | RDS hostname (also written to SSM)             |
| `rds_root_password_secret_name` | Secrets Manager secret name for RDS password   |
| `ecs_tasks_security_group_id`   | ECS tasks SG ID                                |

Full list: `infra/outputs.tf`

## Running Docker Images Locally

```bash
# Build and run health checks for all services (CI-style verification)
./infra/scripts/dev-docker.sh verify

# Build images only
./infra/scripts/dev-docker.sh build
./infra/scripts/dev-docker.sh build web

# Run a service in the foreground (Ctrl+C to stop)
./infra/scripts/dev-docker.sh run web        # http://localhost:3300
./infra/scripts/dev-docker.sh run api-order  # http://localhost:3301

# Remove local images
./infra/scripts/dev-docker.sh clean
```

The `verify` command builds, starts both containers in the background, hits `/api/health` on each, prints image sizes, then stops everything.

## Seeding Cognito Test Users

After `terraform apply`, create one test user per role using `seed-cognito.sh`:

```bash
# Add COGNITO_SEED_PASSWORD to infra/.env first, then:
./infra/scripts/seed-cognito.sh dev
./infra/scripts/seed-cognito.sh staging
```

The script is idempotent — safe to run multiple times. It creates:

| Username                      | Group     | Avatar              |
| ----------------------------- | --------- | ------------------- |
| `seed-admin@example.com`      | admin     | DiceBear avataaars  |
| `seed-moderator@example.com`  | moderator | DiceBear avataaars  |
| `seed-user@example.com`       | user      | DiceBear avataaars  |

**Requirements:**

- `terraform apply` must have been run first (User Pool must exist)
- `COGNITO_SEED_PASSWORD` set in `infra/.env` — min 8 chars, uppercase, lowercase, number, special char (e.g. `MyTestPass1!`)
- AWS credentials with Cognito admin permissions

---

## Pushing Docker Images to ECR

The `service` argument matches the folder name under `apps/`. The Dockerfile path and ECR repository URL are derived automatically.

```bash
# Build and push (most common)
./infra/scripts/build-and-push-ecr.sh <service> <env> [version]

./infra/scripts/build-and-push-ecr.sh web dev
./infra/scripts/build-and-push-ecr.sh api-order dev
./infra/scripts/build-and-push-ecr.sh web staging v1.2.3
./infra/scripts/build-and-push-ecr.sh api-order staging v1.2.3

# Push only (image already built locally)
./infra/scripts/push-ecr.sh <service> <env> [version]

./infra/scripts/push-ecr.sh web dev
./infra/scripts/push-ecr.sh api-order staging v1.2.3
```

**How it works:**

- `service` = folder name under `apps/` (e.g. `web` → `apps/web/`, `api-order` → `apps/api-order/`)
- Dockerfile path: `apps/<service>/Dockerfile`
- ECR URL: looked up from `terraform output ecr_repository_urls` (a map keyed by service name)
- Version defaults to the current git short SHA if not provided
- Both `:version` and `:latest` tags are pushed
