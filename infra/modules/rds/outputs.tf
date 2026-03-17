output "db_endpoint" {
  description = "RDS instance endpoint (host:port). Pass to API service as DB_HOST."
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "RDS instance port (5432 for PostgreSQL)."
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Name of the initial database created in the RDS instance."
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.postgres.username
}

output "rds_security_group_id" {
  description = "Security group ID for the RDS instance."
  value       = aws_security_group.rds.id
}

output "root_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS root password. API task role must have read access."
  value       = aws_secretsmanager_secret.rds_root_password.arn
  sensitive   = true
}

output "root_password_secret_name" {
  description = "Name of the Secrets Manager secret: {project}/{env}/rds/postgres/root-password"
  value       = aws_secretsmanager_secret.rds_root_password.name
}

output "db_resource_id" {
  description = "RDS instance resource ID (e.g. db-XXXXXXXX). Used to construct rds-db:connect IAM policy ARN."
  value       = aws_db_instance.postgres.resource_id
}
