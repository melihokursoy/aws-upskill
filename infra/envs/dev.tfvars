# ---------------------------------------------------------------------------
# Development Environment Variables
#
# Apply with: terraform apply -var-file="envs/dev.tfvars"
# Or use:     infra/scripts/deploy.sh dev
# ---------------------------------------------------------------------------

environment_name = "dev"
region           = "us-east-1"
project_name     = "aws-upskill"
owner            = "team"
cost_center      = "aws-upskill-dev"

# Networking — single-AZ for cost optimization
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidr   = "10.0.1.0/24"
public_subnet_cidr_2 = "10.0.3.0/24" # ALB requires 2 AZs — no workloads deployed here
private_subnet_cidr   = "10.0.2.0/24"
private_subnet_cidr_2 = "10.0.4.0/24" # RDS DB subnet group requires 2 AZs — no workloads here
availability_zone    = "us-east-1a"
availability_zone_2  = "us-east-1b" # ALB secondary AZ only

# Domain — replace with your actual dev subdomain
domain_name = "dev.aws-upskill.codecrib.co.uk"

# ECS task sizing — minimum Fargate size for cost optimization
task_cpu    = 256   # 0.25 vCPU (minimum)
task_memory = 512   # 512 MiB — reduced after webpack bundling eliminated node_modules at runtime

# ECS task scaling
min_task_count = 2
max_task_count = 4

# Monitoring
log_retention_days = 7
log_level          = "info"

# RDS — PostgreSQL
db_name           = "appdb"
db_instance_class = "db.t3.micro"

# Cost / Budgets
monthly_budget_amount = 50
budget_alert_email    = "team@example.com"
