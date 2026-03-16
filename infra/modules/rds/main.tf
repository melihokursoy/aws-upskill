# ---------------------------------------------------------------------------
# RDS Module
#
# Provisions a single-AZ PostgreSQL RDS instance for dev/staging environments.
# Cost optimizations applied:
#   - Single-AZ deployment (no Multi-AZ standby)
#   - db.t3.micro instance class (minimum viable)
#   - Automated backups disabled (deferred for future)
#   - 20 GiB storage (minimum)
#
# Security:
#   - Auto-generated 32-character root password stored in AWS Secrets Manager
#   - Security group restricts port 5432 access to ECS tasks only
#   - RDS runs in the private subnet (no public access)
#   - deletion_protection = false to allow terraform destroy for dev/staging
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Random Password
# Generates a 32-character alphanumeric password for the RDS root user.
# Stored in Secrets Manager immediately after creation.
# ---------------------------------------------------------------------------

resource "random_password" "rds_root" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# AWS Secrets Manager — RDS Root Password
# Secret name follows the pattern: {project}/{env}/rds/postgres/root-password
# ECS API task role (Checkpoint 8) will be granted read access to this secret.
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds_root_password" {
  # Name: aws-upskill/dev/rds/postgres/root-password
  name        = "${var.project_name}/${var.environment_name}/rds/postgres/root-password"
  description = "Auto-generated root password for RDS PostgreSQL instance in ${var.environment_name}. Managed by Terraform."

  # Allow immediate deletion without recovery window (simplifies destroy in dev/staging)
  recovery_window_in_days = 0

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-rds-root-password"
    Purpose = "RDS root password - read by NestJS API at startup via Secrets Manager SDK"
  })
}

resource "aws_secretsmanager_secret_version" "rds_root_password" {
  secret_id = aws_secretsmanager_secret.rds_root_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.rds_root.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = var.db_name
  })

  # Wait for RDS to be available before writing the host into the secret
  depends_on = [aws_db_instance.postgres]
}

# ---------------------------------------------------------------------------
# DB Subnet Group
# RDS requires a subnet group — single-AZ but still needs the group resource.
# We use only the primary private subnet (cost optimization: no Multi-AZ).
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-${var.environment_name}-rds"
  description = "RDS subnet group for ${var.project_name} ${var.environment_name}. Spans 2 AZs as required by AWS, but RDS instance runs in primary AZ only (single-AZ, cost optimized)."
  subnet_ids  = [var.private_subnet_id, var.private_subnet_id_2]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-rds-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Security Group — RDS
# Allows inbound PostgreSQL traffic (port 5432) only from ECS tasks.
# All other inbound traffic is denied by default.
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment_name}-rds"
  description = "Allow PostgreSQL (port 5432) inbound from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
  }

  egress {
    description = "Allow all outbound (RDS needs to reach AWS endpoints for monitoring)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-rds-sg"
    Purpose = "Restrict RDS access to ECS tasks only"
  })
}

# ---------------------------------------------------------------------------
# DB Parameter Group
# PostgreSQL parameter group with logging enabled for CloudWatch integration.
# Logs slow queries (>1s), connections, and disconnections for observability.
# ---------------------------------------------------------------------------

resource "aws_db_parameter_group" "postgres" {
  name        = "${var.project_name}-${var.environment_name}-postgres"
  family      = "postgres16"
  description = "PostgreSQL 16 parameter group for ${var.project_name} ${var.environment_name}"

  # Log slow queries (queries taking longer than 1 second)
  # Useful for identifying N+1 queries and missing indexes
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # milliseconds
  }

  # Log all connections and disconnections for connection pool debugging
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # Log duration of each completed statement when combined with log_min_duration_statement
  parameter {
    name  = "log_duration"
    value = "0" # disabled — log_min_duration_statement handles this more efficiently
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment_name}-postgres-params"
  })
}

# ---------------------------------------------------------------------------
# RDS Instance — PostgreSQL
#
# engine_version: PostgreSQL 16 (latest stable as of 2025)
# instance_class: db.t3.micro — cheapest option for dev/staging
# single-AZ: multi_az = false — no standby replica (cost optimization)
# backups: backup_retention_period = 0 — disabled (deferred for future)
# deletion_protection = false — allows terraform destroy for dev/staging cleanup
# skip_final_snapshot = true — no snapshot on deletion (dev/staging only)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment_name}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  # Storage
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = random_password.rds_root.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  availability_zone      = var.availability_zone
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Cost optimization: single-AZ, no backups, no snapshots
  multi_az                = false
  backup_retention_period = 0 # disabled — deferred for future
  skip_final_snapshot     = true
  deletion_protection     = false # allow terraform destroy in dev/staging

  # Performance Insights disabled for cost optimization
  performance_insights_enabled = false

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment_name}-postgres"
    Purpose = "PostgreSQL database for NestJS API service"
  })
}
