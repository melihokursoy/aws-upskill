output "budget_name" {
  description = "Name of the AWS Budget created for this environment."
  value       = aws_budgets_budget.env.name
}
