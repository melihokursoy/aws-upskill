# ---------------------------------------------------------------------------
# Cognito Module Outputs
# ---------------------------------------------------------------------------

output "user_pool_id" {
  description = "Cognito User Pool ID. Used by seed script and SSM parameters."
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN. Passed to ALB authenticate-cognito action."
  value       = aws_cognito_user_pool.main.arn
}

output "client_id" {
  description = "Cognito App Client ID. Passed to ALB action and stored in SSM for web/API containers."
  value       = aws_cognito_user_pool_client.alb.id
}

output "cognito_domain" {
  description = "Hosted UI domain prefix (e.g. upskill-dev). Passed to ALB authenticate-cognito action. Note: the aws- prefix is stripped by Cognito as it is a reserved substring."
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_domain_url" {
  description = "Full Hosted UI HTTPS URL (e.g. https://upskill-dev.auth.us-east-1.amazoncognito.com). Stored in SSM for web container sign-in/sign-out links."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
}

output "issuer_url" {
  description = "Cognito OIDC issuer URL. Stored in SSM for API container token validation reference."
  value       = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
