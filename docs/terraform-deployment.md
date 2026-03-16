# Terraform Deployment Guide

## Prerequisites

| Tool         | Version   | Install                                     |
|-------------|-----------|---------------------------------------------|
| Terraform    | >= 1.6    | `brew install terraform`                    |
| AWS CLI      | >= 2.x    | `brew install awscli`                       |
| Docker       | any       | Required for building and pushing images    |
| jq           | any       | Required by `force-cleanup.sh`              |

### AWS Credentials

Configure credentials with access to the target AWS account:

```bash
aws configure
# or use a named profile:
export AWS_PROFILE=my-profile
```

The IAM user/role needs permissions to create/manage VPC, ECS, RDS, IAM, ALB, ECR, CloudWatch,
Secrets Manager, SSM, and Budgets resources.

### One-time Backend Setup

Before the first `terraform init`, the S3 bucket and DynamoDB table must exist:

```bash
# S3 state bucket
aws s3api create-bucket \
  --bucket terraform-aws-upskill-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket terraform-aws-upskill-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket terraform-aws-upskill-state \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-aws-upskill-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Deploying an Environment

### First Deploy

```bash
# Initialize (downloads providers, configures backend)
cd infra/
terraform init

# Review what will be created (~85 resources)
./scripts/deploy.sh dev plan

# Apply
./scripts/deploy.sh dev
```

### Subsequent Deploys

```bash
./scripts/deploy.sh dev plan   # review changes
./scripts/deploy.sh dev        # apply
```

### Staging

```bash
./scripts/deploy.sh staging plan
./scripts/deploy.sh staging
```

### Operations

```bash
./scripts/deploy.sh <env> plan     # terraform plan only
./scripts/deploy.sh <env>          # terraform apply (default)
./scripts/deploy.sh <env> destroy  # terraform destroy
```

The deploy script:
1. Validates `env` is `dev` or `staging`
2. Runs `terraform init` if `.terraform/` doesn't exist
3. Uses `envs/{env}.tfvars` for all variable values
4. Requires typing the environment name to confirm destroy

---

## Environment Configuration

Environment-specific values live in `infra/envs/`:

```hcl
# infra/envs/dev.tfvars
environment_name = "dev"
region           = "us-east-1"
project_name     = "aws-upskill"
owner            = "team"
cost_center      = "engineering"
domain_name      = "dev.yourdomain.com"

vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr    = "10.0.1.0/24"
public_subnet_cidr_2  = "10.0.3.0/24"
private_subnet_cidr   = "10.0.2.0/24"
private_subnet_cidr_2 = "10.0.4.0/24"
availability_zone     = "us-east-1a"
availability_zone_2   = "us-east-1b"

task_cpu       = 256
task_memory    = 512
min_task_count = 2
max_task_count = 4

log_retention_days = 7
log_level          = "info"

db_name           = "appdb"
db_instance_class = "db.t3.micro"

monthly_budget_amount = 50
budget_alert_email    = "team@example.com"
```

**Do not commit `terraform.tfvars`** — it is git-ignored and for local overrides only.

---

## Post-Deploy: DNS and HTTPS Setup

After the first apply, Terraform outputs ACM validation CNAME records that must be added to
your DNS provider before the certificate becomes valid:

```bash
terraform output acm_validation_cnames
```

Add those CNAME records in your DNS provider. Once validated, also add an ALB CNAME:

```bash
terraform output alb_dns_name
# → aws-upskill-dev-alb-1234567890.us-east-1.elb.amazonaws.com
```

Create a CNAME in your DNS: `dev.yourdomain.com` → `<alb_dns_name>`

---

## Deploying Application Images

### Build and Push to ECR

```bash
# Build and push web service
./scripts/build-and-push-ecr.sh web dev v1.0.0

# Build and push API service
./scripts/build-and-push-ecr.sh api-order dev v1.0.0
```

The script:
1. Retrieves ECR URLs from `terraform output`
2. Builds the Docker image for `linux/amd64`
3. Authenticates Docker with ECR
4. Pushes with both `:latest` and the version tag

### Force a New ECS Deployment

After pushing a new `:latest` image, force ECS to pull it:

```bash
CLUSTER=$(terraform -chdir=infra output -raw ecs_cluster_name)
ENV=dev

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "aws-upskill-${ENV}-web" \
  --force-new-deployment \
  --region us-east-1

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "aws-upskill-${ENV}-api" \
  --force-new-deployment \
  --region us-east-1
```

ECS performs a rolling deployment: one old task is replaced at a time, keeping at least one
healthy task running throughout.

---

## Scaling Tasks

### Temporary Manual Scale

```bash
aws ecs update-service \
  --cluster aws-upskill-dev \
  --service aws-upskill-dev-web \
  --desired-count 4 \
  --region us-east-1
```

> Note: Auto-scaling will override this once traffic normalises.

### Permanent Scale (via Terraform)

Change `min_task_count` and `max_task_count` in `envs/dev.tfvars`, then apply:

```bash
./scripts/deploy.sh dev
```

---

## Safe Infrastructure Change Procedures

### Low-Risk Changes (apply directly)

- CloudWatch alarm thresholds
- Log retention periods
- Budget alert amounts
- SSM parameter values
- IAM policy adjustments

### Requires Care

**Security group changes** — changing ports or sources affects live traffic immediately.
Always plan first and verify the change is scoped correctly.

**ECS task definition changes** — triggers a rolling deployment. New tasks start before old
ones stop. Ensure the new image is in ECR before applying.

**RDS parameter group changes** — some parameters require an instance reboot. Check the
`ApplyMethod` before applying.

### Destructive Changes (plan carefully)

**VPC CIDR / subnet changes** — require destroying and recreating the VPC. All resources
inside the VPC (ECS, RDS, ALB) will be recreated. Plan for downtime.

**RDS instance class change** — causes a brief outage during instance modification. Set a
maintenance window or accept the downtime.

**ACM certificate replacement** — if `domain_name` changes, the old certificate is deleted
and a new one must be validated via DNS before the ALB listener is updated.

---

## Rollback Procedures

### Application Rollback (image)

Push the previous image tag as `:latest` and force a new deployment:

```bash
# Re-tag a previous version as latest
docker pull <ecr-url>/web:v1.0.0
docker tag <ecr-url>/web:v1.0.0 <ecr-url>/web:latest
docker push <ecr-url>/web:latest

