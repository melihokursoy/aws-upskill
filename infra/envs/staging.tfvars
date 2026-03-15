# ---------------------------------------------------------------------------
# Staging Environment Variables
#
# Apply with: terraform apply -var-file="envs/staging.tfvars"
# Or use:     infra/scripts/deploy.sh staging
# ---------------------------------------------------------------------------

environment_name = "staging"
region           = "us-east-1"
project_name     = "aws-upskill"
owner            = "team"
cost_center      = "aws-upskill-staging"

# Networking — single-AZ for cost optimization
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidr   = "10.1.1.0/24"
public_subnet_cidr_2 = "10.1.3.0/24" # ALB requires 2 AZs — no workloads deployed here
private_subnet_cidr  = "10.1.2.0/24"
availability_zone    = "us-east-1a"
availability_zone_2  = "us-east-1b" # ALB secondary AZ only

# Domain — replace with your actual staging subdomain
domain_name = "staging.aws-upskill.codecrib.co.uk"

# ECS task scaling
min_task_count = 2
max_task_count = 4

# Monitoring
log_retention_days = 7

# Cost / Budgets
monthly_budget_amount = 75
budget_alert_email    = "melih@codecrib.co.uk"