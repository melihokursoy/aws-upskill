# Cost Tracking Documentation

## Overview

This document covers monthly cost estimates, cost optimization strategies, and the cost monitoring
process for the aws-upskill project. All figures are us-east-1 pricing as of 2025 for the dev
environment.

The infrastructure runs two ECS Fargate services (Next.js web on port 3300, NestJS API on port
3301), backed by a single-AZ RDS PostgreSQL instance, an Application Load Balancer, a NAT Gateway,
ECR container registries, Secrets Manager, CloudWatch, and ACM.

---

## Cost Allocation Tags

Every AWS resource created by Terraform receives the following tags via `provider default_tags`.
These tags enable per-environment cost filtering in AWS Cost Explorer and AWS Budgets.

| Tag Key       | Example Value   | Purpose                                      |
|---------------|-----------------|----------------------------------------------|
| `Environment` | `dev`           | Isolate dev vs staging costs                 |
| `Project`     | `aws-upskill`   | Group all project resources together         |
| `ManagedBy`   | `terraform`     | Identify IaC-managed vs manual resources     |
| `Owner`       | `platform-team` | Attribute costs to a responsible team        |
| `CostCenter`  | `eng-training`  | Filter AWS Budgets by cost center            |

Tags are defined in `infra/main.tf` (`locals.common_tags`) and propagated to every module via the
`tags` variable. The `CostCenter` tag is the primary filter used by AWS Budgets (see
`infra/modules/budgets/main.tf`).

---

## Monthly Cost Breakdown by Service (Dev Environment, us-east-1)

### ECS Fargate

Task sizing: 256 CPU units (0.25 vCPU), 512 MB memory per task.
Minimum task count: 2 tasks per service (web + api = 4 tasks total).

**Pricing (us-east-1, 2025):**
- vCPU: $0.04048/vCPU-hour (FARGATE), $0.01218/vCPU-hour (FARGATE_SPOT)
- Memory: $0.004445/GB-hour (FARGATE), $0.001335/GB-hour (FARGATE_SPOT)

**Calculation assumes 70% FARGATE_SPOT, 30% standard FARGATE** (1 base task per service on
standard FARGATE, remaining tasks on SPOT).

Per task per month (720 hours):
- Standard FARGATE: (0.25 × $0.04048) + (0.5 × $0.004445) × 720 = $8.90/task/month
- FARGATE_SPOT: (0.25 × $0.01218) + (0.5 × $0.001335) × 720 = $2.68/task/month

4 tasks total (2 web + 2 api), mixed capacity:
- 2 base tasks on standard FARGATE: 2 × $8.90 = **$17.80**
- 2 remaining tasks on FARGATE_SPOT: 2 × $2.68 = **$5.36**

**ECS Fargate subtotal: ~$23.16/month**

> At maximum scale (4 tasks per service = 8 total), cost rises to approximately $50-55/month.

---

### Application Load Balancer (ALB)

**Pricing (us-east-1, 2025):**
- ALB fixed hourly charge: $0.008/LCU-hour (minimum $0.008/hour)
- ALB hourly: $0.0225/hour (fixed)
- LCU cost: $0.008/LCU-hour

For a dev environment with low traffic (assumed <1 GB/hour, <25 new connections/second):
- Fixed ALB charge: $0.0225 × 720 hours = **$16.20**
- LCU usage (1 LCU assumed at low traffic): $0.008 × 720 = **$5.76**

**ALB subtotal: ~$21.96/month**

---

### NAT Gateway (1x, us-east-1a)

All ECS tasks run in the private subnet and route outbound traffic (ECR pulls, CloudWatch Logs,
Secrets Manager) through a single NAT Gateway.

**Pricing (us-east-1, 2025):**
- Hourly charge: $0.045/hour
- Data processing: $0.045/GB

For a dev environment (assumed ~10 GB/month outbound for ECR pulls, logs, API calls):
- Hourly: $0.045 × 720 = **$32.40**
- Data processing: 10 GB × $0.045 = **$0.45**

**NAT Gateway subtotal: ~$32.85/month**

> NAT Gateway is typically the largest single cost driver in this architecture. Use VPC endpoints
> for ECR and CloudWatch Logs to reduce data processing charges (see Optimization Opportunities).

---

### RDS PostgreSQL (db.t3.micro, 20 GB gp2, Single-AZ)

**Pricing (us-east-1, 2025):**
- db.t3.micro On-Demand: $0.018/hour
- gp2 storage: $0.115/GB-month

