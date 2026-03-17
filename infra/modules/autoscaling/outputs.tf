output "web_autoscaling_target_arn" {
  description = "ARN of the App Auto Scaling target for the web service."
  value       = aws_appautoscaling_target.web.id
}

output "api_autoscaling_target_arn" {
  description = "ARN of the App Auto Scaling target for the API service."
  value       = aws_appautoscaling_target.api.id
}
