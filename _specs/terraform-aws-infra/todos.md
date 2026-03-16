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
- [ ] Create iam module for all IAM policies and roles
- [ ] Create Task Execution Role (ecsTaskExecutionRole)
  - [ ] Add clear purpose comment: "Allows ECS service to pull images from ECR and write logs to CloudWatch"
  - [ ] Attach ECR pull policy with inline comments explaining each permission
  - [ ] Attach CloudWatch Logs write policy with inline comments
  - [ ] Attach X-Ray write policy with inline comments
  - [ ] Document trust relationship (ECS tasks can assume this role)
- [ ] Create Web Service Task Role (ecsTaskRoleWeb)
  - [ ] Add clear purpose comment: "Allows Next.js web application to access S3, Secrets Manager, and Parameter Store"
  - [ ] Attach S3 read/write policy with inline comments
  - [ ] Attach Secrets Manager read policy with inline comments
  - [ ] Attach Parameter Store read policy with inline comments
  - [ ] Document trust relationship
- [ ] Create API Service Task Role (ecsTaskRoleAPI)
  - [ ] Add clear purpose comment: "Allows NestJS API to access RDS, S3, Secrets Manager, and Parameter Store"
  - [ ] Attach RDS connect policy with inline comments
  - [ ] Attach S3 read/write policy with inline comments
  - [ ] Attach Secrets Manager read policy with inline comments
  - [ ] Attach Parameter Store read policy with inline comments
  - [ ] Document trust relationship

### Security Groups & Secrets Management
- [ ] Create security group for ECS tasks
- [ ] Configure security group ingress from ALB
- [ ] Configure security group egress rules

### AWS Secrets Manager (Database Credentials)
- [ ] Create Secrets Manager secret for RDS root password
  - [ ] Secret name: `{project}/rds/postgres/root-password`
  - [ ] Store auto-generated password from RDS module
  - [ ] Enable automatic rotation (optional for dev/staging)
- [ ] Grant ECS task IAM role read access to Secrets Manager

### AWS Parameter Store (Application Configuration)
- [ ] Create Parameter Store entries for web service:
  - [ ] `/app/web/api_endpoint` - API URL
  - [ ] `/app/web/log_level` - Logging level
  - [ ] Any other application config values
- [ ] Create Parameter Store entries for API service:
  - [ ] `/app/api/db_host` - RDS endpoint
  - [ ] `/app/api/db_port` - RDS port
  - [ ] `/app/api/db_name` - Database name
  - [ ] `/app/api/log_level` - Logging level
  - [ ] Any other application config values
- [ ] Grant ECS task IAM role read access to Parameter Store

### Verification
- [ ] Verify IAM permissions for Secrets Manager access
- [ ] Verify IAM permissions for Parameter Store access
- [ ] Verify IAM permissions with terraform plan

## Checkpoint 9 - Terraform Outputs & Environment Variables

### Module Outputs Configuration
- [ ] Define VPC module outputs (VPC ID, subnet IDs, security group IDs)
- [ ] Define ALB module outputs (ALB DNS, target group ARNs, listener ARNs)
- [ ] Define ECR module outputs (repository URLs for web and API)
- [ ] Define ECS module outputs (cluster name, task definition ARNs, service names)
- [ ] Define RDS module outputs (database endpoint, port, name)
- [ ] Define S3 module outputs (bucket names)
- [ ] Define CloudWatch module outputs (log group names)
- [ ] Define IAM module outputs (task execution role ARN, task role ARNs)
- [ ] Aggregate all module outputs in root outputs.tf

### Environment Variables Configuration
- [ ] Create ECS task environment variable mapping from Terraform outputs
- [ ] Define environment variables for web service:
  - [ ] `API_ENDPOINT` from ALB DNS
  - [ ] `LOG_GROUP` from CloudWatch output
  - [ ] `REGION` from variable
  - [ ] `ENVIRONMENT` from variable (not hardcoded)
- [ ] Define environment variables for API service:
  - [ ] `DB_HOST` from RDS endpoint output
  - [ ] `DB_PORT` from RDS output (5432)
  - [ ] `DB_NAME` from Parameter Store (or RDS output)
  - [ ] `DB_USER` = "postgres" (RDS root user)
  - [ ] `DB_PASSWORD_SECRET_ARN` from Secrets Manager output (app retrieves at runtime)
  - [ ] `LOG_GROUP` from CloudWatch output
  - [ ] `REGION` from variable
  - [ ] `ENVIRONMENT` from variable (not hardcoded)
  - [ ] `PARAMETER_STORE_PREFIX` = `/app/api` (for config retrieval)
- [ ] Ensure no magic strings or hardcoded values in Terraform
- [ ] Document that:
  - [ ] API application retrieves RDS password from Secrets Manager at runtime
  - [ ] API application retrieves config values from Parameter Store (db_host, db_name, log_level, etc.)

## Checkpoint 10 - Multi-Environment Configuration