Monthly cost:
- Instance: $0.018 × 720 = **$12.96**
- Storage: 20 GB × $0.115 = **$2.30**
- Backups: $0.00 (backup_retention_period = 0, backups disabled)

**RDS subtotal: ~$15.26/month**

---

### ECR (2 repositories)

ECR charges for storage and data transfer out of AWS. Data transfer to ECS within the same region
is free when using VPC endpoints for ECR (or minimal if routing through NAT Gateway).

**Pricing (us-east-1, 2025):**
- Storage: $0.10/GB-month
- Data transfer in: free

Assumed storage (2 repositories, ~10 tagged images each, ~500 MB compressed per image):
- ~5 GB total stored images

- Storage: 5 GB × $0.10 = **$0.50**
- ECR lifecycle policies keep only the last 10 tagged images and expire untagged images after
  1 day, capping storage growth.

**ECR subtotal: ~$0.50/month**

---

### Secrets Manager

1 secret: `{project}/{env}/rds/postgres/root-password`

**Pricing (us-east-1, 2025):**
- Per secret: $0.40/month
- API calls: $0.05 per 10,000 calls

For 4 ECS tasks reading the secret at startup + periodic rotations:
- Secret storage: **$0.40**
- API calls (low volume): **<$0.01**

**Secrets Manager subtotal: ~$0.40/month**

---

### CloudWatch (Logs, Alarms, Dashboard, Container Insights)

Components:
- 3 log groups: `/aws/ecs/web`, `/aws/ecs/api`, `/aws/alb/web-api` (7-day retention)
- 1 log group auto-created by Container Insights: `/aws/ecs/containerinsights/{cluster}/performance`
- 6 metric alarms (CPU high ×2, memory high ×2, unhealthy targets ×1, tasks low ×2)
- 1 CloudWatch dashboard
- Container Insights enabled on the ECS cluster

**Pricing (us-east-1, 2025):**
- Log ingestion: $0.50/GB
- Log storage: $0.03/GB-month (7-day retention keeps stored GB low)
- Metric alarms: $0.10/alarm/month (standard resolution)
- Dashboard: $3.00/month per dashboard
- Container Insights: $0.35/GB ingested metrics + $0.01 per 1,000 custom metrics

Estimated monthly:
- Log ingestion (assumed 2 GB/month across all groups): 2 GB × $0.50 = **$1.00**
- Log storage (rolling 7 days ≈ 0.5 GB stored on average): $0.03 × 0.5 = **$0.02**
- Alarms: 6 × $0.10 = **$0.60**
- Dashboard: **$3.00**
- Container Insights (assumed 0.5 GB metrics/month): $0.35 × 0.5 = **$0.18**

**CloudWatch subtotal: ~$4.80/month**

---

### AWS Budgets

1 budget per environment with 3 alert thresholds (50%, 75%, 100%).

**Pricing (us-east-1, 2025):**
- First 2 budgets: free
- Additional budgets: $0.02/day each
- Alert actions: $0.10/action/month

First budget is free. Alert notifications via email are free.

**AWS Budgets subtotal: $0.00/month**

---

### ACM Certificate

AWS Certificate Manager certificates for use with ALB are free.

**ACM subtotal: $0.00/month**

---

## Monthly Cost Summary

| Service             | Estimated Monthly Cost |
|---------------------|------------------------|
| ECS Fargate         | $23.16                 |
| ALB                 | $21.96                 |
| NAT Gateway         | $32.85                 |
| RDS PostgreSQL      | $15.26                 |
| ECR                 | $0.50                  |
| Secrets Manager     | $0.40                  |
| CloudWatch          | $4.80                  |
| AWS Budgets         | $0.00                  |
| ACM                 | $0.00                  |
| **Total (estimate)**| **~$98.93/month**      |

> All figures are estimates. Actual costs vary based on traffic volume, task scale-out events,
> NAT Gateway data transfer volume, and CloudWatch log ingestion rates. Monitor actuals in AWS
> Cost Explorer and compare against the configured budget.

---

## Cost Optimizations Already Implemented

### 1. FARGATE_SPOT Capacity Provider

Configured in `infra/modules/ecs/main.tf`. The cluster uses a mixed capacity provider strategy:
- 1 base task per service always runs on standard FARGATE (reliability floor).
- All additional tasks use FARGATE_SPOT, which is up to 70% cheaper than standard FARGATE.

FARGATE_SPOT prices vary by availability but are consistently 60-70% below on-demand in us-east-1.

### 2. Single-AZ RDS Deployment

`multi_az = false` in `infra/modules/rds/main.tf`. Multi-AZ would double the RDS instance cost
by running a synchronous standby replica in a second AZ. For dev/staging environments, single-AZ
is acceptable.

