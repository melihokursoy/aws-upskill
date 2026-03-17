# ---------------------------------------------------------------------------
# ECR Module Outputs
#
# repository_urls is a map keyed by the service folder name under apps/.
# Scripts derive paths as: apps/${service}/Dockerfile
# Example: { "web" => "...", "api-order" => "..." }
# ---------------------------------------------------------------------------

output "repository_urls" {
  description = "Map of service folder name to ECR repository URL."
  value = {
    "web"       = aws_ecr_repository.web.repository_url
    "api-order" = aws_ecr_repository.api_order.repository_url
  }
}

output "registry_id" {
  description = "AWS account ID that owns the registries (used for ECR login)."
  value       = aws_ecr_repository.web.registry_id
}
