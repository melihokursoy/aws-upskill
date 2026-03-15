# Technical Plan: Terraform Infrastructure for AWS

## Overview

Deploy web applications and APIs to AWS using ECS Fargate for container orchestration. Terraform manages all infrastructure as code, enabling reproducible deployments across environments.

**Key Technologies:**
- AWS ECS Fargate (serverless containers)
- AWS ECR (Elastic Container Registry)
- Application Load Balancer (ALB) for routing
- CloudWatch for logging and monitoring
- Auto Scaling based on multiple strategies
- RDS for databases
- S3 for storage
- VPC with public/private subnets

## Architecture Decision

**Container Deployment: ECS Fargate**
- Serverless container platform (no EC2 management required)
- Pay per container usage (cost-efficient)
- Integrates with ALB for load balancing
- CloudWatch Logs for container output

**Container Registry: AWS ECR (Elastic Container Registry)**
- Private, native AWS service
- Integrated with ECS for easy image deployment
- Vulnerability scanning support
- Per-region registries for resilience

**Load Balancing: Application Load Balancer (ALB)**
- Layer 7 routing (path-based, hostname-based)
- Good for both web applications and REST APIs
- Integrated health checks with ECS
- Connection draining for graceful shutdowns

**Auto-Scaling: Target Tracking (Dev/Staging)**
- Target Tracking: CPU 70%, Memory 80% utilization targets
- Minimum tasks: 2 per service (ensures availability)
- Maximum tasks: 4 per service (cost-controlled scaling)
- No step scaling or scheduled scaling

## Terraform State Management Strategy

**Remote State Storage (S3 + DynamoDB):**
- State files stored in AWS S3 (not in project folder)
- S3 bucket configured for:
  - Server-side encryption (AES-256)
  - Versioning enabled for state file recovery
  - Private access (no public read)
  - Bucket policies restricting access to team members only
- DynamoDB table for state locking:
  - Prevents concurrent terraform applies
  - Table name: `{project}-terraform-locks`
  - Ensures data consistency across team

**Local State File Management:**
- Local `.terraform/terraform.tfstate` files generated during planning
- `.gitignore` explicitly prevents committing:
  - `*.tfstate` - State files
  - `*.tfstate.backup` - Backup state files
  - `.terraform/` - Terraform working directory
  - `.terraform.lock.hcl` - Lock file (optional to commit)
- Never manually edit or commit state files
- Team members always use S3 backend (not local state)

**State File Access:**
- Only authorized AWS credentials can access S3 state bucket
- Team members must have IAM permissions for:
  - S3 bucket read/write
  - DynamoDB table read/write
- Production state files completely separate from project repo
- State file history accessible via S3 versioning (audit trail)

## Terraform Outputs and Environment Variables Strategy

**No Magic Strings Policy:**
- All infrastructure identifiers derived from Terraform outputs
- Environment names (dev/staging) passed as variables, never hardcoded
- All application configuration sourced from Terraform outputs

**Terraform Outputs Required:**
- VPC and networking: VPC ID, subnet IDs, security group IDs
- ALB: ALB DNS name, target group ARNs, listener ARNs
- ACM: Certificate ARN, validation CNAME records (for external DNS setup)
- ECR: Repository URLs for web and API services
- ECS: Cluster name, task definition ARNs, service names
- RDS: Database endpoint, port, name
- S3: Bucket names for application assets and backups
- CloudWatch: Log group names for each service
- IAM: Role ARNs for task execution and task roles
- X-Ray: Daemon endpoint for tracing

**Environment Variables Flow:**
- Terraform outputs → Root module outputs.tf
- Root outputs → Application environment variable injection
- ECS task definitions receive environment variables from Terraform
- Applications read all config from environment variables (no hardcoded values)
- Environment variable names consistent across dev/staging (values differ)

**Environment Configuration:**
- Separate variable files per environment (never shared):
  - `infra/envs/dev.tfvars` - Development environment values
  - `infra/envs/staging.tfvars` - Staging environment values
- No environment names hardcoded in Terraform code
- Apply with: `terraform apply -var-file="envs/dev.tfvars"`
- Each file contains all environment-specific values:
  - `environment_name`, `region`, `vpc_cidr`, `domain_name`
  - Task counts, instance sizes, log retention, budget amounts
