output "web_api_endpoint_name" {
  description = "SSM parameter name for the web service API endpoint (/app/web/api_endpoint)."
  value       = aws_ssm_parameter.web_api_endpoint.name
}

output "web_log_level_name" {
  description = "SSM parameter name for the web service log level (/app/web/log_level)."
  value       = aws_ssm_parameter.web_log_level.name
}

output "api_db_host_name" {
  description = "SSM parameter name for the API DB host (/app/api/db_host)."
  value       = aws_ssm_parameter.api_db_host.name
}

output "api_db_port_name" {
  description = "SSM parameter name for the API DB port (/app/api/db_port)."
  value       = aws_ssm_parameter.api_db_port.name
}

output "api_db_name_name" {
  description = "SSM parameter name for the API DB name (/app/api/db_name)."
  value       = aws_ssm_parameter.api_db_name.name
}

output "api_log_level_name" {
  description = "SSM parameter name for the API log level (/app/api/log_level)."
  value       = aws_ssm_parameter.api_log_level.name
}

output "cognito_user_pool_id_name" {
  description = "SSM parameter name for the Cognito User Pool ID (/app/cognito/user_pool_id)."
  value       = aws_ssm_parameter.cognito_user_pool_id.name
}

output "cognito_client_id_name" {
  description = "SSM parameter name for the Cognito Client ID (/app/cognito/client_id)."
  value       = aws_ssm_parameter.cognito_client_id.name
}

output "cognito_issuer_url_name" {
  description = "SSM parameter name for the Cognito issuer URL (/app/cognito/issuer_url)."
  value       = aws_ssm_parameter.cognito_issuer_url.name
}

output "cognito_domain_name" {
  description = "SSM parameter name for the Cognito Hosted UI URL (/app/cognito/domain)."
  value       = aws_ssm_parameter.cognito_domain.name
}
