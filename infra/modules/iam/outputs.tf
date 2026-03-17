output "execution_role_arn" {
  description = "ARN of the ECS task execution role (used by ECS agent to pull images and write logs)."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "web_task_role_arn" {
  description = "ARN of the web service task role (assumed by the Next.js container at runtime)."
  value       = aws_iam_role.web_task.arn
}

output "api_task_role_arn" {
  description = "ARN of the API service task role (assumed by the NestJS container at runtime)."
  value       = aws_iam_role.api_task.arn
}
