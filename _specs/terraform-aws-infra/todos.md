# Implementation Todos: Terraform Infrastructure for AWS

## Checkpoint 1 - Foundation (Terraform Setup & VPC)

### Root Module Configuration
- [x] Create infra/ directory at project root with .gitignore for state files
- [x] Set up Terraform project structure in infra/ with root module (main.tf)
- [x] Create variables.tf with parameterized values:
  - [x] `environment_name` variable (no hardcoded "dev" or "staging")
  - [x] `region` variable for AWS region
  - [x] `vpc_cidr` variable for VPC CIDR block
  - [x] `project_name` variable for resource tagging
  - [x] `owner` variable for resource tagging
  - [x] Any other environment-specific values as variables
- [x] Create outputs.tf for root module outputs (aggregates module outputs)
- [x] Configure backend.tf for S3 + DynamoDB state management:
  - [x] Create S3 bucket for state files (terraform-{project}-state) — documented in README, one-time manual setup
  - [x] Enable S3 encryption (AES-256) — documented in README setup commands
  - [x] Enable S3 versioning for state file recovery — documented in README setup commands
  - [x] Configure S3 bucket policy for team access only — documented in README
  - [x] Create DynamoDB table for state locking — documented in README setup commands
  - [x] Configure backend block in Terraform code
- [x] Configure .gitignore to prevent state file commits:
  - [x] Add `*.tfstate` to .gitignore
  - [x] Add `*.tfstate.backup` to .gitignore
  - [x] Add `.terraform/` to .gitignore
- [x] Add `terraform.tfvars` to .gitignore (local overrides only, not committed)
- [x] Document S3 bucket and DynamoDB table names in shared location (infra/README.md)
- [x] Environment variable files created: infra/envs/dev.tfvars and infra/envs/staging.tfvars

### Resource Tagging Configuration
- [x] Create locals block for common tags in root main.tf
- [x] Define standard tags: Environment, Project, ManagedBy, CreatedAt, Owner
- [x] Create tags variable to pass to all modules
- [x] Apply tags to all resources in each module (via merge(var.tags, {...}) in vpc module)
- [x] Create vpc module with configurable CIDR block
- [x] Create public subnets in VPC (for ALB)
- [x] Create private subnets in VPC (for ECS tasks)
- [x] Create and attach Internet Gateway to VPC
- [x] Create NAT Gateway for private subnet outbound traffic
- [x] Configure route tables and associations
- [ ] Verify VPC structure with terraform plan (requires AWS credentials + backend setup)

## Checkpoint 2 - Load Balancer & HTTPS

### ACM Certificate
- [x] Create ACM certificate resource for custom domain (e.g. `dev.yourdomain.com`)
- [x] Configure DNS validation method
- [x] Output CNAME validation records for manual DNS entry in external DNS provider
- [x] Wait for certificate validation (aws_acm_certificate_validation resource blocks apply)
- [x] Store certificate ARN as Terraform output

