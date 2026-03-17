#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# force-cleanup.sh
#
# Clears all AWS resources that block terraform destroy:
#   1. Delete ALB — releases ALB ENIs, unblocks ALB SG
#   2. Stop ECS tasks — releases task ENIs
#   3. Revoke cross-module SG ingress rules — unblocks ECS tasks SG
#   4. Delete orphaned ENIs on ECS SG
#   5. Delete RDS instance — unblocks parameter group and subnet group
#   6. Delete Container Insights log group — AWS-managed, not tracked by Terraform
#
# Run this when terraform destroy stalls, then re-run terraform destroy.
#
# Usage:
#   ./infra/scripts/force-cleanup.sh <env>
#
# Dependencies: aws, terraform, jq
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${INFRA_DIR}/.env" ]]; then
  set -o allexport; source "${INFRA_DIR}/.env"; set +o allexport
fi

ENV="${1:-}"
if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <dev|staging>"
  exit 1
fi

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
skip() { echo "[$(date '+%H:%M:%S')] - $* (skipped — not found)"; }
fail() { echo "[$(date '+%H:%M:%S')] ✗ $*" >&2; }

cd "$INFRA_DIR"
REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "aws-upskill-${ENV}")
ECS_SG=$(terraform output -raw ecs_tasks_security_group_id 2>/dev/null || true)
DB_ID="aws-upskill-${ENV}-postgres"
ALB_NAME="aws-upskill-${ENV}-alb"

log "ENV=$ENV  REGION=$REGION  CLUSTER=$CLUSTER"

# ---------------------------------------------------------------------------
# 1. Delete ALB
# Lookup by name tag if describe-load-balancers by name fails.
# ---------------------------------------------------------------------------

log "==> [1/6] ALB: $ALB_NAME"

# Always list all ALBs and grep — avoids silent failures from --names throwing exceptions
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query  "LoadBalancers[?LoadBalancerName=='${ALB_NAME}'].LoadBalancerArn" \
  --output text)

log "  ARN lookup result: '${ALB_ARN}'"

if [[ -z "$ALB_ARN" || "$ALB_ARN" == "None" ]]; then
  skip "ALB"
else
  log "  Deleting ALB..."
  aws elbv2 delete-load-balancer \
    --load-balancer-arn "$ALB_ARN" \
    --region "$REGION"
  log "  Waiting for ALB to fully terminate (this takes ~1 min)..."
  aws elbv2 wait load-balancers-deleted \
    --load-balancer-arns "$ALB_ARN" \
    --region "$REGION"
  # Verify it is actually gone
  VERIFY=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query  "LoadBalancers[?LoadBalancerName=='${ALB_NAME}'].State.Code" \
    --output text)
  if [[ -z "$VERIFY" || "$VERIFY" == "None" ]]; then
    ok "ALB deleted and confirmed gone"
  else
    fail "ALB still present after wait (state: $VERIFY) — may need another attempt"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Stop ECS tasks
# ---------------------------------------------------------------------------

log "==> [2/6] ECS tasks in cluster: $CLUSTER"
TASKS=$(aws ecs list-tasks \
  --cluster "$CLUSTER" \
  --region  "$REGION" \
  --query   'taskArns[]' \
  --output  text 2>/dev/null || true)

if [[ -n "$TASKS" ]]; then
  for TASK in $TASKS; do
    aws ecs stop-task \
      --cluster "$CLUSTER" \
      --task    "$TASK" \
      --reason  "force-cleanup" \
      --region  "$REGION" > /dev/null
    log "  Stopped: $TASK"
  done
  ok "ECS tasks stopped"
else
  skip "ECS tasks"
fi

# ---------------------------------------------------------------------------
# 3. Revoke cross-module SG ingress rules
# ---------------------------------------------------------------------------

log "==> [3/6] Cross-SG ingress rules"

