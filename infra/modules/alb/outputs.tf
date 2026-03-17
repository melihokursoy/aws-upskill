output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Create a CNAME record in your DNS provider pointing to this value."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (useful for alias records if using Route53)."
  value       = aws_lb.main.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener. Used to attach additional listener rules."
  value       = aws_lb_listener.https.arn
}

output "web_target_group_arn" {
  description = "ARN of the web service target group. ECS web service registers tasks here."
  value       = aws_lb_target_group.web.arn
}

output "api_target_group_arn" {
  description = "ARN of the API service target group. ECS API service registers tasks here."
  value       = aws_lb_target_group.api.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group. ECS task security groups must allow inbound from this."
  value       = aws_security_group.alb.id
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used in CloudWatch metric dimensions (e.g. app/name/id)."
  value       = aws_lb.main.arn_suffix
}
