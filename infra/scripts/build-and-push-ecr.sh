#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-and-push-ecr.sh
#
# Builds a Docker image from the monorepo and pushes it to ECR.
# Reads ECR repository URLs from Terraform outputs.
#
# Usage:
#   ./infra/scripts/build-and-push-ecr.sh <service> <env> [version]
#
#   service: folder name under apps/ (e.g. web, api-order)
#   env:     dev | staging
#   version: optional version tag (default: git short SHA)
#
# Examples:
#   ./infra/scripts/build-and-push-ecr.sh web dev
#   ./infra/scripts/build-and-push-ecr.sh api-order dev v1.2.3
#   ./infra/scripts/build-and-push-ecr.sh web staging v1.2.3
#
# Dependencies: docker, aws, terraform, git, jq
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

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
VERSION="${3:-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"

if [[ -z "$SERVICE" || -z "$ENV" ]]; then
  echo "Usage: $0 <service> <dev|staging> [version]"
  echo "  service: folder name under apps/ (e.g. web, api-order)"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: env must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

# Derive Dockerfile path from service folder name
DOCKERFILE="apps/${SERVICE}/Dockerfile"

if [[ ! -f "${REPO_ROOT}/${DOCKERFILE}" ]]; then
  echo "ERROR: Dockerfile not found at ${REPO_ROOT}/${DOCKERFILE}"
  echo "       Service must match a folder under apps/ (e.g. web, api-order)"
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

log "   Service      : $SERVICE"
log "   Environment  : $ENV"
log "   Version      : $VERSION"
log "   Dockerfile   : $DOCKERFILE"

# ---------------------------------------------------------------------------
# Build Docker image (first — fail fast before any AWS operations)
# ---------------------------------------------------------------------------

log "==> Building Docker image..."
cd "$REPO_ROOT"

docker build \
  --file "$DOCKERFILE" \
  --tag "${SERVICE}:${VERSION}" \
  --tag "${SERVICE}:latest" \
  --platform linux/amd64 \
  .

log "   Build complete."

# ---------------------------------------------------------------------------
# Image size check
# ---------------------------------------------------------------------------

MAX_SIZE_MB=500
IMAGE_SIZE_BYTES=$(docker inspect --format='{{.Size}}' "${SERVICE}:${VERSION}")
IMAGE_SIZE_MB=$(( IMAGE_SIZE_BYTES / 1024 / 1024 ))

log "   Image size: ${IMAGE_SIZE_MB}MB (limit: ${MAX_SIZE_MB}MB)"

if [[ $IMAGE_SIZE_MB -gt $MAX_SIZE_MB ]]; then
  echo "ERROR: Image size ${IMAGE_SIZE_MB}MB exceeds the ${MAX_SIZE_MB}MB limit."
  echo "       Review the Dockerfile to reduce image size before pushing."
  exit 1
fi

# ---------------------------------------------------------------------------
# Read Terraform outputs
# ---------------------------------------------------------------------------

log "==> Reading Terraform outputs for environment: $ENV"
cd "$INFRA_DIR"

if [[ ! -d ".terraform" ]]; then
  log "==> Running terraform init..."
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

# ---------------------------------------------------------------------------
# Authenticate Docker with ECR
# ---------------------------------------------------------------------------

log "==> Authenticating Docker with ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "${REGISTRY_ID}.dkr.ecr.${REGION}.amazonaws.com"

# ---------------------------------------------------------------------------
# Tag and push to ECR
# ---------------------------------------------------------------------------

docker tag "${SERVICE}:${VERSION}" "${REPO_URL}:${VERSION}"
docker tag "${SERVICE}:latest"    "${REPO_URL}:latest"

log "==> Pushing ${REPO_URL}:${VERSION}..."
docker push "${REPO_URL}:${VERSION}"

log "==> Pushing ${REPO_URL}:latest..."
docker push "${REPO_URL}:latest"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${REPO_URL}:${VERSION}" 2>/dev/null || echo "unavailable")

log ""
log "==> Push complete!"
log "   Image  : ${REPO_URL}:${VERSION}"
log "   Digest : ${DIGEST}"
