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
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
availability_zone   = "us-east-1a"

# Domain — replace with your actual dev subdomain
domain_name = "dev.example.com"

# ECS task scaling
min_task_count = 2
max_task_count = 4

# Monitoring
log_retention_days = 7

# Cost / Budgets
monthly_budget_amount = 50
budget_alert_email    = "team@example.com"
