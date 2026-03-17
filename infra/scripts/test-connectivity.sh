#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test-connectivity.sh
#
# Validates infrastructure connectivity by probing live endpoints and checking
# AWS resource health. Reads all URLs and names from Terraform outputs.
#
# Usage:
#   ./infra/scripts/test-connectivity.sh <env>
#
#   env: dev | staging
#
# Examples:
#   ./infra/scripts/test-connectivity.sh dev
#   ./infra/scripts/test-connectivity.sh staging
#
# Dependencies: aws, terraform, curl, jq
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

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <dev|staging>"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: env must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies check
# ---------------------------------------------------------------------------

for cmd in aws terraform curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
done

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ✗ $*"; FAILURES=$((FAILURES + 1)); }

FAILURES=0

# ---------------------------------------------------------------------------
# Read Terraform outputs
# ---------------------------------------------------------------------------

log "==> Reading Terraform outputs for environment: $ENV"
cd "$INFRA_DIR"

if [[ ! -d ".terraform" ]]; then
  log "==> Running terraform init..."
  terraform init -backend-config="envs/${ENV}.backend.hcl" -input=false -reconfigure
fi

DOMAIN=$(terraform output -raw domain_name)
ALB_DNS=$(terraform output -raw alb_dns_name)
CLUSTER=$(terraform output -raw ecs_cluster_name)
WEB_SERVICE=$(terraform output -raw ecs_web_service_name)
API_SERVICE=$(terraform output -raw ecs_api_service_name)
REGION=$(terraform output -raw region)

BASE_URL="https://${DOMAIN}"

log "   Domain     : $DOMAIN"
log "   ALB DNS    : $ALB_DNS"
log "   Cluster    : $CLUSTER"
log "   Region     : $REGION"

# ---------------------------------------------------------------------------
# 1. ECS Service Health — check running task counts
# ---------------------------------------------------------------------------

log ""
log "==> Checking ECS service health..."

check_ecs_service() {
  local service_name="$1"
  local label="$2"

  local output
  output=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$service_name" \
    --region "$REGION" \
    --output json)

  local desired running status
  desired=$(echo "$output" | jq -r '.services[0].desiredCount')
  running=$(echo "$output" | jq -r '.services[0].runningCount')
  status=$(echo "$output"  | jq -r '.services[0].status')

  if [[ "$status" == "ACTIVE" && "$running" -ge "$desired" && "$desired" -gt 0 ]]; then
    pass "$label: ACTIVE — $running/$desired tasks running"
  else
    fail "$label: status=$status running=$running desired=$desired"
  fi
}

check_ecs_service "$WEB_SERVICE" "ECS web service"
check_ecs_service "$API_SERVICE" "ECS api service"

# ---------------------------------------------------------------------------
# 2. ALB Target Group Health — check healthy target counts
# ---------------------------------------------------------------------------

log ""
log "==> Checking ALB target group health..."

WEB_TG_ARN=$(terraform output -raw web_target_group_arn)
API_TG_ARN=$(terraform output -raw api_target_group_arn)

check_target_group() {
  local tg_arn="$1"
  local label="$2"

  local healthy
  healthy=$(aws elbv2 describe-target-health \
    --target-group-arn "$tg_arn" \
    --region "$REGION" \
    --output json | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')

  if [[ "$healthy" -gt 0 ]]; then
    pass "$label: $healthy healthy target(s)"
  else
    fail "$label: 0 healthy targets"
  fi
}

check_target_group "$WEB_TG_ARN" "Web target group"
check_target_group "$API_TG_ARN" "API target group"

# ---------------------------------------------------------------------------
# 3. HTTP Endpoint Tests — probe live URLs
# ---------------------------------------------------------------------------

log ""
log "==> Testing HTTP endpoints..."

check_endpoint() {
  local url="$1"
  local label="$2"
  local expected_status="${3:-200}"

  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 \
    --connect-timeout 5 \
    "$url" 2>/dev/null || echo "000")

  if [[ "$http_status" == "$expected_status" ]]; then
    pass "$label: HTTP $http_status — $url"
  else
    fail "$label: HTTP $http_status (expected $expected_status) — $url"
  fi
}

check_endpoint "${BASE_URL}/api/health"    "API health endpoint"   "200"
check_endpoint "${BASE_URL}/api/db-health" "API db-health endpoint" "200"
check_endpoint "${BASE_URL}/"              "Web root"              "200"

# ---------------------------------------------------------------------------
# 4. CloudWatch Logs — verify log streams exist
# ---------------------------------------------------------------------------

log ""
log "==> Checking CloudWatch log groups..."

check_log_group() {
  local log_group="$1"
  local label="$2"

  local count
  count=$(aws logs describe-log-streams \
    --log-group-name "$log_group" \
    --region "$REGION" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --output json 2>/dev/null | jq '.logStreams | length')

  if [[ "$count" -gt 0 ]]; then
    pass "$label ($log_group): has log streams"
  else
    fail "$label ($log_group): no log streams found"
  fi
}

WEB_LOG_GROUP=$(terraform output -raw log_group_web)
API_LOG_GROUP=$(terraform output -raw log_group_api)

check_log_group "$WEB_LOG_GROUP" "Web log group"
check_log_group "$API_LOG_GROUP" "API log group"

# ---------------------------------------------------------------------------
# 5. Resource Tag Verification — spot-check ECS cluster tags
# ---------------------------------------------------------------------------

log ""
log "==> Verifying resource tags..."

CLUSTER_ARN=$(terraform output -raw ecs_cluster_arn)

TAGS=$(aws ecs list-tags-for-resource \
  --resource-arn "$CLUSTER_ARN" \
  --region "$REGION" \
  --output json | jq -r '[.tags[] | .key] | sort | join(",")')

REQUIRED_TAGS=("Environment" "ManagedBy" "Owner" "Project")
for tag in "${REQUIRED_TAGS[@]}"; do
  if echo "$TAGS" | grep -q "$tag"; then
    pass "Tag present: $tag"
  else
    fail "Tag missing: $tag on ECS cluster"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
if [[ $FAILURES -eq 0 ]]; then
  log "==> All checks passed."
else
  log "==> $FAILURES check(s) failed."
  exit 1
fi
