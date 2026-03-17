#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# redeploy-service.sh
#
# Forces an ECS service to redeploy by triggering a new deployment.
# Reads cluster/service names from Terraform outputs.
# Waits for the deployment to stabilize before returning.
#
# Usage:
#   ./infra/scripts/redeploy-service.sh <service> <env>
#
#   service: web | api-order
#   env:     dev | staging
#
# Examples:
#   ./infra/scripts/redeploy-service.sh api-order dev
#   ./infra/scripts/redeploy-service.sh web staging
#
# Dependencies: aws, terraform, jq
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

SERVICE="${1:-}"
ENV="${2:-}"

if [[ -z "$SERVICE" || -z "$ENV" ]]; then
  echo "Usage: $0 <service> <dev|staging>"
  echo "  service: web | api-order"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: env must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies check
# ---------------------------------------------------------------------------

for cmd in aws terraform jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
done

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Read Terraform outputs
# ---------------------------------------------------------------------------

log "==> Reading Terraform outputs for environment: $ENV"
cd "$INFRA_DIR"

if [[ ! -d ".terraform" ]]; then
  log "==> Running terraform init..."
  terraform init -backend-config="envs/${ENV}.backend.hcl" -input=false -reconfigure
fi

CLUSTER=$(terraform output -raw ecs_cluster_name)
REGION=$(terraform output -raw region)

# Map service folder name to ECS service name from Terraform outputs
case "$SERVICE" in
  web)       ECS_SERVICE=$(terraform output -raw ecs_web_service_name) ;;
  api-order) ECS_SERVICE=$(terraform output -raw ecs_api_service_name) ;;
  *)
    echo "ERROR: unknown service '$SERVICE'. Valid values: web, api-order"
    exit 1
    ;;
esac

log "   Cluster : $CLUSTER"
log "   Service : $ECS_SERVICE"
log "   Region  : $REGION"

# ---------------------------------------------------------------------------
# Force new deployment
# ---------------------------------------------------------------------------

log "==> Forcing new deployment..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --output json | jq -r '.service | "   Status  : \(.status)\n   Running : \(.runningCount)/\(.desiredCount) tasks"'

# ---------------------------------------------------------------------------
# Wait for stability
# ---------------------------------------------------------------------------

log "==> Waiting for service to stabilize (this may take a few minutes)..."
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$REGION"

log ""
log "==> Deployment complete: $SERVICE ($ENV)"