if [[ -n "$ECS_SG" ]]; then
  # Revoke rules in OTHER SGs that reference the ECS tasks SG (e.g. RDS SG)
  log "  Looking for SGs that reference ECS tasks SG ($ECS_SG)..."
  REF_SGS=$(aws ec2 describe-security-groups \
    --region  "$REGION" \
    --filters "Name=ip-permission.group-id,Values=${ECS_SG}" \
    --query   'SecurityGroups[].GroupId' \
    --output  text 2>/dev/null || true)

  if [[ -n "$REF_SGS" ]]; then
    for REF_SG in $REF_SGS; do
      log "  Revoking reference to ECS tasks SG in: $REF_SG"
      PERMS=$(aws ec2 describe-security-groups \
        --group-ids "$REF_SG" \
        --region    "$REGION" \
        --query     'SecurityGroups[0].IpPermissions' \
        --output    json 2>/dev/null || echo '[]')
      SG_RULES=$(echo "$PERMS" | jq "[.[] | select(.UserIdGroupPairs[].GroupId == \"${ECS_SG}\")]" 2>/dev/null || echo '[]')
      if [[ "$SG_RULES" != "[]" && -n "$SG_RULES" ]]; then
        aws ec2 revoke-security-group-ingress \
          --group-id       "$REF_SG" \
          --ip-permissions "$SG_RULES" \
          --region         "$REGION" > /dev/null 2>&1 || true
        log "  Revoked."
      else
        log "  No matching rules found in $REF_SG."
      fi
    done
  else
    log "  No SGs reference ECS tasks SG."
  fi

  # Revoke rules IN the ECS tasks SG that reference other SGs (e.g. ALB SG)
  log "  Looking for ingress rules inside ECS tasks SG that reference other SGs..."
  PERMS=$(aws ec2 describe-security-groups \
    --group-ids "$ECS_SG" \
    --region    "$REGION" \
    --query     'SecurityGroups[0].IpPermissions' \
    --output    json 2>/dev/null || echo '[]')
  SG_RULES=$(echo "$PERMS" | jq '[.[] | select(.UserIdGroupPairs | length > 0)]' 2>/dev/null || echo '[]')
  if [[ "$SG_RULES" != "[]" && -n "$SG_RULES" ]]; then
    aws ec2 revoke-security-group-ingress \
      --group-id       "$ECS_SG" \
      --ip-permissions "$SG_RULES" \
      --region         "$REGION" > /dev/null 2>&1 || true
    log "  Revoked ECS tasks SG cross-SG ingress rules."
  else
    log "  No cross-SG ingress rules inside ECS tasks SG."
  fi

  ok "Cross-SG rules cleared"
else
  skip "Cross-SG rules (ECS SG not found in terraform output)"
fi

# ---------------------------------------------------------------------------
# 4. Delete orphaned ENIs on ECS SG
# ---------------------------------------------------------------------------

log "==> [4/6] Orphaned ENIs"

if [[ -n "$ECS_SG" ]]; then
  ENIS=$(aws ec2 describe-network-interfaces \
    --region  "$REGION" \
    --filters "Name=group-id,Values=${ECS_SG}" \
    --query   'NetworkInterfaces[].NetworkInterfaceId' \
    --output  text 2>/dev/null || true)

  if [[ -n "$ENIS" ]]; then
    for ENI in $ENIS; do
      ATTACHMENT=$(aws ec2 describe-network-interfaces \
        --region                "$REGION" \
        --network-interface-ids "$ENI" \
        --query  'NetworkInterfaces[0].Attachment.AttachmentId' \
        --output text 2>/dev/null || true)
      if [[ "$ATTACHMENT" != "None" && -n "$ATTACHMENT" ]]; then
        aws ec2 detach-network-interface \
          --attachment-id "$ATTACHMENT" \
          --force \
          --region "$REGION" > /dev/null 2>&1 || true
        sleep 2
      fi
      aws ec2 delete-network-interface \
        --network-interface-id "$ENI" \
        --region "$REGION" > /dev/null 2>&1 || true
      log "  Deleted ENI: $ENI"
    done
    ok "ENIs deleted"
  else
    skip "Orphaned ENIs"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Delete RDS instance
# ---------------------------------------------------------------------------

log "==> [5/6] RDS: $DB_ID"
STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_ID" \
  --region "$REGION" \
  --query  'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "not-found")

if [[ "$STATUS" == "not-found" || "$STATUS" == "None" ]]; then
  skip "RDS"
elif [[ "$STATUS" == "deleting" ]]; then
  log "  Already deleting — waiting..."
  aws rds wait db-instance-deleted \
    --db-instance-identifier "$DB_ID" \
    --region "$REGION"
  ok "RDS deleted"
else
  log "  Status: $STATUS — deleting..."
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_ID" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region "$REGION" > /dev/null
  aws rds wait db-instance-deleted \
    --db-instance-identifier "$DB_ID" \
    --region "$REGION"
  ok "RDS deleted"
fi

# ---------------------------------------------------------------------------
# 6. Delete Container Insights log group
#
# AWS auto-creates this log group when the ECS cluster starts Container Insights.
# It is NOT managed by Terraform (Terraform only creates /aws/ecs/web and /aws/ecs/api).
# Must be deleted manually, otherwise it persists after destroy.
# ---------------------------------------------------------------------------

log "==> [6/6] Container Insights log group"
CW_LOG_GROUP="/aws/ecs/containerinsights/${CLUSTER}/performance"
aws logs delete-log-group \
  --log-group-name "$CW_LOG_GROUP" \
  --region         "$REGION" > /dev/null 2>&1 \
  && ok "Deleted log group: $CW_LOG_GROUP" \
  || skip "Container Insights log group (already gone or never created)"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
log "==> Pre-cleanup complete. Now run:"
log "    ./infra/scripts/deploy.sh $ENV destroy"
