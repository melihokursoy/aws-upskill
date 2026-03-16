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
