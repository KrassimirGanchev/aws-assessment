output "github_oidc_provider_arn" {
  value = local.github_oidc_provider_arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}