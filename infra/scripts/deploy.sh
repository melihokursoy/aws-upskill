#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh
#
# Full infrastructure deployment with automatic ACM certificate validation.
#
# Usage:
#   ./infra/scripts/deploy.sh <env> [operation]
#
#   env:       dev | staging
#   operation: apply (default) | plan | destroy
#
# Examples:
#   ./infra/scripts/deploy.sh dev
#   ./infra/scripts/deploy.sh dev plan
#   ./infra/scripts/deploy.sh staging apply
#   ./infra/scripts/deploy.sh dev destroy
#
# Flow for apply:
#   1. terraform init (if needed)
#   2. Apply VPC + ACM certificate (targeted)
#   3. Run setup-dns-cloudflare.sh to add validation CNAME
#   4. Wait for certificate to become ISSUED
#   5. Full terraform apply
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------

if [[ -f "${INFRA_DIR}/.env" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "${INFRA_DIR}/.env"
  set +o allexport
fi

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

ENV="${1:-}"
OP="${2:-apply}"

if [[ -z "$ENV" ]]; then
  echo "ERROR: environment argument required"
  echo "Usage: $0 <dev|staging> [plan|apply|destroy]"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: environment must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

if [[ "$OP" != "plan" && "$OP" != "apply" && "$OP" != "destroy" ]]; then
  echo "ERROR: operation must be 'plan', 'apply', or 'destroy', got: $OP"
  exit 1
fi

TFVARS="envs/${ENV}.tfvars"
BACKEND_CFG="envs/${ENV}.backend.hcl"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Step 1 — Init
# ---------------------------------------------------------------------------

cd "$INFRA_DIR"

if [[ ! -d ".terraform" ]]; then
  log "==> Initialising Terraform backend for: $ENV"
  terraform init -backend-config="$BACKEND_CFG" -input=false
else
  log "==> Terraform already initialised"
fi

# ---------------------------------------------------------------------------
# Plan only — no apply
# ---------------------------------------------------------------------------

if [[ "$OP" == "plan" ]]; then
  log "==> Running terraform plan for: $ENV"
  terraform plan -var-file="$TFVARS"
  exit 0
fi

# ---------------------------------------------------------------------------
# Destroy
# ---------------------------------------------------------------------------

if [[ "$OP" == "destroy" ]]; then
  echo ""
  echo "WARNING: This will destroy ALL infrastructure for environment: $ENV"
  read -r -p "Type the environment name to confirm: " CONFIRM
  if [[ "$CONFIRM" != "$ENV" ]]; then
    echo "Aborted."
    exit 1
  fi

  log "==> Running terraform destroy for: $ENV"
  terraform destroy -var-file="$TFVARS"
  exit 0
fi

# ---------------------------------------------------------------------------
# Cloudflare helper — skips silently if credentials not set
# ---------------------------------------------------------------------------

run_cloudflare() {
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    echo ""
    echo "WARN: CLOUDFLARE_API_TOKEN or CLOUDFLARE_ZONE_ID not set — skipping DNS update."
    echo "      Add them to infra/.env and re-run to set DNS records."
    return 0
  fi
  "${SCRIPT_DIR}/setup-dns-cloudflare.sh" "$ENV"
}

# ---------------------------------------------------------------------------
# Apply — step 1: VPC + ACM only (cert must be issued before HTTPS listener)
# ---------------------------------------------------------------------------

log "==> Step 1/4: Applying VPC and ACM certificate..."
terraform apply \
  -var-file="$TFVARS" \
  -target=module.vpc \
  -target=module.acm \
  -auto-approve

# ---------------------------------------------------------------------------
# Apply — step 2: Add ACM validation CNAME to Cloudflare
# ---------------------------------------------------------------------------

log "==> Step 2/4: Adding ACM validation CNAME to Cloudflare..."
run_cloudflare

# ---------------------------------------------------------------------------
# Apply — step 3: Wait for certificate to be issued
# ---------------------------------------------------------------------------

CERT_ARN=$(terraform output -raw acm_certificate_arn)
REGION=$(terraform output -json 2>/dev/null | jq -r '.region.value // "us-east-1"')

log "==> Step 3/4: Waiting for ACM certificate to be validated (up to 10 min)..."
log "    Certificate ARN: $CERT_ARN"

aws acm wait certificate-validated \
  --certificate-arn "$CERT_ARN" \
  --region "${REGION}"

log "    Certificate validated!"

# ---------------------------------------------------------------------------
# Apply — step 4: Full apply (ALB + HTTPS listener + all remaining resources)
# ---------------------------------------------------------------------------

log "==> Step 4/4: Running full terraform apply..."
terraform apply -var-file="$TFVARS" -auto-approve

# ---------------------------------------------------------------------------
# Post-deploy: update domain → ALB CNAME now that ALB DNS name is available
# ---------------------------------------------------------------------------

log "==> Post-deploy: Updating domain CNAME to ALB in Cloudflare..."
run_cloudflare

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

DOMAIN=$(terraform output -json acm_validation_cnames | jq -r 'keys[0]')

log ""
log "==> Deployment complete for: $ENV"
log ""
log "    ALB DNS name : $(terraform output -raw alb_dns_name)"
log "    Domain       : https://${DOMAIN}"
log ""
log "    DNS may take a few minutes to propagate."
