#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# dev-docker.sh
#
# Build and run Docker images locally for development/testing.
#
# Usage:
#   ./infra/scripts/dev-docker.sh <command> [service]
#
#   command: build | run | verify | clean
#   service: web | api-order | all (default: all)
#
# Examples:
#   ./infra/scripts/dev-docker.sh build             # build both
#   ./infra/scripts/dev-docker.sh build web         # build web only
#   ./infra/scripts/dev-docker.sh run               # run both
#   ./infra/scripts/dev-docker.sh run api-order     # run api-order only
#   ./infra/scripts/dev-docker.sh verify            # build, run, health check, clean up
#   ./infra/scripts/dev-docker.sh clean             # remove local images
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

COMMAND="${1:-}"
SERVICE="${2:-all}"

WEB_PORT=3300
API_PORT=3301
IMAGE_TAG="local"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

usage() {
  echo "Usage: $0 <build|run|verify|clean> [web|api-order|all]"
  exit 1
}

if [[ -z "$COMMAND" ]]; then
  usage
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

image_name() {
  local svc="$1"
  echo "aws-upskill-${svc}:${IMAGE_TAG}"
}

build_service() {
  local svc="$1"
  local dockerfile="${REPO_ROOT}/apps/${svc}/Dockerfile"

  if [[ ! -f "$dockerfile" ]]; then
    echo "ERROR: Dockerfile not found: $dockerfile"
    exit 1
  fi

  log "==> Building $(image_name "$svc")..."
  docker build \
    --file "$dockerfile" \
    --tag "$(image_name "$svc")" \
    "$REPO_ROOT"
  log "   Done: $(image_name "$svc")"
}

run_service() {
  local svc="$1"
  local port

  if [[ "$svc" == "web" ]]; then
    port=$WEB_PORT
  else
    port=$API_PORT
  fi

  log "==> Starting $(image_name "$svc") on port $port..."
  log "   Stop with Ctrl+C"
  docker run --rm \
    -p "${port}:${port}" \
    --name "aws-upskill-${svc}" \
    "$(image_name "$svc")"
}

health_check() {
  local svc="$1"
  local port
  local path

  if [[ "$svc" == "web" ]]; then
    port=$WEB_PORT
    path="/nextapi/health"
  else
    port=$API_PORT
    path="/api/health"
  fi

  local url="http://localhost:${port}${path}"
  local max_attempts=15
  local attempt=0

  log "   Waiting for $svc to be ready at $url..."
  until curl -sf "$url" -o /dev/null 2>/dev/null; do
    attempt=$((attempt + 1))
    if [[ $attempt -ge $max_attempts ]]; then
      echo "ERROR: $svc did not respond after $max_attempts seconds"
      return 1
    fi
    sleep 1
  done

  local response
  response=$(curl -sf "$url")
  log "   $svc health check OK: $response"
}

stop_service() {
  local svc="$1"
  if docker ps -q --filter "name=aws-upskill-${svc}" | grep -q .; then
    log "==> Stopping $svc container..."
    docker stop "aws-upskill-${svc}" &>/dev/null || true
  fi
}

clean_service() {
  local svc="$1"
  stop_service "$svc"
  if docker image inspect "$(image_name "$svc")" &>/dev/null; then
    log "==> Removing $(image_name "$svc")..."
    docker rmi "$(image_name "$svc")"
  fi
}

services_for() {
  if [[ "$1" == "all" ]]; then
    echo "web api-order"
  else
    echo "$1"
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

case "$COMMAND" in
  build)
    for svc in $(services_for "$SERVICE"); do
      build_service "$svc"
    done

    log ""
    log "==> Image sizes:"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" \
      $(for svc in $(services_for "$SERVICE"); do echo "$(image_name "$svc")"; done)
    ;;

  run)
    if [[ "$SERVICE" == "all" ]]; then
      echo "ERROR: cannot run both services in foreground at once."
      echo "       Run each in a separate terminal:"
      echo "         $0 run web"
      echo "         $0 run api-order"
      exit 1
    fi
    run_service "$SERVICE"
    ;;

  verify)
    # Build, start in background, health check, print sizes, clean up
    SVCS=$(services_for "$SERVICE")

    log "==> Building images..."
    for svc in $SVCS; do
      build_service "$svc"
    done

    log ""
    log "==> Starting containers in background..."
    for svc in $SVCS; do
      local_port=$WEB_PORT
      [[ "$svc" != "web" ]] && local_port=$API_PORT
      docker run -d --rm \
        -p "${local_port}:${local_port}" \
        --name "aws-upskill-${svc}" \
        "$(image_name "$svc")" > /dev/null
      log "   Started $svc (port $local_port)"
    done

    log ""
    log "==> Running health checks..."
    FAILED=0
    for svc in $SVCS; do
      health_check "$svc" || FAILED=1
    done

    log ""
    log "==> Image sizes:"
    MAX_SIZE_MB=500
    SIZE_FAILED=0
    for svc in $SVCS; do
      SIZE_BYTES=$(docker inspect --format='{{.Size}}' "$(image_name "$svc")")
      SIZE_MB=$(( SIZE_BYTES / 1024 / 1024 ))
      if [[ $SIZE_MB -gt $MAX_SIZE_MB ]]; then
        log "   WARNING: $(image_name "$svc") is ${SIZE_MB}MB — exceeds ${MAX_SIZE_MB}MB limit"
        SIZE_FAILED=1
      else
        log "   OK: $(image_name "$svc") is ${SIZE_MB}MB (limit: ${MAX_SIZE_MB}MB)"
      fi
    done

    log ""
    log "==> Stopping containers..."
    for svc in $SVCS; do
      stop_service "$svc"
    done

    if [[ $FAILED -eq 1 || $SIZE_FAILED -eq 1 ]]; then
      echo ""
      [[ $FAILED -eq 1 ]] && echo "ERROR: One or more health checks failed."
      [[ $SIZE_FAILED -eq 1 ]] && echo "ERROR: One or more images exceed the 500MB size limit."
      exit 1
    fi

    log ""
    log "==> Verify complete. All services healthy."
    ;;

  clean)
    for svc in $(services_for "$SERVICE"); do
      clean_service "$svc"
    done
    log "==> Clean complete."
    ;;

  *)
    echo "ERROR: unknown command '$COMMAND'"
    usage
    ;;
esac
