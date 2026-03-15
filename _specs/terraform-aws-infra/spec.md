# Spec for Terraform Infrastructure for AWS

branch: feature/terraform-aws-infra

## Summary

Set up Infrastructure as Code (IaC) using Terraform to provision and manage AWS infrastructure for the application. This enables reproducible, version-controlled infrastructure deployments and removes manual infrastructure setup.

## Functional Requirements

- Terraform configuration files that define all AWS infrastructure resources
- Docker files for Next.js web and NestJS API applications
- Scripts to build Docker images and push to ECR
- Support for multiple environments (dev, staging)
- VPC with public and private subnets (single-AZ for dev/staging cost optimization)
- Application load balancer for web traffic routing
- RDS database for persistent data storage
- ECS Fargate for serverless application hosting
- S3 buckets for Terraform state backend (application asset buckets deferred)
- CloudWatch for logging and monitoring
- X-Ray for distributed tracing and service map visualization
- IAM roles and policies following least-privilege principle
- Network security groups and NACLs for traffic control
- State management using S3 backend with state locking

## Possible Edge Cases

- Infrastructure drift (manual changes outside Terraform)
- State file corruption or loss
- Multi-region deployments and failover
- Rolling deployment failures and rollback procedures
- Handling secrets and sensitive data in Terraform
- Terraform apply failures requiring rollback
- Terraform version compatibility across team members

## Acceptance Criteria

- [ ] Terraform code is well-organized in modules
- [ ] Infrastructure can be provisioned from code in under 30 minutes
- [ ] All infrastructure is documented with descriptions and tags
- [ ] Terraform plan output is reviewed and approved before apply
- [ ] State file is stored remotely with encryption and locking enabled
- [ ] Multiple environments are supported (dev, staging)
- [ ] Disaster recovery and backup procedures (deferred for future)
- [ ] AWS Budgets configured for cost alerts
- [ ] Cost allocation tags applied to all resources
- [ ] Monthly cost reports reviewed by team
- [ ] CI/CD integration for automated infrastructure testing
- [ ] Documentation includes runbooks for common operations

## Resolved Decisions

- **IaC Tool**: Terraform (open source, multi-cloud support, infrastructure as code)
- **Container Platform**: AWS ECS Fargate (serverless containers, no EC2 management)
- **Container Registry**: AWS ECR (Elastic Container Registry) with image retention policies
- **Docker Image Building**:
  - Dockerfiles for web (Next.js) and API (NestJS) applications
  - Multi-stage builds for optimized images
  - Build and push scripts in `infra/scripts/` folder
  - Manual push capability via `infra/scripts/build-and-push-ecr.sh`