### 3. db.t3.micro Instance Class

The smallest available RDS instance class. At $0.018/hour it is approximately 89% cheaper than
db.r6g.large ($0.156/hour) commonly used in production.

### 4. RDS Backups Disabled

`backup_retention_period = 0` disables automated daily snapshots. RDS automated backup storage
is priced at $0.095/GB-month. For a 20 GB database this would add ~$1.90/month. Disabled for
dev/staging where data loss is acceptable.

### 5. 7-Day CloudWatch Log Retention

`log_retention_days = 7` (configurable via `var.log_retention_days`). AWS retains logs
indefinitely by default, which accumulates storage charges at $0.03/GB-month. 7-day retention
keeps stored log volume minimal.

### 6. No Performance Insights

`performance_insights_enabled = false` in `infra/modules/rds/main.tf`. Performance Insights
retention beyond 7 days costs $0.02/vCPU-month. Disabled for dev/staging to avoid unnecessary
cost.

### 7. ECR Lifecycle Policies

Both ECR repositories (`web`, `api-order`) have lifecycle policies (defined in
`infra/modules/ecr/main.tf`) that:
- Expire untagged (intermediate build) images after 1 day.
- Retain only the last 10 tagged releases per repository.

This caps ECR storage growth to roughly 10 images × ~500 MB = ~5 GB regardless of how frequently
images are pushed.

### 8. Minimum Task Count = 2

`min_task_count = 2` with `max_task_count = 4`. The auto-scaler (Target Tracking in
`infra/modules/autoscaling/main.tf`) only adds tasks when CPU or memory pressure demands it.
At idle, only 4 tasks total run across both services.

---

## Cost Optimization Opportunities (Not Yet Implemented)

### VPC Endpoints for ECR and CloudWatch

Adding Interface VPC Endpoints for `ecr.api`, `ecr.dkr`, `logs`, and `secretsmanager` would
route traffic from ECS tasks to these services over the AWS private network instead of through
the NAT Gateway. This eliminates NAT Gateway data processing charges for those services.

Estimated saving: $5-15/month depending on ECR pull frequency and log volume.
Endpoint cost: ~$0.01/hour × 4 endpoints = $28.80/month — net negative for dev; worth evaluating
for staging or production where data transfer volume is higher.

### Scheduled Scale-Down Outside Business Hours

The auto-scaler currently reacts to load but does not schedule scale-down during nights/weekends.
A scheduled action to reduce `min_task_count` to 1 outside business hours (e.g. 8pm-8am weekdays,
all weekend) could reduce ECS costs by 30-40%.

### RDS Stop/Start Schedule

AWS supports stopping RDS instances for up to 7 days at a time (they auto-restart after 7 days).
Stopping the dev RDS instance nights and weekends (16 hours/day × 5 days + 48 hours weekend = ~128
hours stopped/week) would save approximately 70% of the RDS instance cost — reducing it from
$12.96 to ~$3.89/month.

---

## Viewing Costs in AWS Cost Explorer

### Filter by Environment Tag