### Environment Variable Files
- [ ] Create `infra/envs/` directory
- [ ] Create `infra/envs/dev.tfvars` with all dev-specific values:
  - [ ] `environment_name = "dev"`
  - [ ] `region` - AWS region
  - [ ] `vpc_cidr` - VPC CIDR block
  - [ ] `domain_name` - dev subdomain (e.g. dev.yourdomain.com)
  - [ ] `min_task_count = 2`, `max_task_count = 4`
  - [ ] `log_retention_days = 7`
  - [ ] `project_name`, `owner`, `cost_center`
  - [ ] `monthly_budget_amount` - dev environment budget
- [ ] Create `infra/envs/staging.tfvars` with all staging-specific values:
  - [ ] `environment_name = "staging"`
  - [ ] Same structure as dev.tfvars with staging-specific values
  - [ ] `domain_name` - staging subdomain (e.g. staging.yourdomain.com)
- [ ] Add `terraform.tfvars` to `.gitignore` (local overrides only)
- [ ] Commit both `envs/dev.tfvars` and `envs/staging.tfvars` to repo

### Deploy Script
- [ ] Create `infra/scripts/` directory
- [ ] Create `infra/scripts/deploy.sh` with the following behavior:
  - [ ] Accept required `env` argument (`dev` or `staging`); exit with error if missing/invalid
  - [ ] Accept optional operation argument: `plan`, `apply` (default), `destroy`
  - [ ] Use `set -euo pipefail` for safe shell execution
  - [ ] Change working directory to `infra/` before running Terraform
  - [ ] Run `terraform init` if `.terraform/` directory doesn't exist
  - [ ] Run `terraform plan -var-file="envs/${env}.tfvars" -out=tfplan`
  - [ ] Prompt for confirmation before `apply` (or accept `-auto-approve` flag)
  - [ ] Run `terraform apply tfplan` for apply operation
  - [ ] Require explicit confirmation for `destroy` operation (not auto-approvable)
  - [ ] Run `terraform destroy -var-file="envs/${env}.tfvars"` for destroy
  - [ ] Log output with timestamps for auditability
  - [ ] Exit with non-zero code on any failure
- [ ] Make deploy script executable (`chmod +x infra/scripts/deploy.sh`)
- [ ] Test `./infra/scripts/deploy.sh dev plan` runs terraform plan for dev
- [ ] Test `./infra/scripts/deploy.sh staging plan` runs terraform plan for staging
- [ ] Test that invalid env argument produces clear error message
- [ ] Document deploy script usage in deployment docs

### Verification
- [ ] Test `terraform plan -var-file="envs/dev.tfvars"` succeeds
- [ ] Test `terraform plan -var-file="envs/staging.tfvars"` succeeds
- [ ] Verify environment names, domains, and config differ correctly between files
- [ ] Document the apply command for each environment in deployment docs

## Checkpoint 11 - Testing & Validation

- [ ] Run terraform fmt to format all code
- [ ] Run terraform validate on all modules
- [ ] Run terraform plan for dev environment and review
- [ ] Run terraform plan for staging environment and review
- [ ] Create infrastructure connectivity tests
- [ ] Verify ALB health checks are passing
- [ ] Verify ECS tasks are running and healthy
- [ ] Test application endpoint through ALB
- [ ] Test API endpoint through ALB path-based routing
- [ ] Verify CloudWatch logs are being collected

### Resource Tagging Verification
- [ ] Verify all resources have required tags (Environment, Project, ManagedBy, CreatedAt, Owner)
- [ ] Test AWS Console filtering by Environment tag (show all dev or staging)
- [ ] Test AWS Console filtering by Project tag
- [ ] Test AWS Console filtering by ManagedBy tag
- [ ] Verify no resources missing tags

## Checkpoint 12 - Cleanup & Destruction Testing

- [ ] Configure S3 bucket force_destroy = true for dev/staging
- [ ] Configure RDS deletion_protection = false for dev/staging
- [ ] Run `terraform destroy` in dev environment
- [ ] Verify all resources completely removed from AWS Console
- [ ] Verify no orphaned resources left behind:
  - [ ] No security groups remaining
  - [ ] No IAM roles/policies remaining
  - [ ] No CloudWatch log groups remaining
  - [ ] No S3 buckets remaining
  - [ ] No ECR repositories remaining
  - [ ] No RDS instances remaining
  - [ ] No VPC/subnets remaining
  - [ ] No ALB/target groups remaining
- [ ] Run `terraform destroy` in staging environment
- [ ] Verify complete cleanup of staging environment
- [ ] Document cleanup procedures
- [ ] Test re-creation from scratch with `terraform apply`

## Checkpoint 13 - Cost Tracking & Budget Alerts

### AWS Budgets Configuration
- [ ] Create AWS Budget for Dev environment
  - [ ] Set monthly budget amount (based on projected usage)
  - [ ] Configure alert at 50% of budget
  - [ ] Configure alert at 75% of budget
  - [ ] Configure alert at 100% of budget
  - [ ] Set notification email for team
