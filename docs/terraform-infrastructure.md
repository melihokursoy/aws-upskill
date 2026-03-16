# Terraform Infrastructure Documentation

## Overview

This document describes the AWS infrastructure for the aws-upskill project. All resources are
managed by Terraform and deployed to a single AWS account across two environments: `dev` and
`staging`. Infrastructure is defined in the `infra/` directory.

---

## Architecture Diagram

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                                  │
│                                                                     │
│  ┌─────────────────────────┐  ┌──────────────────────────┐         │
│  │  Public Subnet AZ1      │  │  Public Subnet AZ2        │         │
│  │  10.0.1.0/24            │  │  10.0.3.0/24              │         │
│  │  ┌───────────────────┐  │  │  (ALB only, no workloads) │         │
│  │  │  NAT Gateway      │  │  └──────────────────────────┘         │
│  │  └───────────────────┘  │                                        │
│  └─────────────────────────┘                                        │
│             │                                                        │
│  ┌──────────▼──────────────────────────────────────────────────┐   │
│  │  Application Load Balancer (internet-facing)                │   │
│  │  HTTPS :443 → path-based routing                            │   │
│  │    /api/*   → API target group (port 3301)                  │   │
│  │    /*       → Web target group (port 3300)                  │   │
│  │  HTTP :80   → redirect to HTTPS                             │   │
│  └──────────┬────────────────────┬──────────────────────────────┘  │
│             │                    │                                   │
│  ┌──────────▼────────┐  ┌────────▼──────────┐                      │
│  │  Private Subnet   │  │  Private Subnet   │                      │
│  │  AZ1              │  │  AZ2              │                      │
│  │  10.0.2.0/24      │  │  10.0.4.0/24      │                      │
│  │                   │  │  (RDS subnet      │                      │
│  │  ┌─────────────┐  │  │   group only)     │                      │
│  │  │ ECS Fargate │  │  └───────────────────┘                      │
│  │  │  web x2     │  │                                              │
│  │  │  api x2     │  │  ┌─────────────────────────────┐            │
│  │  └─────────────┘  │  │  RDS PostgreSQL 16 (AZ1)    │            │
│  │                   │  │  db.t3.micro, 20 GiB gp2    │            │
│  └───────────────────┘  └─────────────────────────────┘            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                    │ (outbound via NAT Gateway)
                    ▼
              Internet (ECR, CloudWatch, Secrets Manager, etc.)
```

---

## Module Structure

```
infra/
├── main.tf              # Root module — orchestrates all modules
├── variables.tf         # Input variables (no hardcoded values)
├── outputs.tf           # Aggregated outputs from all modules
├── backend.tf           # S3 + DynamoDB remote state configuration
├── envs/
│   ├── dev.tfvars       # Dev environment values
│   └── staging.tfvars   # Staging environment values
├── modules/
│   ├── vpc/             # VPC, subnets, IGW, NAT Gateway, route tables
│   ├── acm/             # ACM TLS certificate (DNS validation)
│   ├── alb/             # Application Load Balancer, listeners, target groups
│   ├── ecr/             # ECR repositories for web and API images
│   ├── iam/             # IAM roles and policies for ECS tasks
│   ├── ecs/             # ECS cluster, task definitions, services, SG
│   ├── rds/             # RDS PostgreSQL, security group, secrets
│   ├── ssm/             # Parameter Store entries for app configuration
│   ├── autoscaling/     # ECS auto-scaling policies (CPU + memory)
│   ├── monitoring/      # CloudWatch alarms and dashboard
│   └── budgets/         # AWS Budgets alerts
└── scripts/
    ├── deploy.sh            # Terraform plan/apply/destroy wrapper
    ├── build-and-push-ecr.sh # Build Docker images and push to ECR
    ├── force-cleanup.sh     # Manual cleanup for stuck terraform destroy
    └── test-connectivity.sh # Post-deploy health check script
```

### Module Dependencies

```
vpc ──────────────────────────────────────────────────────────┐
acm ──────────────────────────────────┐                       │
ecr ────────────────────────────┐     │                       │
rds ── (depends on vpc) ─────┐  │     │                       │
iam ── (depends on rds) ──┐  │  │     │                       │
                           ▼  ▼  ▼     ▼                       ▼
                          ecs alb ──> alb (SG rules in root) vpc
                           │
                    autoscaling, monitoring
```

Cross-module security group rules are defined in the **root module** (`main.tf`) as
`aws_security_group_rule` resources. This gives Terraform explicit dependency edges across
module boundaries, ensuring correct destroy ordering.

---

## VPC and Networking

### CIDR Layout

| Resource         | CIDR          | AZ      | Purpose                              |
|-----------------|---------------|---------|--------------------------------------|
| VPC             | 10.0.0.0/16   | -       | Network boundary                     |
| Public subnet 1 | 10.0.1.0/24   | AZ1     | ALB, NAT Gateway                     |
| Public subnet 2 | 10.0.3.0/24   | AZ2     | ALB second AZ (AWS requirement)      |
| Private subnet 1 | 10.0.2.0/24  | AZ1     | ECS tasks, RDS instance              |
| Private subnet 2 | 10.0.4.0/24  | AZ2     | RDS subnet group (AWS requirement)   |

### Routing

- **Public subnets**: route `0.0.0.0/0` → Internet Gateway via `aws_route.public_igw`
- **Private subnets**: route `0.0.0.0/0` → NAT Gateway via `aws_route.private_nat`
- Routes are separate `aws_route` resources (not inline in `aws_route_table`) so Terraform
  deletes routes before detaching the IGW/NAT GW during destroy.

### Security Groups

All cross-module SG rules are `aws_security_group_rule` resources in root `main.tf`:

| Rule                  | Source SG    | Destination SG | Port | Purpose             |
|-----------------------|-------------|----------------|------|---------------------|
| `alb_to_ecs_web`      | ALB SG      | ECS tasks SG   | 3300 | ALB → Next.js       |
| `alb_to_ecs_api`      | ALB SG      | ECS tasks SG   | 3301 | ALB → NestJS API    |
| `ecs_to_rds`          | ECS tasks SG | RDS SG        | 5432 | API → PostgreSQL    |

---

## Application Load Balancer

- **Type**: Internet-facing ALB across both public subnets
- **HTTPS listener** (port 443): ACM certificate (TLS 1.2+), path-based routing:
  - `/api/*` → API target group (port 3301)
  - `/*` → Web target group (port 3300)
- **HTTP listener** (port 80): 301 redirect to HTTPS
- **Health checks**:
  - Web: `GET /nextapi/health` — interval 30s, timeout 5s, 2 healthy / 2 unhealthy thresholds
  - API: `GET /api/health` — same intervals
  - Deregistration delay: 30s (graceful rolling deployment)
- **ALB SG**: ingress 80 and 443 from `0.0.0.0/0`; egress all to ECS tasks SG

---

## ECS Fargate Cluster

### Cluster

- Name: `{project}-{env}` (e.g. `aws-upskill-dev`)
- Container Insights enabled (CPU, memory, network metrics per task)
- Capacity providers: `FARGATE` (base=1) + `FARGATE_SPOT` (scale-out cost savings)

### Services

| Service | Image          | Port | Min tasks | Max tasks |
|---------|----------------|------|-----------|-----------|
| web     | ECR web repo   | 3300 | 2         | 4         |
| api     | ECR api-order repo | 3301 | 2     | 4         |

### Task Configuration (dev/staging)

| Resource | Value       |
|----------|-------------|
| CPU      | 256 units (0.25 vCPU) |
| Memory   | 512 MiB     |
| Network  | awsvpc mode, private subnet, no public IP |

### Rolling Deployment

- `minimumHealthyPercent`: 50 (keeps 1 of 2 tasks alive during deploy)
- `maximumPercent`: 200 (allows new task to start before old is stopped)
- `healthCheckGracePeriodSeconds`: 120
- Controller type: `ECS` (rolling, not blue/green)

### Container Health Checks

- Web: `wget -q -O- http://localhost:3300/nextapi/health`
- API: `wget -q -O- http://localhost:3301/api/health`
- Interval: 30s, timeout: 5s, retries: 3, start period: 60s

---

## Database (RDS PostgreSQL)

| Setting                | Value                              |
|-----------------------|------------------------------------|
| Engine                | PostgreSQL 16                      |
| Instance class        | db.t3.micro                        |
| Storage               | 20 GiB gp2, encrypted (AES-256)   |
| Multi-AZ              | false (cost optimization)          |
| Backups               | disabled (backup_retention = 0)    |
| Final snapshot        | skipped                            |
| Deletion protection   | false (allows `terraform destroy`) |
| Publicly accessible   | false                              |

### Parameter Group

Slow query logging enabled: queries >1000ms are logged to CloudWatch.
Connection/disconnection logging also enabled for pool debugging.

### Credentials

- Auto-generated 32-character password at provision time
- Stored in AWS Secrets Manager: `{project}/{env}/rds/postgres/root-password`
- Secret format: `{"username":"postgres","password":"...","host":"...","port":5432,"dbname":"appdb","engine":"postgres"}`
- ECS API task injects `DB_PASSWORD` via the `secrets` field in the task definition (ECS fetches it at container start)

---

## Auto-Scaling

Target tracking policies on both ECS services:

| Metric           | Target | Scale-out cooldown | Scale-in cooldown |
|-----------------|--------|--------------------|--------------------|
| CPU utilization | 70%    | 60s                | 300s               |
| Memory utilization | 80% | 60s                | 300s               |

Scale range: `min_task_count` → `max_task_count` (default: 2 → 4 per service)

---

## Monitoring

### CloudWatch Alarms

| Alarm                         | Threshold              | Evaluation |
|-------------------------------|------------------------|------------|
| `web-cpu-high`                | CPU > 80%              | 2 × 5 min  |
| `api-cpu-high`                | CPU > 80%              | 2 × 5 min  |
| `web-memory-high`             | Memory > 85%           | 2 × 5 min  |
| `api-memory-high`             | Memory > 85%           | 2 × 5 min  |
| `alb-unhealthy-targets`       | UnhealthyHostCount > 0 | 2 × 1 min  |
| `web-tasks-low`               | RunningTaskCount < min | 2 × 1 min  |
| `api-tasks-low`               | RunningTaskCount < min | 2 × 1 min  |

### CloudWatch Dashboard

Dashboard: `{project}-{env}` in CloudWatch console.

Panels:
- ECS CPU utilization (web + api), with 80% alert line
- ECS Memory utilization (web + api), with 85% alert line
- ECS Running Task Count (web + api), with min_task line
- ALB Request Count (total)
- ALB Response Time (p99)
- ALB Unhealthy Targets

### Log Groups

| Log Group              | Retention | Contents                  |
|------------------------|-----------|---------------------------|
| `/aws/ecs/web`         | 7 days    | Next.js stdout/stderr      |
| `/aws/ecs/api`         | 7 days    | NestJS stdout/stderr       |
| `/aws/alb/web-api`     | 7 days    | ALB access logs            |

> The Container Insights log group (`/aws/ecs/containerinsights/{cluster}/performance`) is
> auto-created by AWS and not managed by Terraform. It is deleted by `force-cleanup.sh`.

---

## IAM Roles

### Role Summary

| Role                         | Assumed by         | Purpose                                          |
|------------------------------|--------------------|--------------------------------------------------|
| `{project}-{env}-ecs-execution` | ECS agent       | Pull images from ECR, write logs to CloudWatch   |
| `{project}-{env}-ecs-task-web`  | Next.js container | S3, Secrets Manager (/web/*), SSM (/app/web/*), X-Ray |
| `{project}-{env}-ecs-task-api`  | NestJS container  | RDS connect, S3, Secrets Manager (RDS secret), SSM (/app/api/*), X-Ray |

### Execution Role Policies

- `AmazonECSTaskExecutionRolePolicy` (AWS managed) — ECR pull, CloudWatch Logs write
- Inline policy: `secretsmanager:GetSecretValue` on the RDS secret ARN (for container secret injection)

### Web Task Role Policies

| Policy              | Scope                                        |
|--------------------|----------------------------------------------|
| S3 read/write      | `{project}-{env}-*` bucket prefix            |
| Secrets Manager    | `{project}/{env}/web/*` (future web secrets) |
| Parameter Store    | `/app/web/*`                                 |
| X-Ray write        | `*` (traces + sampling)                      |

### API Task Role Policies

| Policy              | Scope                                          |
|--------------------|------------------------------------------------|
| S3 read/write      | `{project}-{env}-*` bucket prefix             |
| Secrets Manager    | Exact RDS secret ARN                           |
| Parameter Store    | `/app/api/*`                                   |
| RDS IAM connect    | Specific RDS instance + `postgres` user        |
| X-Ray write        | `*` (traces + sampling)                        |

> RDS IAM connect is included for future migration to IAM authentication. The API currently
> uses password authentication via the Secrets Manager secret.

---

## Secrets Management

### AWS Secrets Manager

| Secret name                                          | Managed by  | Contents                      |
|------------------------------------------------------|-------------|-------------------------------|
| `{project}/{env}/rds/postgres/root-password`         | Terraform   | RDS credentials (JSON)        |

The API container receives `DB_PASSWORD` injected by ECS at container start via the task
definition `secrets` field — the app never calls Secrets Manager directly for the password.

### AWS Parameter Store (SSM)

| Parameter path              | Value source          | Used by |
|-----------------------------|-----------------------|---------|
| `/app/api/db_host`          | RDS endpoint output   | API     |
| `/app/api/db_port`          | RDS port output       | API     |
| `/app/api/db_name`          | RDS name output       | API     |
| `/app/api/log_level`        | `log_level` tfvar     | API     |
| `/app/web/api_endpoint`     | ALB DNS name output   | Web     |
| `/app/web/log_level`        | `log_level` tfvar     | Web     |

The API reads config under `/app/api/*` at startup via `PARAMETER_STORE_PREFIX=/app/api`.

---

## Resource Tagging

Every resource receives these tags via `merge(var.tags, {...})`:

| Tag         | Value                    | Purpose                           |
|-------------|--------------------------|-----------------------------------|
| Environment | `dev` or `staging`       | Filter by environment in console  |
| Project     | `aws-upskill`            | Filter by project                 |
| ManagedBy   | `terraform`              | Identify IaC-managed resources    |
| Owner       | Team/individual name     | Ownership and accountability      |
| CostCenter  | e.g. `engineering`       | Cost allocation in Cost Explorer  |
| Name        | Per-resource name        | Human-readable label in console   |

To filter resources in the AWS Console: **EC2/RDS/etc → Tags → Filter by Environment=dev**.

Cost allocation tags are activated in **AWS Billing → Cost Allocation Tags** for
`Environment`, `Project`, `CostCenter`, `Owner`, `ManagedBy`.

---

## Cost Estimates (Dev Environment)

See [cost-tracking.md](./cost-tracking.md) for full breakdown (~$98.93/month for dev).

### AWS Budgets

Monthly budget alerts configured per environment at 50%, 75%, and 100% of `monthly_budget_amount`:

| Environment | Budget    | Alert email             |
|-------------|-----------|-------------------------|
| dev         | $50/month | configured in tfvars    |
| staging     | configured in staging.tfvars | - |

---

## Terraform State Management

State is stored remotely in S3 with DynamoDB locking. See [infra/README.md](../infra/README.md)
for backend setup details.

| Resource          | Name                                   |
|-------------------|----------------------------------------|
| S3 bucket         | `terraform-aws-upskill-state`          |
| DynamoDB table    | `terraform-aws-upskill-locks`          |
| State key         | `{env}/terraform.tfstate`              |
| Encryption        | AES-256 (S3 server-side)               |
| Versioning        | Enabled (state file recovery)          |
