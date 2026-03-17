# ---------------------------------------------------------------------------
# Budgets Module
#
# Creates an AWS Budget for this environment filtered by CostCenter tag.
# Sends email alerts at 50%, 75%, and 100% of the monthly budget.
#
# The budget tracks actual spend (not forecasted) against the monthly limit.
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "env" {
  name         = "${var.project_name}-${var.environment_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Filter to costs tagged with this environment's CostCenter tag.
  # This ensures dev budget only counts dev resources and vice versa.
  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:CostCenter$%s", var.cost_center)]
  }

  # Alert at 50% — early warning to investigate unexpected spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Alert at 75% — action threshold to review and reduce spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 75
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Alert at 100% — budget exceeded, immediate action required
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