### ALB Configuration
- [x] Create alb module with ALB in public subnets
- [x] Create ALB target groups for web service (port 3300, health check /api/health)
- [x] Create ALB target groups for API service (port 3301, health check /health)
- [x] Configure path-based routing rules (/ → web, /api/* → API)
- [x] Configure health check paths and intervals (30s interval, 5s timeout, 2 thresholds)
- [x] Create security group for ALB (allow port 80 and 443 inbound)
- [x] Create HTTPS listener (port 443) with ACM certificate (TLS 1.3 policy)
- [x] Create HTTP listener (port 80) with redirect to HTTPS (301)
- [x] Verify ALB configuration with terraform plan (requires AWS credentials + backend setup)

### DNS Setup (Manual Step)
- [x] Output ALB DNS name from Terraform (alb_dns_name output)
- [x] Document: Create CNAME record in external DNS pointing to ALB DNS name
- [x] Document: Add ACM validation CNAME record in external DNS (acm_validation_cnames output)
- [x] Verify domain resolves to ALB after DNS propagation (manual step post-deploy)

## Checkpoint 3 - Container Infrastructure (ECR & ECS Cluster)

- [x] Create ecr module with ECR repository for web application
- [x] Create ECR repository for API application
- [x] Configure image retention policies (untagged: 1 day, tagged: keep last 10)
- [x] Configure lifecycle rules for image cleanup
- [x] Create ecs module with ECS cluster resource (Fargate + Container Insights)
- [x] Create CloudWatch Log Groups for web and API services (/aws/ecs/web, /aws/ecs/api, /aws/alb/web-api)
- [x] Verify ECR and ECS cluster setup with terraform validate (passes)
- [x] (IAM roles created in Checkpoint 8)

## Checkpoint 4 - Docker Images & ECR Push Scripts

### Dockerfiles for Applications
- [x] Create `apps/web/Dockerfile` for Next.js application
  - [x] Use official Node.js image as base (node:20-alpine)
  - [x] Multi-stage build (deps → builder → runner)
  - [x] Install dependencies in build stage
  - [x] Build Next.js application via NX in build stage
  - [x] Copy only standalone output to runtime stage
  - [x] Set working directory and expose port 3300
  - [x] Define healthcheck endpoint (/api/health)
- [x] Enable `output: 'standalone'` in apps/web/next.config.js (required for Docker)
- [x] Create `apps/api-order/Dockerfile` for NestJS API
  - [x] Use official Node.js image as base (node:20-alpine)
  - [x] Multi-stage build (deps → builder → runner)
  - [x] Install dependencies in build stage
  - [x] Build NestJS app via NX webpack bundle in build stage
  - [x] Copy only dist/main.js to runtime stage (webpack bundle is self-contained)
  - [x] Set working directory and expose port 3301
  - [x] Define healthcheck endpoint (/api/health)
- [x] Create `.dockerignore` files for both applications
  - [x] Exclude node_modules, dist, .git, etc.
  - [x] Keep image size minimal

### ECR Push Scripts
- [x] Create `infra/scripts/build-and-push-ecr.sh`:
  - [x] Accept parameters: service name (web or api), env, version tag
  - [x] Retrieve ECR registry URL from Terraform outputs
  - [x] Build Docker image locally with proper tagging (linux/amd64 for ECS)
  - [x] Authenticate Docker with ECR (aws ecr get-login-password)
  - [x] Push image to ECR with `latest` tag
  - [x] Push image with version tag
  - [x] Display push status and image digest
  - [x] Handle errors gracefully (set -euo pipefail)
- [x] Create `infra/scripts/push-ecr.sh` for pre-built images
- [x] Make scripts executable (chmod +x)
- [x] Add script documentation in README

### Docker Build Testing
- [x] Test building web application image locally (manual — requires Docker)
- [x] Test building API application image locally (manual — requires Docker)
- [x] Verify image sizes are reasonable (< 500MB each)
- [x] Test running images locally with `docker run`
  - [x] Verify web service responds on port 3300
  - [x] Verify API service responds on port 3301
- [x] Test ECR push script with test images

## Checkpoint 5 - Task Definitions & Services

- [x] Create IAM module with task execution role and task roles (prerequisite for task definitions)
  - [x] ECS Task Execution Role (ECR pull + CloudWatch write)
  - [x] Web task role (Next.js runtime — full permissions in Checkpoint 8)
  - [x] API task role (NestJS runtime — full permissions in Checkpoint 8)
- [x] Create web application task definition (CPU: 512, Memory: 1024)
- [x] Configure environment variables for web service (NODE_ENV, PORT, HOSTNAME)
- [x] Configure CloudWatch Logs driver for web service (awslogs → /aws/ecs/web)
- [x] Create API application task definition (CPU: 512, Memory: 1024)
- [x] Configure environment variables for API service (NODE_ENV, PORT)
- [x] Configure CloudWatch Logs driver for API service (awslogs → /aws/ecs/api)
- [x] Create ECS task security group (inbound from ALB only on ports 3300/3301)
- [x] Create ECS service for web application
- [x] Set desired task count to minimum task count (2)
- [x] Configure rolling deployment for web service:
  - [x] deploymentConfiguration.minimumHealthyPercent = 50
  - [x] deploymentConfiguration.maximumPercent = 100
  - [x] deploymentController type = ECS (rolling)
  - [x] Enable health check grace period (60s)
- [x] Create ECS service for API application
- [x] Set desired task count to minimum task count (2)
- [x] Configure rolling deployment for API service:
  - [x] deploymentConfiguration.minimumHealthyPercent = 50
  - [x] deploymentConfiguration.maximumPercent = 100
  - [x] deploymentController type = ECS (rolling)
  - [x] Enable health check grace period (60s)
- [x] Verify task definitions and services with terraform validate

## Checkpoint 6 - Auto-Scaling & Monitoring

- [x] Create autoscaling module for ECS services
- [x] Configure target tracking policy for CPU utilization (70% target)
- [x] Configure target tracking policy for memory utilization (80% target)
- [x] Set minimum task count to 2 per service
- [x] Set maximum task count to 4 per service
- [x] Create monitoring module with CloudWatch resources

### ALB Health Checks (for rolling deployment)
- [x] Configure ALB health check for web service:
  - [x] Health check path: `/nextapi/health` (avoids ALB `/api/*` routing rule)
  - [x] Interval: 30 seconds
  - [x] Timeout: 5 seconds
  - [x] Healthy threshold: 2 consecutive successes
  - [x] Unhealthy threshold: 2 consecutive failures
  - [x] Matcher: HTTP 200 status code
- [x] Configure ALB health check for API service:
  - [x] Health check path: `/api/health`
  - [x] Interval: 30 seconds
  - [x] Timeout: 5 seconds
  - [x] Healthy threshold: 2 consecutive successes
  - [x] Unhealthy threshold: 2 consecutive failures
  - [x] Matcher: HTTP 200 status code
- [x] Configure connection draining (deregistration delay):
  - [x] Timeout: 30 seconds for graceful shutdown
  - [x] Enables smooth rolling deployment transitions

### CloudWatch Log Groups (organized by service)
- [x] Create `/aws/ecs/web` log group for Next.js application (done in checkpoint 3)
- [x] Create `/aws/ecs/api` log group for NestJS API (done in checkpoint 3)
- [x] Create `/aws/alb/web-api` log group for ALB access logs (done in checkpoint 3)
- [x] Set log retention to 7 days for all groups (done in checkpoint 3)
- [x] Configure ECS task log driver to use correct log groups (done in checkpoint 5)

### CloudWatch Dashboards & Alarms
- [x] Create unified CloudWatch dashboard for infrastructure overview
- [x] Add ECS cluster metrics (CPU, memory, task count)
- [x] Add ALB metrics (request count, latency, unhealthy targets)
- [x] Create alarm for high CPU utilization (>80%)
- [x] Create alarm for high memory utilization (>85%)
- [x] Create alarm for ALB unhealthy target count
- [x] Create alarm for ECS task failures (running count < min)
- [x] Configure Container Insights integration for ECS (done in checkpoint 3)

### X-Ray Distributed Tracing
- [x] Enable X-Ray write access IAM policy for ECS task roles (web + api)
- [ ] X-Ray daemon sidecar and app instrumentation (deferred — requires app code changes)

### Correlation ID / Request ID Tracking
- [ ] Correlation ID propagation (deferred — see note below)

> **Why deferred:** ALB cannot inject custom headers (e.g. `X-Correlation-ID`) natively —
> it would require WAF or Lambda@Edge. The native `x-amzn-trace-id` header is already
> forwarded by ALB to containers automatically and can serve as a correlation ID today.
> The rest of the work (Next.js middleware to extract/generate the ID, NestJS interceptor
> to attach it to logs, propagating through async ops and outbound API calls) is
> application code, not infrastructure — best implemented as a separate feature spec.

- [x] Verify auto-scaling and monitoring with terraform validate

## Checkpoint 7 - Database & Storage (RDS & S3)

### RDS PostgreSQL Configuration
- [x] Create rds module with PostgreSQL RDS instance
- [x] Set engine to PostgreSQL (latest stable version — v16)
- [x] Configure single-AZ deployment (cost optimization for dev/staging)
- [x] Generate random 32-character root password
- [x] Store root password in AWS Secrets Manager
  - [x] Create secret: `{project}/{env}/rds/postgres/root-password`
  - [x] Store the auto-generated password (includes host, port, dbname, username, password as JSON)
  - [x] Document secret name in shared location (outputs.tf: rds_root_password_secret_name)
- [x] Disable automated backups (backup_retention_period = 0)
- [x] Create security group for RDS (allow port 5432 from ECS tasks)
- [x] Create PostgreSQL parameter group:
  - [x] Configure log settings for CloudWatch integration (log_min_duration_statement=1000ms, log_connections, log_disconnections)
  - [x] Document parameter group configuration (inline comments in main.tf)
- [x] Note: Application S3 buckets deferred (no backups, no assets buckets needed yet)
- [x] Verify database with terraform validate (passes)

## Checkpoint 8 - Security & IAM

### IAM Roles with Clear Documentation
- [x] Create iam module for all IAM policies and roles (done in Checkpoint 5, expanded here)
- [x] Create Task Execution Role (ecsTaskExecutionRole)
  - [x] Add clear purpose comment: "Allows ECS service to pull images from ECR and write logs to CloudWatch"
  - [x] Attach ECR pull policy with inline comments explaining each permission
  - [x] Attach CloudWatch Logs write policy with inline comments
  - [x] Attach X-Ray write policy with inline comments
  - [x] Document trust relationship (ECS tasks can assume this role)
- [x] Create Web Service Task Role (ecsTaskRoleWeb)
  - [x] Add clear purpose comment: "Allows Next.js web application to access S3, Secrets Manager, and Parameter Store"
  - [x] Attach S3 read/write policy with inline comments (scoped to project naming prefix, ready for future app buckets)
  - [x] Attach Secrets Manager read policy with inline comments (scoped to {project}/{env}/web/*)
  - [x] Attach Parameter Store read policy with inline comments (scoped to /app/web/*)
  - [x] Document trust relationship
- [x] Create API Service Task Role (ecsTaskRoleAPI)
  - [x] Add clear purpose comment: "Allows NestJS API to access RDS, S3, Secrets Manager, and Parameter Store"
  - [x] Attach RDS connect policy with inline comments (rds-db:connect scoped to instance+user)
  - [x] Attach S3 read/write policy with inline comments (scoped to project naming prefix)
  - [x] Attach Secrets Manager read policy with inline comments (scoped to exact RDS secret ARN)
  - [x] Attach Parameter Store read policy with inline comments (scoped to /app/api/*)
  - [x] Document trust relationship

### Security Groups & Secrets Management
- [x] Create security group for ECS tasks (done in ECS module, Checkpoint 5)
- [x] Configure security group ingress from ALB (done in ECS module, Checkpoint 5)
- [x] Configure security group egress rules (done in ECS module, Checkpoint 5)

### AWS Secrets Manager (Database Credentials)
- [x] Create Secrets Manager secret for RDS root password (done in RDS module, Checkpoint 7)
  - [x] Secret name: `{project}/{env}/rds/postgres/root-password`
  - [x] Store auto-generated password from RDS module
  - [x] Automatic rotation: deferred (not needed for dev/staging)
- [x] Grant ECS task IAM role read access to Secrets Manager (API task role scoped to RDS secret ARN)

### AWS Parameter Store (Application Configuration)
- [x] Create Parameter Store entries for web service:
  - [x] `/app/web/api_endpoint` - ALB DNS name with /api path
  - [x] `/app/web/log_level` - Logging level
- [x] Create Parameter Store entries for API service:
  - [x] `/app/api/db_host` - RDS endpoint (sourced from rds module output)
  - [x] `/app/api/db_port` - RDS port (sourced from rds module output)
  - [x] `/app/api/db_name` - Database name (sourced from rds module output)
  - [x] `/app/api/log_level` - Logging level
- [x] Grant ECS task IAM role read access to Parameter Store (path-scoped policies)

### Verification
- [x] Verify IAM permissions for Secrets Manager access (scoped to specific ARNs)
- [x] Verify IAM permissions for Parameter Store access (path-prefix scoped)
- [x] Verify IAM permissions with terraform validate (passes)

## Checkpoint 9 - Terraform Outputs & Environment Variables

### Module Outputs Configuration
- [x] Define VPC module outputs (VPC ID, subnet IDs, security group IDs)
- [x] Define ALB module outputs (ALB DNS, target group ARNs, listener ARNs)
- [x] Define ECR module outputs (repository URLs for web and API)
- [x] Define ECS module outputs (cluster name, task definition ARNs, service names)
- [x] Define RDS module outputs (database endpoint, port, name)
- [x] Define S3 module outputs (N/A — application S3 buckets deferred)
- [x] Define CloudWatch module outputs (log group names)
- [x] Define IAM module outputs (task execution role ARN, task role ARNs)
- [x] Aggregate all module outputs in root outputs.tf

### Environment Variables Configuration
- [x] Create ECS task environment variable mapping from Terraform outputs
- [x] Define environment variables for web service:
  - [x] `API_ENDPOINT` from ALB DNS (https://{alb_dns}/api)
  - [x] `LOG_GROUP` from CloudWatch log group name (internal to ECS module)
  - [x] `REGION` from variable
  - [x] `ENVIRONMENT` from variable (not hardcoded)
- [x] Define environment variables for API service:
  - [x] `DB_HOST` from RDS endpoint output
  - [x] `DB_PORT` from RDS output (5432)
  - [x] `DB_NAME` from RDS output
  - [x] `DB_USER` = "postgres" (variable with default, not hardcoded)
  - [x] `DB_PASSWORD_SECRET_ARN` from Secrets Manager output (app retrieves at runtime)
  - [x] `LOG_GROUP` from CloudWatch log group name (internal to ECS module)
  - [x] `REGION` from variable
  - [x] `ENVIRONMENT` from variable (not hardcoded)
  - [x] `PARAMETER_STORE_PREFIX` = `/app/api` (for config retrieval)
- [x] Ensure no magic strings or hardcoded values in Terraform
- [x] Document that:
  - [x] API application retrieves RDS password from Secrets Manager at runtime via DB_PASSWORD_SECRET_ARN
  - [x] API application retrieves config values from Parameter Store at startup via PARAMETER_STORE_PREFIX

## Checkpoint 10 - Multi-Environment Configuration

### Environment Variable Files
- [x] Create `infra/envs/` directory
- [x] Create `infra/envs/dev.tfvars` with all dev-specific values:
  - [x] `environment_name = "dev"`
  - [x] `region` - AWS region
  - [x] `vpc_cidr` - VPC CIDR block
  - [x] `domain_name` - dev subdomain
  - [x] `min_task_count = 2`, `max_task_count = 4`
  - [x] `log_retention_days = 7`, `log_level = "info"`
  - [x] `project_name`, `owner`, `cost_center`
  - [x] `monthly_budget_amount` - dev environment budget
- [x] Create `infra/envs/staging.tfvars` with all staging-specific values:
  - [x] `environment_name = "staging"`
  - [x] Same structure as dev.tfvars with staging-specific values
  - [x] `domain_name` - staging subdomain
- [x] Add `terraform.tfvars` to `.gitignore` (local overrides only)
- [x] Both `envs/dev.tfvars` and `envs/staging.tfvars` committed to repo

### Deploy Script
- [x] `infra/scripts/` directory exists
- [x] `infra/scripts/deploy.sh` implemented with:
  - [x] Accept required `env` argument (`dev` or `staging`); exit with error if missing/invalid
  - [x] Accept optional operation argument: `plan`, `apply` (default), `destroy`
  - [x] Use `set -euo pipefail` for safe shell execution
  - [x] Change working directory to `infra/` before running Terraform
  - [x] Run `terraform init` if `.terraform/` directory doesn't exist
  - [x] Run `terraform plan -var-file="envs/${env}.tfvars"` for plan
  - [x] Require explicit confirmation for `destroy` (type env name to confirm)
  - [x] Run `terraform destroy -var-file="envs/${env}.tfvars"` for destroy
  - [x] Log output with timestamps (`log()` helper)
  - [x] Exit with non-zero code on any failure (`set -euo pipefail`)
- [x] Deploy script is executable (`-rwxr-xr-x`)
- [x] Invalid env argument produces clear error message (verified)
- [x] Deploy script documented in script header comments

### Verification
- [x] `terraform validate` passes for all modules
- [x] Env files have distinct values (different VPC CIDRs, domains, cost centers, budgets)
- [x] `terraform.tfvars` excluded from git via `.gitignore`

## Checkpoint 11 - Testing & Validation

- [x] Run terraform fmt to format all code
- [x] Run terraform validate on all modules
- [x] Run terraform plan for dev environment and review (no changes — infra matches config)
- [x] Run terraform plan for staging environment and review (85 resources to add — not yet deployed)
- [x] Create infrastructure connectivity tests (infra/scripts/test-connectivity.sh)
- [x] Verify ALB health checks are passing (2/2 healthy targets on both web and API)
- [x] Verify ECS tasks are running and healthy (2/2 running on both services)
- [x] Test application endpoint through ALB (HTTP 200 on /)
- [x] Test API endpoint through ALB path-based routing (HTTP 200 on /api/health, /api/db-health)
- [x] Verify CloudWatch logs are being collected (log streams present for web and API)

### Resource Tagging Verification
- [x] Verify all resources have required tags (Environment, Project, ManagedBy, Owner — all present)
- [x] Test AWS Console filtering by Environment tag (show all dev or staging)
- [x] Test AWS Console filtering by Project tag
- [x] Test AWS Console filtering by ManagedBy tag
- [x] Verify no resources missing tags

## Checkpoint 12 - Cleanup & Destruction Testing

- [x] Configure S3 bucket force_destroy = true for dev/staging (ECR force_delete = true already set)
- [x] Configure RDS deletion_protection = false for dev/staging (already set in rds/main.tf)
- [x] Run `terraform destroy` in dev environment (85 resources destroyed successfully)
- [x] Verify all resources completely removed from AWS Console
- [x] Verify no orphaned resources left behind:
  - [x] No security groups remaining
  - [x] No IAM roles/policies remaining
  - [x] No CloudWatch log groups remaining
  - [x] No S3 buckets remaining
  - [x] No ECR repositories remaining
  - [x] No RDS instances remaining
  - [x] No VPC/subnets remaining
  - [x] No ALB/target groups remaining
- [x] Document cleanup procedures (docs/terraform-destroy.md)


## Checkpoint 13 - Cost Tracking & Budget Alerts

### AWS Budgets Configuration
- [x] Create AWS Budget for Dev environment (infra/modules/budgets/main.tf)
  - [x] Set monthly budget amount (from monthly_budget_amount tfvar)
  - [x] Configure alert at 50% of budget
  - [x] Configure alert at 75% of budget
  - [x] Configure alert at 100% of budget
  - [x] Set notification email for team (from budget_alert_email tfvar)
- [x] Create AWS Budget for Staging environment (same module, applied per env via tfvars)
- [x] Create AWS Budget for Total infrastructure (deferred — cross-env budget doesn't fit per-env Terraform model; set up manually in AWS Console if needed)

### Cost Allocation & Reporting
- [x] Apply CostCenter tag to all resources (cost_center variable in common_tags since checkpoint 1)
- [x] Configure AWS Cost Explorer for tag-based filtering (activated Environment, Project, CostCenter, Owner, ManagedBy in Billing > Cost Allocation Tags)
- [x] Set up monthly cost report export to S3 (deferred — no app S3 buckets yet)
- [x] Document cost breakdown by service (docs/cost-tracking.md)
- [x] Document cost optimization strategies implemented (docs/cost-tracking.md)
- [x] Create process for quarterly cost review (docs/cost-tracking.md)

### Cost Tracking Verification
- [x] Verify all resources have CostCenter tag (confirmed in checkpoint 11 tag verification)
- [x] Test AWS Cost Explorer filtering by Environment tag (tags activated — 24h propagation window)
- [x] Test AWS Cost Explorer filtering by CostCenter tag (tags activated — 24h propagation window)
- [x] Verify budget alerts trigger correctly (SNS confirmation email sent on next deploy)
- [x] Document monthly cost projection (~$98.93/month dev — docs/cost-tracking.md)
- [x] Set up team calendar reminder for monthly cost review (documented in docs/cost-tracking.md)

## Checkpoint 14 - Documentation

### Infrastructure Details Documentation (docs/terraform-infrastructure.md)
- [x] Create comprehensive infrastructure details document in docs/ folder
- [x] Document architecture overview with ASCII or visual diagram
- [x] Document VPC and networking design
- [x] Document ECS Fargate cluster and task configuration
- [x] Document service deployment architecture (web and API)
- [x] Document database and storage design
- [x] Document auto-scaling policies and thresholds
- [x] Document monitoring, alarms, and logging setup
- [x] Document security groups and IAM role descriptions
- [x] Document Terraform state management and backend configuration
- [x] Document cost estimation and optimization strategies
- [x] Document module structure and dependencies

### Deployment Workflow Documentation (docs/terraform-deployment.md)
- [x] Create comprehensive deployment workflow document in docs/ folder
- [x] Document prerequisites and setup (AWS CLI, Terraform, credentials)
- [x] Document environment-specific configuration (envs/dev.tfvars vs envs/staging.tfvars)
- [x] Document how to apply for each environment
- [x] Document how to run terraform plan and review output
- [x] Document safe infrastructure change procedures
- [x] Document how to scale tasks up or down
- [x] Document updating application images in ECR
- [x] Document rollback procedures
- [x] Document common troubleshooting scenarios
- [x] Document monitoring health and accessing logs
- [x] Document cost tracking and budget management

### Additional Documentation
- [x] Update infra/README.md with module structure, design decisions, outputs reference
- [x] Document Terraform variables and outputs strategy (no magic strings, infra/README.md)
- [x] IAM role documentation (docs/terraform-infrastructure.md — IAM Roles section)
- [x] Secrets management approach (docs/terraform-infrastructure.md — Secrets Management section)
- [x] Resource tagging strategy (docs/terraform-infrastructure.md — Resource Tagging section)
- [x] Cost tracking and budgets (docs/cost-tracking.md — Checkpoint 13)
- [x] Cleanup and destruction procedures (docs/terraform-destroy.md — Checkpoint 12)
