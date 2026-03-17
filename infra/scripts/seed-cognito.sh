#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# seed-cognito.sh
#
# Creates one test user per role in the Cognito User Pool after terraform apply.
# Idempotent — safe to run multiple times.
#
# Usage:
#   ./infra/scripts/seed-cognito.sh <env>
#
#   env: dev | staging
#
# Required environment variable:
#   COGNITO_SEED_PASSWORD — must meet Cognito complexity:
#     min 8 chars, uppercase, lowercase, number, special character
#     Example: MyTestPass1!
#
# Set in infra/.env (git-ignored) or export before running:
#   COGNITO_SEED_PASSWORD=MyTestPass1! ./infra/scripts/seed-cognito.sh dev
#
# Dependencies: aws, terraform, jq
#
# Seed users created:
#   seed-admin@example.com      → group: admin
#   seed-moderator@example.com  → group: moderator
#   seed-user@example.com       → group: user
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
  echo "ERROR: environment argument required"
  echo "Usage: $0 <dev|staging>"
  exit 1
fi

if [[ "$ENV" != "dev" && "$ENV" != "staging" ]]; then
  echo "ERROR: environment must be 'dev' or 'staging', got: $ENV"
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate required env var
# ---------------------------------------------------------------------------

if [[ -z "${COGNITO_SEED_PASSWORD:-}" ]]; then
  echo "ERROR: COGNITO_SEED_PASSWORD env var is required"
  echo "Set it in infra/.env or export it before running:"
  echo "  COGNITO_SEED_PASSWORD=MyTestPass1! $0 $ENV"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
skip() { echo "[$(date '+%H:%M:%S')] → $*"; }

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

for cmd in aws terraform; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Read Terraform outputs
# ---------------------------------------------------------------------------

cd "$INFRA_DIR"

TFVARS="envs/${ENV}.tfvars"
BACKEND_CFG="envs/${ENV}.backend.hcl"

log "==> Initialising Terraform backend for: $ENV"
terraform init -reconfigure -backend-config="$BACKEND_CFG" -input=false -no-color 2>&1 | tail -1

log "==> Reading outputs from Terraform state..."
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
REGION=$(terraform output -raw region)
COGNITO_DOMAIN_URL=$(terraform output -raw cognito_domain_url)

if [[ -z "$USER_POOL_ID" ]]; then
  echo "ERROR: cognito_user_pool_id output is empty — run terraform apply first"
  exit 1
fi

log "    User Pool ID : $USER_POOL_ID"
log "    Region       : $REGION"
log "    Hosted UI    : $COGNITO_DOMAIN_URL"
log ""

# ---------------------------------------------------------------------------
# Seed users
#
# Format per entry: "username:email:group:given_name:family_name"
# ---------------------------------------------------------------------------

declare -a USERS=(
  "seed-admin:seed-admin@example.com:admin:Admin:Seed"
  "seed-moderator:seed-moderator@example.com:moderator:Moderator:Seed"
  "seed-user:seed-user@example.com:user:User:Seed"
)

for entry in "${USERS[@]}"; do
  IFS=":" read -r USERNAME EMAIL GROUP GIVEN_NAME FAMILY_NAME <<< "$entry"

  AVATAR_URL="https://api.dicebear.com/9.x/avataaars/svg?seed=${USERNAME}"

  log "==> Processing: $USERNAME ($EMAIL) → group: $GROUP"

  # ------------------------------------------------------------------
  # Create user (idempotent — skip if already exists)
  # ------------------------------------------------------------------

  if aws cognito-idp admin-get-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --region "$REGION" \
      &>/dev/null; then
    skip "User $EMAIL already exists — skipping creation"
  else
    log "    Creating user..."
    aws cognito-idp admin-create-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --message-action SUPPRESS \
      --temporary-password "$COGNITO_SEED_PASSWORD" \
      --user-attributes \
        Name=email,Value="$EMAIL" \
        Name=email_verified,Value=true \
        Name=name,Value="${GIVEN_NAME} ${FAMILY_NAME}" \
        Name=given_name,Value="$GIVEN_NAME" \
        Name=family_name,Value="$FAMILY_NAME" \
        Name=picture,Value="$AVATAR_URL" \
        Name=gender,Value=other \
        Name=locale,Value=en-GB \
        Name=zoneinfo,Value=Europe/London \
        Name=birthdate,Value=1990-01-01 \
      --region "$REGION" \
      > /dev/null

    # Set permanent password — bypasses Cognito force-change-password flow
    aws cognito-idp admin-set-user-password \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --password "$COGNITO_SEED_PASSWORD" \
      --permanent \
      --region "$REGION"

    ok "User $EMAIL created"
  fi

  # ------------------------------------------------------------------
  # Add to group (idempotent — skip if already a member)
  # ------------------------------------------------------------------

  CURRENT_GROUPS=$(aws cognito-idp admin-list-groups-for-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EMAIL" \
    --region "$REGION" \
    --query "Groups[].GroupName" \
    --output text 2>/dev/null || echo "")

  if echo "$CURRENT_GROUPS" | grep -qw "$GROUP"; then
    skip "User $EMAIL already in group $GROUP"
  else
    aws cognito-idp admin-add-user-to-group \
      --user-pool-id "$USER_POOL_ID" \
      --username "$EMAIL" \
      --group-name "$GROUP" \
      --region "$REGION"
    ok "User $EMAIL added to group $GROUP"
  fi

  log ""
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log "==> Seed complete for environment: $ENV"
log ""
log "Test users:"
log "  seed-admin@example.com      → group: admin"
log "  seed-moderator@example.com  → group: moderator"
log "  seed-user@example.com       → group: user"
log ""
log "Password for all users: \$COGNITO_SEED_PASSWORD (from .env)"
log ""
log "Sign in at:"
log "  $COGNITO_DOMAIN_URL"
log ""