- Both files committed to repo (no secrets — secrets are in Secrets Manager)
- `.gitignore` excludes `terraform.tfvars` (local overrides only)

## Implementation Architecture

### Web Application Deployment
- Docker container running Next.js application
- ECR repository for image storage
- ECS Task Definition specifying container, CPU, memory, environment
- ECS Service managing desired task count and updates
- ALB target group for routing HTTP/HTTPS traffic
- CloudWatch Logs for application logs

### API Service Deployment
- Docker container running NestJS API
- ECR repository for image storage
- ECS Task Definition (similar to web)
- ECS Service with API-specific configuration
- ALB target group with path-based routing (e.g., /api/*)
- CloudWatch Logs for API logs

## Implementation Tasks

### Phase 1: Terraform Foundation

1. Set up Terraform project structure
   - Root module configuration
   - Variables and outputs
   - Backend setup (S3 + DynamoDB for state)
   - VPC and networking modules

2. Create VPC and Networking
   - VPC with configurable CIDR block
   - Public subnets (for ALB)
   - Private subnets (for ECS tasks)
   - NAT Gateway for private subnet outbound traffic
   - Internet Gateway for public internet access
   - Route tables and associations

3. Configure Application Load Balancer
   - ALB in public subnets
   - Target groups for web and API services
   - Path-based routing rules (/ → web, /api/* → API)
   - Health check configuration
   - Security groups for ALB (port 80 and 443 inbound)
   - HTTPS listener (port 443) with ACM certificate
   - HTTP listener (port 80) redirects to HTTPS
   - DNS: External DNS provider, CNAME pointing to ALB DNS name (Route53 out of scope)

4. Configure ACM Certificate
   - Request ACM certificate for custom domain (e.g. dev.yourdomain.com)
   - DNS validation method (add CNAME record in external DNS provider)
   - Attach certificate to ALB HTTPS listener
   - Certificate auto-renewal managed by ACM

### Phase 2: ECS and Container Infrastructure

1. Set up ECR Repositories
   - ECR repo for web application image
   - ECR repo for API application image
   - Image retention policies
   - Lifecycle rules for cleanup

2. Configure ECS Cluster
   - ECS cluster resource
   - CloudWatch Log Groups for container logs
   - IAM roles for ECS task execution
   - IAM roles for task permissions (S3, RDS, etc.)

3. Create ECS Task Definitions
   - Web application task definition (CPU: 512, Memory: 1024)
   - API application task definition (CPU: 512, Memory: 1024)
   - Environment variables for app configuration
   - Log driver configuration (CloudWatch Logs)
   - Container port mappings

4. Deploy ECS Services
   - Web application service
   - API application service
   - Service discovery (if needed)
   - Desired task count
   - Deployment strategy: Rolling deployment
     - Gradually replace old tasks with new versions
     - Minimum healthy percent: 50% (at least 1 task healthy during update)
     - Maximum percent: 100% (allows old and new to run together briefly)
     - Health check integration with ALB
     - Connection draining enabled for graceful shutdown

### Phase 3: Auto-Scaling and Monitoring

1. Configure Auto-Scaling Policies
   - Target tracking policy for CPU utilization (70% target)
   - Target tracking policy for memory utilization (80% target)
   - Minimum tasks: 2 per service
   - Maximum tasks: 4 per service
   - No step scaling or scheduled scaling (deferred)

2. Set up CloudWatch Monitoring
   - **Log Groups Organization**:
     - `/aws/ecs/web` - Next.js application logs
     - `/aws/ecs/api` - NestJS API application logs
     - `/aws/alb/web-api` - Application Load Balancer access logs
     - `/aws/rds/postgres` - RDS database logs (if enabled)
   - Log retention: 7 days for dev/staging
   - Container Insights integration for ECS cluster metrics
   - Custom CloudWatch Dashboards:
     - ECS task CPU/memory utilization
     - ALB request count and latency
     - RDS database connections and queries
     - Container error and warning logs
   - CloudWatch Alarms:
     - High CPU utilization (>80%)
     - High memory utilization (>85%)
     - ALB unhealthy target count
     - Task failures/crashes
     - Database connection pool exhaustion

3. Set up X-Ray Tracing
   - Enable X-Ray daemon in ECS cluster
   - X-Ray service map for distributed tracing
   - Trace sampling: 10% for dev/staging (cost optimization)
   - Observable services:
     - Next.js web service → ALB → NestJS API calls
     - NestJS API → RDS database queries
     - Both services → S3 access
   - X-Ray annotations for:
     - Environment (dev/staging)
     - Service name (web/api)
     - Request path and method

4. Configure Correlation ID / Request ID Tracking
   - **Header Strategy**:
     - Use `X-Correlation-ID` header for tracing (or `x-amzn-trace-id` from X-Ray)
     - ALB passes through `X-Correlation-ID` header from client or generates one
     - Web service receives/generates correlation ID and includes in all logs
     - Web service forwards correlation ID in API calls to backend (via header)
     - API service receives correlation ID and includes in all logs
   - **Log Integration**:
     - All CloudWatch log entries include `correlationId` field
     - Log format: `{timestamp, level, correlationId, service, message}`
     - Enables log filtering and querying by correlation ID across services
   - **Implementation Requirements**:
     - ALB: Configure to add/pass through correlation ID header
     - Web (Next.js): Middleware to extract/generate and attach to all logs
     - API (NestJS): Interceptor to extract and attach to all logs
     - Correlation ID persisted through async operations and database queries

5. Configure Load Balancer Health Checks
   - Health check path configuration
   - Timeout and interval settings
   - Healthy/unhealthy threshold

### Phase 4: Database and Data Services

1. Provision RDS Database (PostgreSQL)
   - Engine: PostgreSQL (latest stable version)
   - Single-AZ deployment (dev/staging cost optimization)
   - Auto-generate root password (random 32-char string)
   - Store root password in AWS Secrets Manager
   - Security group configuration (ECS task access only)
   - Parameter group configuration for PostgreSQL optimization
   - Backups disabled (deferred for future, dev/staging only)

2. Configure S3 Storage
   - S3 bucket for Terraform state backend (already configured)
   - S3 bucket for cost reports export (optional, deferred)
   - Application asset buckets: Deferred for future
   - Versioning: Disabled (no backups)
   - Lifecycle policies: Not configured

### Phase 5: Security and Compliance

1. IAM Configuration with Clear Documentation
   - **Task Execution Role** (ecsTaskExecutionRole)
     - Purpose: Allows ECS to pull images from ECR and write logs to CloudWatch
     - Permissions: ECR pull, CloudWatch Logs write, X-Ray write
     - Documentation: Clear comment in tf files describing purpose
     - Applied to: Both web and API ECS tasks

   - **Web Service Task Role** (ecsTaskRoleWeb)
     - Purpose: Permissions for Next.js application runtime operations
     - Permissions: S3 read/write, Secrets Manager read, Parameter Store read
     - Documentation: Clear comment explaining web service requirements
     - Applied to: Web application ECS tasks

   - **API Service Task Role** (ecsTaskRoleAPI)
     - Purpose: Permissions for NestJS API runtime operations
     - Permissions: RDS connect, S3 read/write, Secrets Manager read, Parameter Store read
     - Documentation: Clear comment explaining API service requirements
     - Applied to: API application ECS tasks

   - **IAM Role Documentation Requirements**:
     - Each role defined with clear purpose comment in Terraform
     - Trust relationship documented (who can assume the role)
     - Attached policies documented with inline comments
     - Least-privilege principle applied to all policies
     - Comprehensive IAM documentation in docs/terraform-infrastructure.md

2. Network Security
   - Security groups for ALB
   - Security groups for ECS tasks
   - Security groups for RDS
   - NACLs if additional filtering needed

3. Secrets and Configuration Management
   - **AWS Secrets Manager**:
     - Database credentials (RDS password)
     - Sensitive secrets requiring rotation
     - Auto-generated passwords
   - **AWS Parameter Store**:
     - Application configuration values
     - API endpoint URLs
     - Feature flags and non-sensitive config
     - Application settings per environment
   - Access control: IAM policies restrict access per service
   - Rotation: Configured for database credentials

## Terraform Module Structure

Infrastructure code is organized in the `infra/` folder at project root:

```
infra/
├── main.tf              # Root module
├── variables.tf         # Input variables
├── outputs.tf           # Module outputs
├── backend.tf           # State backend config
├── .gitignore           # Excludes *.tfstate, .terraform/, terraform.tfvars
├── envs/
│   ├── dev.tfvars       # Development environment variables
│   └── staging.tfvars   # Staging environment variables
├── scripts/
│   ├── deploy.sh               # Terraform deploy (env: dev or staging, op: plan/apply/destroy)
│   ├── build-and-push-ecr.sh   # Build Docker image and push to ECR
│   └── push-ecr.sh             # Push pre-built image to ECR
└── modules/
    ├── vpc/             # VPC and networking
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/             # Load balancer + HTTPS listeners
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── acm/             # ACM certificate for HTTPS
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecr/             # Container registries
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecs/             # ECS cluster and services
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── autoscaling/     # Auto-scaling policies
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/             # Database
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── s3/              # Storage
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/             # IAM roles and policies
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── monitoring/      # CloudWatch
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Deployment Environments

**Development**
- Single AZ (cost optimization)
- Task scaling: min 2, max 4 per service
- Target tracking auto-scaling (CPU 70%, Memory 80%)
- Basic monitoring and 7-day log retention

**Staging**
- Single AZ (cost optimization)
- Task scaling: min 2, max 4 per service
- Target tracking auto-scaling (CPU 70%, Memory 80%)
- Basic monitoring and 7-day log retention

## Docker Image Building and ECR Push Strategy

**Docker Configuration:**
- Dockerfiles for each application:
  - `apps/web/Dockerfile` - Next.js application (multi-stage build)
  - `apps/api-order/Dockerfile` - NestJS API (multi-stage build)
- Docker image naming convention:
  - `{ecr-registry}/web:latest` and `{ecr-registry}/web:{version-tag}`
  - `{ecr-registry}/api:latest` and `{ecr-registry}/api:{version-tag}`
- Multi-stage builds for optimized image size
- .dockerignore files to exclude unnecessary files

## Infrastructure Deploy Script

**Location:** `infra/scripts/deploy.sh`

**Purpose:** Wrapper script that runs Terraform commands for a given environment, simplifying the deployment workflow.

**Usage:**
```bash
./infra/scripts/deploy.sh dev      # Deploy dev environment
./infra/scripts/deploy.sh staging  # Deploy staging environment
```

**Script behavior:**
- Accepts a single required argument: `env` (must be `dev` or `staging`)
- Validates the `env` argument and exits with error if invalid
- Changes directory to `infra/` before running Terraform commands
- Runs `terraform init` if `.terraform/` directory doesn't exist
- Runs `terraform plan -var-file="envs/${env}.tfvars" -out=tfplan`
- Prompts user to confirm before applying (or accepts `-auto-approve` flag)
- Runs `terraform apply tfplan`
- Supports an optional operation argument: `plan`, `apply`, `destroy`
  - Default operation: `apply`
  - `./infra/scripts/deploy.sh dev plan` — only runs plan, no apply
  - `./infra/scripts/deploy.sh dev apply` — runs plan + apply
  - `./infra/scripts/deploy.sh dev destroy` — runs destroy with confirmation prompt
- Logs output with timestamps for auditability
- Exits with non-zero code on any failure

**Important notes:**
- `destroy` operation requires explicit confirmation (not auto-approved)
- Script uses `set -euo pipefail` for safe shell execution
- All Terraform operations run from the `infra/` working directory
- Both infrastructure and ECR scripts live under `infra/scripts/`

**ECR Push Scripts:**
- Location: `infra/scripts/` folder (same as deploy script)
- Script: `infra/scripts/build-and-push-ecr.sh`
  - Parameters: service name (web or api), version/tag
  - Builds Docker image locally
  - Authenticates with ECR (AWS CLI)
  - Pushes image to ECR repository
  - Tags with `latest` and version tag
  - Logs success/failure
- Script: `infra/scripts/push-ecr.sh` (for pre-built images)
- Documentation: Scripts should be idempotent and safe

**CI/CD Integration:**
- Scripts can be called manually for local testing
- Scripts can be integrated into GitHub Actions workflow (optional)
- Environment variables: AWS_REGION, ECR_REGISTRY_URL

## Cost Tracking and Budget Management

**Cost Allocation Tags:**
- All resources tagged with cost allocation tags
- Tag: `CostCenter` (team or project identifier)
- Tag: `Environment` (dev/staging - already included in standard tags)
- AWS Cost Explorer filters by tags for cost analysis
- Monthly cost reports by environment and service

**AWS Budgets Configuration:**
- Budget 1: Dev environment monthly budget
  - Alert at 50%, 75%, 100% of budget
  - Notification to team email
- Budget 2: Staging environment monthly budget
  - Alert at 50%, 75%, 100% of budget
  - Notification to team email
- Budget 3: Total infrastructure monthly budget
  - Alert at 75%, 100%, 125% of budget
  - Escalation notification for overages

**Cost Monitoring:**
- CloudWatch dashboard for cost metrics (optional)
- AWS Cost Explorer integration
- Monthly cost reports exported to S3
- Cost optimization recommendations reviewed quarterly

**Cost Optimization Strategies:**
- Dev/Staging: Single-AZ, minimal task counts (min 2, max 4)
- S3 lifecycle policies: deferred (no app buckets yet)
- RDS backups disabled for dev/staging
- CloudWatch log retention (7 days)
- X-Ray sampling at 10% (not 100%)
- No unused resources (enforce via tagging and monitoring)

## Resource Tagging and Cleanup Strategy

**Tagging Standard:**
- All AWS resources tagged with consistent naming convention
- Required tags on all resources:
  - `Environment`: dev or staging (from variable)
  - `Project`: terraform-aws-infra (or application name)
  - `ManagedBy`: terraform
  - `CreatedAt`: deployment timestamp
  - `Owner`: team or organization name

**AWS Console Filtering:**
- Resources filterable by `Environment` tag (show all dev or all staging)
- Resources filterable by `Project` tag (show all project resources)
- Resources filterable by `ManagedBy: terraform` (identify managed vs manual)
- ALB and ECS resources tagged for easy identification

**Terraform Destroy Cleanup:**
- `terraform destroy` removes ALL resources created by Terraform
- No orphaned resources left behind (databases, buckets, etc.)
- All resources must be managed by Terraform (no manual creation)
- State file contains complete resource list for accurate cleanup
- S3 bucket `force_destroy` enabled to remove versioned/empty buckets on destroy
- RDS deletion protection disabled for dev/staging (enables cleanup)

**Cleanup Verification:**
- AWS Console shows no remaining resources after destroy
- CloudWatch log groups cleaned up by Terraform
- IAM roles and policies cleaned up completely
- Security groups fully removed
- VPC and networking fully removed
- ECR repositories empty and removed
- S3 buckets fully removed

## Success Criteria

- All infrastructure provisioned via Terraform
- Web and API applications running in ECS Fargate
- ALB routing traffic correctly to both services
- Auto-scaling responding to load changes
- CloudWatch monitoring and alarms configured
- RDS database accessible from ECS tasks
- S3 buckets available for application use
- Security groups restricting traffic appropriately
- State file stored remotely with encryption and locking
- Infrastructure can be reprovisioned in under 30 minutes
- All resources properly tagged for filtering
- `terraform destroy` completely removes all resources
- Documentation is current and complete

## Documentation Requirements

Two comprehensive documents should be created in the `docs/` folder at project root:

### 1. Infrastructure Details Documentation (`docs/terraform-infrastructure.md`)
Complete reference for the infrastructure setup including:
- Architecture overview with diagrams (ASCII or visual)
- VPC and networking design
- ECS Fargate cluster configuration
- Service deployment architecture
- Database and storage design
- Auto-scaling policies and thresholds
- Monitoring and alerting setup
- Security group and IAM role descriptions
- State management and backend configuration
- Cost estimation and optimization strategies

### 2. Deployment Workflow Documentation (`docs/terraform-deployment.md`)
Step-by-step operational guide including:
- Prerequisites and setup (AWS CLI, Terraform, credentials)
- Environment-specific configuration
- Running `terraform plan` and reviewing output
- Applying infrastructure changes safely
- Scaling tasks up or down
- Updating application images in ECR
- Rolling back changes
- Common troubleshooting scenarios
- Monitoring health and logs
- Disaster recovery procedures
- Cost tracking and budget management
