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