# Force ECS to pull it
aws ecs update-service --cluster ... --service ... --force-new-deployment
```

### Infrastructure Rollback (Terraform)

If a `terraform apply` causes issues, revert the code change in git and re-apply:

```bash
git revert HEAD
./scripts/deploy.sh dev
```

For a specific resource:

```bash
# Restore a single resource to its previous state
terraform apply -target=module.ecs.aws_ecs_service.web -var-file=envs/dev.tfvars
```

> Terraform state versions are stored in S3 with versioning enabled. To recover a previous
> state file: AWS Console → S3 → terraform-aws-upskill-state → dev/terraform.tfstate → Version history.

---

## Destroying an Environment

### Standard Destroy

```bash
./scripts/deploy.sh dev destroy
# Type "dev" to confirm
```

Terraform destroys resources in reverse dependency order. All destroy ordering is handled
by the dependency graph — no manual steps required under normal conditions.

### If Destroy Gets Stuck

Run the force-cleanup script first, then re-run destroy:

```bash
./scripts/force-cleanup.sh dev
./scripts/deploy.sh dev destroy
```

The force-cleanup script handles:
1. Deletes ALB (releases ALB ENIs, unblocks ALB security group)
2. Stops ECS tasks (releases Fargate ENIs)
3. Revokes cross-SG ingress rules
4. Deletes orphaned ENIs on the ECS tasks SG
5. Deletes RDS instance (waits for completion)
6. Deletes Container Insights log group (AWS-managed, not tracked by Terraform)

See [terraform-destroy.md](./terraform-destroy.md) for full destroy troubleshooting details.

---

## Monitoring Health and Accessing Logs

### Check ECS Service Health

```bash
aws ecs describe-services \
  --cluster aws-upskill-dev \
  --services aws-upskill-dev-web aws-upskill-dev-api \
  --region us-east-1 \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount,status:status}'
```

### View Container Logs

```bash
# Tail web service logs
aws logs tail /aws/ecs/web --follow --region us-east-1

# Tail API service logs
aws logs tail /aws/ecs/api --follow --region us-east-1

# Filter for errors
aws logs tail /aws/ecs/api \
  --filter-pattern "ERROR" \
  --follow \
  --region us-east-1
```

### CloudWatch Dashboard

AWS Console → CloudWatch → Dashboards → `aws-upskill-dev`

Shows: ECS CPU, ECS Memory, Running Task Count, ALB Request Count, ALB Latency p99,
ALB Unhealthy Targets.

### ALB Health Check Status

```bash
# Get target group ARNs
terraform -chdir=infra output web_target_group_arn
terraform -chdir=infra output api_target_group_arn

# Check health
aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region us-east-1
```

---

## Cost Tracking and Budget Management

See [cost-tracking.md](./cost-tracking.md) for full details.

### View Current Costs

AWS Console → Cost Explorer → filter by tag `Environment=dev`

### Budget Alerts

Configured at 50%, 75%, and 100% of `monthly_budget_amount`. Notification emails go to
`budget_alert_email` from `envs/{env}.tfvars`.

To update the budget limit:

```bash
# Edit envs/dev.tfvars
monthly_budget_amount = 75

# Apply
./scripts/deploy.sh dev
```

---

## Common Troubleshooting

### ECS Tasks Not Starting

1. Check service events: AWS Console → ECS → Service → Events tab
2. Check CloudWatch logs for the task: `/aws/ecs/web` or `/aws/ecs/api`
3. Common causes:
   - Image not in ECR (push the image first)
   - Secrets Manager secret not accessible (check IAM execution role)
   - RDS unreachable (check security group `ecs_to_rds` rule exists)
   - Out of memory (increase `task_memory` in tfvars)

### ALB Health Checks Failing

1. Check the health check path is reachable inside the container:
   ```bash
   # Web: GET /nextapi/health → should return 200
   # API: GET /api/health → should return 200
   ```
2. Check the container is actually listening on the right port (`3300` / `3301`)
3. Check security group `alb_to_ecs_web` and `alb_to_ecs_api` rules exist:
   ```bash
   terraform output ecs_tasks_security_group_id
   aws ec2 describe-security-groups --group-ids <id> --region us-east-1
   ```

### RDS Connection Refused

1. Verify `ecs_to_rds` security group rule: `infra/main.tf` → `aws_security_group_rule.ecs_to_rds`
2. Check RDS status:
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier aws-upskill-dev-postgres \
     --region us-east-1 \
     --query 'DBInstances[0].DBInstanceStatus'
   ```
3. Check the Secrets Manager secret has the correct password:
   ```bash
   terraform output rds_root_password_secret_name
   aws secretsmanager get-secret-value --secret-id <name> --region us-east-1
   ```

### Terraform State Lock Stuck

If a previous run was interrupted and left a lock:

```bash
# Find the lock ID
aws dynamodb scan \
  --table-name terraform-aws-upskill-locks \
  --region us-east-1

# Force-unlock (use the LockID from above)
terraform force-unlock <LOCK_ID>
```