1. Open [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home#/cost-explorer).
2. Set the date range to the current or previous month.
3. Click **Filters** in the top-right panel.
4. Select **Tags** > **Environment** > choose `dev` or `staging`.
5. Group by **Service** to see per-service breakdown.

### Filter by CostCenter Tag

1. In Cost Explorer, click **Filters**.
2. Select **Tags** > **CostCenter** > enter the value set in `var.cost_center` (e.g.
   `eng-training`).
3. This matches the filter used by the AWS Budget in `infra/modules/budgets/main.tf`.

### Useful Cost Explorer Views

| View                          | How to configure                                              |
|-------------------------------|---------------------------------------------------------------|
| Per-service breakdown         | Group by: Service; Filter: Environment = dev                  |
| Daily spend trend             | Granularity: Daily; Group by: Service                         |
| Environment comparison        | Group by: Tag: Environment (compare dev vs staging side by side) |
| NAT Gateway data charges      | Filter: Service = EC2-Other; Group by: Usage Type            |

> Note: Tags on resources must be activated as Cost Allocation Tags in the Billing console before
> they appear in Cost Explorer. Navigate to **Billing > Cost allocation tags** and activate
> `Environment`, `Project`, `ManagedBy`, `Owner`, and `CostCenter`.

### Activating Cost Allocation Tags

Tags are not automatically available in Cost Explorer. To activate them:

1. Go to **AWS Billing Console** > **Cost allocation tags**.
2. Under **User-defined cost allocation tags**, find each tag (`Environment`, `Project`,
   `ManagedBy`, `Owner`, `CostCenter`).
3. Select all five and click **Activate**.
4. Tags become visible in Cost Explorer within 24 hours.

---

## AWS Budgets Configuration

The budget is provisioned via Terraform in `infra/modules/budgets/main.tf`. It:

- Tracks actual (not forecasted) monthly spend.
- Filters spend to the environment's `CostCenter` tag value.
- Sends email alerts to `var.budget_alert_email` at 50%, 75%, and 100% of the monthly limit.
- `var.monthly_budget_amount` sets the threshold (configured per environment in
  `infra/envs/dev.tfvars`).

**Recommended budget amounts:**
- Dev: $120/month (provides ~20% buffer above the ~$99 baseline estimate)
- Staging: $150/month (accounts for more frequent deployments and higher load testing)

**Alert thresholds:**
- 50% (~$60): Early warning — investigate if mid-month spend is unexpectedly high.
- 75% (~$90): Review running tasks, NAT Gateway data transfer, and any unexpected services.
- 100% ($120): Immediate action — check for runaway tasks, data transfer spikes, or misconfigured
  resources.

---

## Quarterly Cost Review Process

Perform a cost review at the start of each quarter (January, April, July, October).

### Step 1 — Pull the Previous Quarter's Actuals

1. Open AWS Cost Explorer.
2. Set date range to the previous 3 months.
3. Filter by `Environment` tag and group by Service.
4. Export the CSV for the record.

### Step 2 — Compare Actuals Against Estimates

Compare each service line against the estimates in the Monthly Cost Summary table above.
Investigate any service that is >20% over estimate.

Common causes of overrun:
- NAT Gateway: higher than expected ECR pull frequency or CloudWatch log volume.
- ECS Fargate: scale-out events sustained longer than expected; review auto-scaling thresholds.
- RDS: storage autoscaling triggered (if enabled); review `allocated_storage`.
- CloudWatch: log ingestion higher than expected; review application log verbosity.

### Step 3 — Review and Adjust Budget Thresholds

If actual spend has consistently been 10-20% below budget, consider lowering the budget to tighten
the alert signal. If spend is approaching the 75% threshold regularly, raise the budget or
implement the scale-down/stop optimizations described above.

Update `monthly_budget_amount` in `infra/envs/dev.tfvars` and apply with:

```bash
terraform -chdir=infra apply -var-file=envs/dev.tfvars
```

### Step 4 — Review Optimization Opportunities

Revisit the Optimization Opportunities section each quarter. As traffic patterns stabilize, the
ROI on VPC Endpoints and scheduled scale-down actions may become positive.

### Step 5 — Tag Compliance Audit

Verify that all running resources have the expected cost allocation tags:

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=aws-upskill \
  --region us-east-1 \
  --query 'ResourceTagMappingList[*].{ARN:ResourceARN,Tags:Tags}' \
  --output table
```

Any resource missing `Environment`, `CostCenter`, or `Project` tags will not be counted in the
budget filter and will appear as untagged spend in Cost Explorer.

---

## Implementation Details

### Tag Configuration

Tags are defined in `infra/main.tf`:

```hcl
locals {
  common_tags = {
    Environment = var.environment_name
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}
```

All modules receive `tags = local.common_tags` and merge additional resource-specific tags
(e.g. `Name`, `Service`) using `merge(var.tags, { ... })`.

### Budget Filter

The budget in `infra/modules/budgets/main.tf` uses a `TagKeyValue` cost filter:

```hcl
cost_filter {
  name   = "TagKeyValue"
  values = ["user:CostCenter${var.cost_center}"]
}
```

This means only resources tagged with the matching `CostCenter` value are counted against the
budget. Resources without this tag are excluded from budget tracking even if they belong to the
same AWS account.

### Relevant Terraform Files

| File                                       | Relevance                                     |
|--------------------------------------------|-----------------------------------------------|
| `infra/main.tf`                            | `common_tags` definition, module wiring       |
| `infra/variables.tf`                       | `cost_center`, `monthly_budget_amount` vars   |
| `infra/modules/budgets/main.tf`            | AWS Budgets resource and alert thresholds     |
| `infra/modules/ecs/main.tf`                | FARGATE_SPOT capacity provider, task sizing   |
| `infra/modules/rds/main.tf`                | Single-AZ, no backups, no Performance Insights|
| `infra/modules/ecr/main.tf`                | Lifecycle policies for image expiry           |
| `infra/modules/monitoring/main.tf`         | CloudWatch alarms and dashboard               |