- **Infrastructure Deploy Script**: `infra/scripts/deploy.sh` accepts `env` (dev or staging) and optional operation (plan, apply, destroy); defaults to apply; destroy requires confirmation
- **Load Balancing**: Application Load Balancer (ALB) with path-based routing (/ → web, /api/* → API)
- **DNS**: External DNS provider (Route53 out of scope) — user provides domain, creates CNAME to ALB DNS name
- **HTTPS/TLS**: ACM certificate for custom domain, ALB listener on port 443, HTTP redirects to HTTPS
- **Auto-Scaling Strategy**: Target tracking (CPU 70%, Memory 80%), min 2 tasks, max 4 tasks per service
- **State Management**:
  - Remote S3 backend (not in project folder, shared across team)
  - S3 encryption, versioning, and private access enabled
  - DynamoDB locking for concurrent execution safety
  - .gitignore prevents committing local state files
  - Complete separation between project code and state
- **Deployment Environments**: Two environments (dev and staging) with minimal resources
  - Both single-AZ for cost optimization
  - Task scaling: min 2, max 4 tasks per service
  - Both with target tracking auto-scaling (CPU 70%, Memory 80%)
  - Both with basic monitoring and 7-day log retention
  - Separate variable files per environment: `infra/envs/dev.tfvars` and `infra/envs/staging.tfvars`
  - Apply with: `terraform apply -var-file="envs/dev.tfvars"`
- **Terraform Outputs for Configuration**:
  - All infrastructure identifiers derived from Terraform outputs
  - No magic strings or hardcoded values in code
  - Environment variables populated from Terraform outputs
  - Configuration management: terraform.tfvars for environment-specific values
- **Resource Tagging & Cleanup**:
  - All resources tagged with Environment, Project, ManagedBy, CreatedAt, Owner
  - Resources filterable in AWS Console by tags
  - terraform destroy removes ALL resources (no orphans)
  - S3 force_destroy enabled for complete cleanup
  - RDS deletion protection disabled for dev/staging environments
- **Deployment Strategy**: Rolling deployment
  - New versions gradually replace old versions
  - Minimum healthy percent: 50% (at least 1 task always healthy)
  - Maximum percent: 100% (old and new can run together briefly)
  - Health check driven (ALB integration)
  - Connection draining for graceful shutdown
- **Secrets & Configuration Management**:
  - AWS Secrets Manager: Database credentials only (RDS password)
  - AWS Parameter Store: Application config values, URLs, feature flags
  - Separation: Sensitive secrets vs non-sensitive config
  - Access control: IAM policies restrict per service
- **Cost Tracking & Budgets**:
  - Cost allocation tags: CostCenter, Environment
  - AWS Budgets: Dev, Staging, and Total infrastructure budgets
  - Alerts at 50%, 75%, 100% of budget (125% for total)
  - Email notifications for budget overages
  - Monthly cost reports via AWS Cost Explorer
  - Cost optimization: Single-AZ, min tasks, log retention, X-Ray sampling
- **Architecture**: VPC with public/private subnets, ALB in public subnets, ECS tasks in private subnets
- **Database**: PostgreSQL RDS with single-AZ deployment (dev/staging)
  - Engine: PostgreSQL
  - Single-AZ for both dev and staging (cost optimization)
  - Auto-generated root password stored in AWS Secrets Manager
  - Backups: Not configured (deferred for future)
  - Security groups restrict access to ECS tasks only
- **Storage**: S3 for Terraform state only (versioning, lifecycle policies, app buckets all deferred)
- **Security**:
  - IAM roles per service with least-privilege policies (documented in code and docs)
  - Three distinct IAM roles:
    - Task Execution Role: ECR pull, CloudWatch Logs write, X-Ray write
    - Web Task Role: S3, Secrets Manager, Parameter Store read/write
    - API Task Role: RDS, S3, Secrets Manager, Parameter Store access
  - Each IAM role has clear purpose comments in Terraform files
  - Comprehensive IAM role documentation in docs/terraform-infrastructure.md
  - Security groups for ALB, ECS tasks, and RDS
  - AWS Secrets Manager: Database credentials (RDS password)
  - AWS Parameter Store: Application config values and API endpoints
- **Monitoring & Observability**:
  - CloudWatch Log Groups (organized by service):
    - `/aws/ecs/web` - Next.js application logs
    - `/aws/ecs/api` - NestJS API logs
    - `/aws/alb/web-api` - Load balancer access logs
  - CloudWatch Metrics: Container Insights for ECS cluster monitoring
  - CloudWatch Alarms: CPU, memory, ALB health, task failures
  - X-Ray distributed tracing: 10% sampling rate for dev/staging
  - X-Ray service map: Web → ALB → API → RDS/S3
  - **Correlation ID Tracking**:
    - Header-based tracing using `X-Correlation-ID` header
    - ALB generates/passes through correlation ID on all requests
    - Correlation ID included in all CloudWatch logs for cross-service tracing
    - Web service (Next.js) middleware extracts and forwards correlation ID to API
    - API service (NestJS) interceptor extracts and logs correlation ID
    - Enables log queries across services by correlation ID
- **Task Configuration**: 512 CPU and 1024 MB memory for both web and API services
- **Documentation**: Two comprehensive guides in docs/ folder:
  - `terraform-infrastructure.md` - Complete infrastructure reference and design
  - `terraform-deployment.md` - Operational workflow and procedures

## Testing Guidelines

Create tests and validation for infrastructure:

- Terraform format and validation (terraform fmt, terraform validate)
- Terraform plan review and approval workflow
- Infrastructure testing: connectivity checks, security scans
- Load testing to verify infrastructure capacity
- Disaster recovery and backup testing (deferred)
- Cost estimation and budget alerts
- Infrastructure documentation accuracy validation
