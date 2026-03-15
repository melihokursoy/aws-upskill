#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-dns-cloudflare.sh
#
# Reads Terraform outputs and upserts the required DNS records in Cloudflare:
#   1. ACM certificate validation CNAME (one-time, keeps cert auto-renewing)
#   2. Domain CNAME → ALB DNS name
#
# Usage:
#   ./infra/scripts/setup-dns-cloudflare.sh dev
#   ./infra/scripts/setup-dns-cloudflare.sh staging
#
# Required environment variables (set in shell or infra/.env):
#   CLOUDFLARE_API_TOKEN   — Cloudflare API token with DNS:Edit permission
#   CLOUDFLARE_ZONE_ID     — Zone ID from Cloudflare dashboard (Overview page)
#
# The script loads infra/.env automatically if it exists.
# Create it by copying the example:
#   cp infra/.env.example infra/.env
#
# Dependencies: terraform, curl, jq
# ---------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Load .env file (if present)
# Looks for infra/.env first, then project root .env
# Explicit env vars always take precedence over .env values
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_ENV_FILE="${SCRIPT_DIR}/../.env"
ROOT_ENV_FILE="${SCRIPT_DIR}/../../.env"

if [[ -f "$INFRA_ENV_FILE" ]]; then
  echo "==> Loading env vars from infra/.env"
  set -o allexport
  # shellcheck source=/dev/null
  source "$INFRA_ENV_FILE"
  set +o allexport
elif [[ -f "$ROOT_ENV_FILE" ]]; then
  echo "==> Loading env vars from .env"
  set -o allexport
  # shellcheck source=/dev/null
  source "$ROOT_ENV_FILE"
  set +o allexport
fi

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

ENV="${1:-}"

if [[ -z "$ENV" ]]; then
  echo "ERROR: environment argument required (dev or staging)"
  echo "Usage: $0 <dev|staging>"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: environment must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

# ---------------------------------------------------------------------------
# Required env vars
# ---------------------------------------------------------------------------

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "ERROR: CLOUDFLARE_API_TOKEN environment variable is not set"
  echo "Create an API token at: https://dash.cloudflare.com/profile/api-tokens"
  echo "Required permission: Zone > DNS > Edit"
  exit 1
fi

if [[ -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
  echo "ERROR: CLOUDFLARE_ZONE_ID environment variable is not set"
  echo "Find your Zone ID on the Cloudflare dashboard Overview page (right sidebar)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies check
# ---------------------------------------------------------------------------

for cmd in terraform curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Read Terraform outputs
# ---------------------------------------------------------------------------

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Reading Terraform outputs for environment: $ENV"
cd "$INFRA_DIR"

# Initialise backend for this environment if needed
if [[ ! -d ".terraform" ]]; then
  echo "==> Running terraform init..."
  terraform init -backend-config="envs/${ENV}.backend.hcl" -input=false
fi

VALIDATION_CNAMES=$(terraform output -json acm_validation_cnames)
DOMAIN=$(echo "$VALIDATION_CNAMES" | jq -r 'keys[0]')

# ALB may not exist yet (e.g. during initial cert validation step) — optional
ALB_DNS_NAME=$(terraform output -raw alb_dns_name 2>/dev/null || true)

echo "   Domain       : $DOMAIN"
if [[ -n "$ALB_DNS_NAME" ]]; then
  echo "   ALB DNS name : $ALB_DNS_NAME"
else
  echo "   ALB DNS name : (not deployed yet — will be set on next run)"
fi

# ---------------------------------------------------------------------------
# Cloudflare API helper
# ---------------------------------------------------------------------------

CF_API="https://api.cloudflare.com/client/v4"

# upsert_cname NAME TARGET
#   Creates the CNAME if it doesn't exist, updates it if the target changed.
#   Always sets proxy=false (DNS only) — required for ALB and ACM validation.
upsert_cname() {
  local name="$1"
  local target="$2"

  # Strip trailing dots — AWS outputs FQDNs with trailing dot, Cloudflare does not accept them
  name="${name%.}"
  target="${target%.}"

  echo ""
  echo "--> Upserting CNAME: $name → $target"

  # Check if any record (any type) already exists with this name
  existing=$(curl -s -X GET \
    "${CF_API}/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${name}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json")

  record_id=$(echo "$existing" | jq -r '.result[0].id // empty')
  current_type=$(echo "$existing" | jq -r '.result[0].type // empty')
  current_content=$(echo "$existing" | jq -r '.result[0].content // empty')

  if [[ -z "$record_id" ]]; then
    # No existing record — create
    echo "    Creating new CNAME record..."
    response=$(curl -s -X POST \
      "${CF_API}/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\":    \"CNAME\",
        \"name\":    \"${name}\",
        \"content\": \"${target}\",
        \"ttl\":     1,
        \"proxied\": false
      }")
  elif [[ "$current_type" == "CNAME" && "$current_content" == "$target" ]]; then
    echo "    Already up to date, skipping."
    return
  elif [[ "$current_type" != "CNAME" ]]; then
    # Different record type exists — delete all records with this name then create CNAME
    echo "    Deleting existing $current_type record(s) for $name..."
    all_records=$(echo "$existing" | jq -r '.result[].id')
    while IFS= read -r rid; do
      curl -s -X DELETE \
        "${CF_API}/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${rid}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" > /dev/null
    done <<< "$all_records"
    echo "    Creating new CNAME record..."
    response=$(curl -s -X POST \
      "${CF_API}/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\":    \"CNAME\",
        \"name\":    \"${name}\",
        \"content\": \"${target}\",
        \"ttl\":     1,
        \"proxied\": false
      }")
  else
    # Same type, different content — update
    echo "    Updating existing CNAME (was: $current_content)..."
    response=$(curl -s -X PATCH \
      "${CF_API}/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
      -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\":    \"CNAME\",
        \"name\":    \"${name}\",
        \"content\": \"${target}\",
        \"ttl\":     1,
        \"proxied\": false
      }")
  fi

  success=$(echo "$response" | jq -r '.success')
  if [[ "$success" != "true" ]]; then
    echo "ERROR: Cloudflare API call failed:"
    echo "$response" | jq '.errors'
    exit 1
  fi

  echo "    Done."
}

# ---------------------------------------------------------------------------
# 1. ACM validation CNAME(s)
# ---------------------------------------------------------------------------

echo ""
echo "==> Setting ACM certificate validation CNAME records..."

echo "$VALIDATION_CNAMES" | jq -c 'to_entries[]' | while read -r entry; do
  cname_name=$(echo "$entry" | jq -r '.value.name')
  cname_value=$(echo "$entry" | jq -r '.value.value')
  upsert_cname "$cname_name" "$cname_value"
done

# ---------------------------------------------------------------------------
# 2. Domain CNAME → ALB (skipped if ALB not deployed yet)
# ---------------------------------------------------------------------------

if [[ -n "$ALB_DNS_NAME" ]]; then
  echo ""
  echo "==> Setting domain CNAME to ALB..."
  upsert_cname "$DOMAIN" "$ALB_DNS_NAME"
else
  echo ""
  echo "==> Skipping domain CNAME (ALB not deployed yet — will be set after full apply)"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
echo "==> All DNS records updated successfully."
echo ""
echo "Next steps:"
echo "  - ACM certificate validation takes ~5 minutes after DNS propagates"
echo "  - Check certificate status: aws acm list-certificates --region us-east-1"
echo "  - Your domain will be live at: https://${DOMAIN}"
