#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# push-ecr.sh
#
# Pushes a pre-built local Docker image to ECR.
# Use this when the image is already built and only needs to be pushed.
# For build + push in one step, use build-and-push-ecr.sh instead.
#
# Usage:
#   ./infra/scripts/push-ecr.sh <service> <env> [version]
#
#   service: folder name under apps/ (e.g. web, api-order)
#   env:     dev | staging
#   version: optional version tag (default: git short SHA)
#
# Examples:
#   ./infra/scripts/push-ecr.sh web dev
#   ./infra/scripts/push-ecr.sh api-order staging v1.2.3
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

if [[ -f "${INFRA_DIR}/.env" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "${INFRA_DIR}/.env"
  set +o allexport
fi

SERVICE="${1:-}"
ENV="${2:-}"
VERSION="${3:-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"

if [[ -z "$SERVICE" || -z "$ENV" ]]; then
  echo "Usage: $0 <service> <dev|staging> [version]"
  echo "  service: folder name under apps/ (e.g. web, api-order)"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: env must be 'dev' or 'staging'"
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies check
# ---------------------------------------------------------------------------

for cmd in docker aws terraform git jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
done

log() { echo "[$(date '+%H:%M:%S')] $*"; }

cd "$INFRA_DIR"

if [[ ! -d ".terraform" ]]; then
  terraform init -backend-config="envs/${ENV}.backend.hcl" -input=false -reconfigure
fi

REPO_URL=$(terraform output -json ecr_repository_urls | jq -r ".\"${SERVICE}\"")

if [[ -z "$REPO_URL" || "$REPO_URL" == "null" ]]; then
  echo "ERROR: No ECR repository found for service '${SERVICE}'"
  echo "       Available services: $(terraform output -json ecr_repository_urls | jq -r 'keys[]' | tr '\n' ' ')"
  exit 1
fi

REGISTRY_ID=$(terraform output -raw ecr_registry_id)
REGION=$(terraform output -raw region)

# Check image exists locally
if ! docker image inspect "${REPO_URL}:${VERSION}" &>/dev/null; then
  echo "ERROR: Image not found locally: ${REPO_URL}:${VERSION}"
  echo "       Build it first with: ./infra/scripts/build-and-push-ecr.sh $SERVICE $ENV $VERSION"
  exit 1
fi

log "==> Authenticating Docker with ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "${REGISTRY_ID}.dkr.ecr.${REGION}.amazonaws.com"

log "==> Pushing ${REPO_URL}:${VERSION}..."
docker push "${REPO_URL}:${VERSION}"

docker tag "${REPO_URL}:${VERSION}" "${REPO_URL}:latest"
log "==> Pushing ${REPO_URL}:latest..."
docker push "${REPO_URL}:latest"

log "==> Push complete: ${REPO_URL}:${VERSION}"