- [ ] Create AWS Budget for Staging environment
  - [ ] Set monthly budget amount
  - [ ] Configure alerts at 50%, 75%, 100%
  - [ ] Set notification email for team
- [ ] Create AWS Budget for Total infrastructure
  - [ ] Set combined monthly budget
  - [ ] Configure alerts at 75%, 100%, 125%
  - [ ] Set escalation notification for overages

### Cost Allocation & Reporting
- [ ] Apply CostCenter tag to all resources
- [ ] Configure AWS Cost Explorer for tag-based filtering
- [ ] Set up monthly cost report export to S3
- [ ] Document cost breakdown by service (ECS, RDS, ALB, etc.)
- [ ] Document cost optimization strategies implemented
- [ ] Create process for quarterly cost review

### Cost Tracking Verification
- [ ] Verify all resources have CostCenter tag
- [ ] Test AWS Cost Explorer filtering by Environment tag
- [ ] Test AWS Cost Explorer filtering by CostCenter tag
- [ ] Verify budget alerts trigger correctly (test with forecast)
- [ ] Document monthly cost projection
- [ ] Set up team calendar reminder for monthly cost review

## Checkpoint 14 - Documentation

### Infrastructure Details Documentation (docs/terraform-infrastructure.md)
- [ ] Create comprehensive infrastructure details document in docs/ folder
- [ ] Document architecture overview with ASCII or visual diagram
- [ ] Document VPC and networking design
- [ ] Document ECS Fargate cluster and task configuration
- [ ] Document service deployment architecture (web and API)
- [ ] Document database and storage design
- [ ] Document auto-scaling policies and thresholds
- [ ] Document monitoring, alarms, and logging setup
- [ ] Document security groups and IAM role descriptions
- [ ] Document Terraform state management and backend configuration:
  - [ ] Explain S3 + DynamoDB backend setup
  - [ ] Document S3 bucket and DynamoDB table locations
  - [ ] Explain why state is NOT in project folder
  - [ ] Document how team members access shared state
  - [ ] Document state file encryption and versioning
  - [ ] Explain DynamoDB locking mechanism
- [ ] Document cost estimation and optimization strategies
- [ ] Document module structure and dependencies

### Deployment Workflow Documentation (docs/terraform-deployment.md)
- [ ] Create comprehensive deployment workflow document in docs/ folder
- [ ] Document prerequisites and setup (AWS CLI, Terraform, credentials)
- [ ] Document environment-specific configuration (envs/dev.tfvars vs envs/staging.tfvars)
- [ ] Document how to apply for each environment: `terraform apply -var-file="envs/dev.tfvars"`
- [ ] Document how to run terraform plan and review output
- [ ] Document safe infrastructure change procedures
- [ ] Document how to scale tasks up or down
- [ ] Document updating application images in ECR
- [ ] Document rollback procedures
- [ ] Document common troubleshooting scenarios
- [ ] Document monitoring health and accessing logs
- [ ] Document cost tracking and budget management
- [ ] Note: Disaster recovery and backups deferred for future implementation

### Additional Documentation
- [ ] Create README in infra/ directory explaining module structure
- [ ] Document infra/ folder structure and file organization
- [ ] Document Terraform variables and outputs strategy:
  - [ ] Explain no magic strings policy
  - [ ] Document all available Terraform outputs
  - [ ] Document how outputs are used for environment variables
  - [ ] Explain terraform.tfvars configuration per environment
  - [ ] Show examples of output usage
- [ ] Create comprehensive IAM role documentation including:
  - [ ] Task Execution Role purpose and permissions
  - [ ] Web Service Task Role purpose and permissions
  - [ ] API Service Task Role purpose and permissions
  - [ ] Trust relationships and role assumptions
  - [ ] Least-privilege principle applied
- [ ] Document secrets management approach
- [ ] Document correlation ID tracking and tracing strategy
- [ ] Document how to query logs by correlation ID in CloudWatch
- [ ] Document resource tagging strategy:
  - [ ] Explain tagging standard (Environment, Project, ManagedBy, CreatedAt, Owner, CostCenter)
  - [ ] Explain how to filter resources in AWS Console by tags
  - [ ] Provide examples of tag filtering
- [ ] Document cost tracking and budgets:
  - [ ] Explain AWS Budgets setup and alert thresholds
  - [ ] Document how to view costs in AWS Cost Explorer
  - [ ] Explain cost allocation by tag and environment
  - [ ] Document monthly cost review process
  - [ ] Provide cost optimization recommendations (already applied)
- [ ] Document cleanup and destruction procedures:
  - [ ] Prerequisites for destroy (S3 force_destroy, RDS deletion_protection)
  - [ ] Step-by-step terraform destroy process
  - [ ] Verification checklist for complete resource removal
  - [ ] How to recover from failed destroy
- [ ] Create or update CONTRIBUTING.md with infrastructure guidelines
