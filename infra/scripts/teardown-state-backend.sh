#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# teardown-state-backend.sh
#
# Removes the S3 bucket and DynamoDB table used for Terraform remote state.
# Run this ONLY after all environments have been destroyed with deploy.sh.
#
# WARNING: This permanently deletes all Terraform state. You will not be
#          able to manage existing AWS resources with Terraform after this.
#
# Usage:
#   ./infra/scripts/teardown-state-backend.sh
# ---------------------------------------------------------------------------

set -euo pipefail

STATE_BUCKET="terraform-aws-upskill-state"
LOCK_TABLE="terraform-aws-upskill-locks"
REGION="us-east-1"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

echo ""
echo "WARNING: This will permanently delete:"
echo "  S3 bucket  : $STATE_BUCKET (all Terraform state files)"
echo "  DynamoDB   : $LOCK_TABLE (state lock table)"
echo ""
echo "Ensure all environments are destroyed before proceeding."
echo "  ./infra/scripts/deploy.sh dev destroy"
echo "  ./infra/scripts/deploy.sh staging destroy"
echo ""
read -r -p "Type 'delete state' to confirm: " CONFIRM

if [[ "$CONFIRM" != "delete state" ]]; then
  echo "Aborted."
  exit 1
fi

# ---------------------------------------------------------------------------
# Empty and delete S3 bucket
# ---------------------------------------------------------------------------

log "==> Deleting all object versions from s3://$STATE_BUCKET ..."

# Delete all versioned objects
VERSIONS=$(aws s3api list-object-versions \
  --bucket "$STATE_BUCKET" \
  --region "$REGION" \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null || echo '{"Objects": null}')

if [[ $(echo "$VERSIONS" | jq '.Objects | length') -gt 0 ]]; then
  echo "$VERSIONS" | aws s3api delete-objects \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --delete "$(echo "$VERSIONS" | jq '{Objects: .Objects, Quiet: true}')" \
    --output table
fi

# Delete all delete markers
MARKERS=$(aws s3api list-object-versions \
  --bucket "$STATE_BUCKET" \
  --region "$REGION" \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json 2>/dev/null || echo '{"Objects": null}')

if [[ $(echo "$MARKERS" | jq '.Objects | length') -gt 0 ]]; then
  echo "$MARKERS" | aws s3api delete-objects \
    --bucket "$STATE_BUCKET" \
    --region "$REGION" \
    --delete "$(echo "$MARKERS" | jq '{Objects: .Objects, Quiet: true}')" \
    --output table
fi

log "==> Deleting S3 bucket: $STATE_BUCKET"
aws s3api delete-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$REGION"
log "    Deleted: s3://$STATE_BUCKET"

# ---------------------------------------------------------------------------
# Delete DynamoDB table
# ---------------------------------------------------------------------------

log "==> Deleting DynamoDB table: $LOCK_TABLE"
aws dynamodb delete-table \
  --table-name "$LOCK_TABLE" \
  --region "$REGION" \
  --output table
log "    Deleted: $LOCK_TABLE"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

log ""
log "==> State backend removed."
log "    To recreate it, run the setup commands in infra/README.md."
