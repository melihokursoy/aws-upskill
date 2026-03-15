output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN."
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "web_cpu_alarm_arn" {
  description = "ARN of the web CPU high alarm."
  value       = aws_cloudwatch_metric_alarm.web_cpu_high.arn
}

output "api_cpu_alarm_arn" {
  description = "ARN of the API CPU high alarm."
  value       = aws_cloudwatch_metric_alarm.api_cpu_high.arn
}
