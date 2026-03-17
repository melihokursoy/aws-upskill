output "cluster_name" {
  description = "ECS cluster name. Used by ECS services and auto-scaling policies."
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.main.arn
}

output "web_log_group_name" {
  description = "CloudWatch log group name for the web service (/aws/ecs/web)."
  value       = aws_cloudwatch_log_group.web.name
}

output "api_log_group_name" {
  description = "CloudWatch log group name for the API service (/aws/ecs/api)."
  value       = aws_cloudwatch_log_group.api.name
}

output "alb_log_group_name" {
  description = "CloudWatch log group name for ALB access logs (/aws/alb/web-api)."
  value       = aws_cloudwatch_log_group.alb.name
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks (used by auto-scaling and RDS ingress rules)."
  value       = aws_security_group.ecs_tasks.id
}

output "web_service_name" {
  description = "ECS service name for the web application."
  value       = aws_ecs_service.web.name
}

output "api_service_name" {
  description = "ECS service name for the API application."
  value       = aws_ecs_service.api.name
}

output "web_task_definition_arn" {
  description = "ARN of the latest web task definition revision."
  value       = aws_ecs_task_definition.web.arn
}

output "api_task_definition_arn" {
  description = "ARN of the latest API task definition revision."
  value       = aws_ecs_task_definition.api.arn
}
