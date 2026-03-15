# ---------------------------------------------------------------------------
# ACM Certificate Module
#
# Requests an ACM certificate for the custom domain using DNS validation.
# DNS validation is preferred over email because it auto-renews as long as
# the CNAME record stays in place.
#
# After terraform apply, you MUST manually add the CNAME validation record
# to your external DNS provider. The record details are in the outputs:
#   terraform output acm_validation_cnames
#
# The certificate will remain in PENDING_VALIDATION until the DNS record
# is added and propagated (~5 minutes). The ALB listener will not work
# until the certificate is ISSUED.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # Allow Terraform to replace the certificate when the domain name changes
  # without destroying the old one first (avoids downtime)
  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Note: Certificate validation is NOT managed here.
#
# After terraform apply, run the Cloudflare DNS script to add the validation
# CNAME — the certificate will validate automatically within ~5 minutes:
#
#   ./infra/scripts/setup-dns-cloudflare.sh dev
#
# The ALB is created immediately with the pending certificate. HTTPS will
# work as soon as ACM marks the certificate as ISSUED.
# ---------------------------------------------------------------------------
