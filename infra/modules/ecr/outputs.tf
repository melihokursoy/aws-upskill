output "web_repository_url" {
  description = "ECR repository URL for the web service. Used in ECS task definition and push scripts."
  value       = aws_ecr_repository.web.repository_url
}

output "api_repository_url" {
  description = "ECR repository URL for the API service. Used in ECS task definition and push scripts."
  value       = aws_ecr_repository.api.repository_url
}

output "web_repository_name" {
  description = "ECR repository name for the web service."
  value       = aws_ecr_repository.web.name
}

output "api_repository_name" {
  description = "ECR repository name for the API service."
  value       = aws_ecr_repository.api.name
}

output "registry_id" {
  description = "AWS account ID that owns the registries (used for ECR login)."
  value       = aws_ecr_repository.web.registry_id
}
