output "certificate_arn" {
  description = "ARN of the ACM certificate. The ALB can be created immediately — HTTPS works once the certificate is validated via DNS."
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain" {
  description = "Domain name the certificate was issued for."
  value       = aws_acm_certificate.main.domain_name
}

output "validation_cnames" {
  description = <<-EOT
    CNAME records to add to your external DNS provider for certificate validation.
    Add these before or immediately after terraform apply — the certificate will
    remain PENDING until the records are present and propagated.
  EOT
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
