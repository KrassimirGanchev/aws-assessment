include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  iam_vars     = read_terragrunt_config(find_in_parent_folders("iam.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/iam"
}

inputs = {
  create_github_oidc_provider       = true
  github_oidc_subjects              = []
  github_repository                 = "${local.account_vars.locals.github_owner}/${local.account_vars.locals.github_repo}"
  github_branch                     = local.account_vars.locals.github_branch
  github_environments               = [local.account_vars.locals.environment]
  github_allow_pull_request_subject = true

  github_actions_role_name             = local.account_vars.locals.names.github_actions_role
  github_actions_managed_policy_arns   = local.iam_vars.locals.github_actions_managed_policy_arns
  github_actions_allowed_resource_arns = ["*"]

  ecs_task_execution_role_name = local.account_vars.locals.names.ecs_task_execution_role
  lambda_execution_role_name   = local.account_vars.locals.names.lambda_execution_role

  lambda_execution_managed_policy_arns = local.iam_vars.locals.lambda_execution_managed_policy_arns
  lambda_runtime_dynamodb_table_arns   = ["arn:aws:dynamodb:*:${local.account_vars.locals.aws_account_id}:table/${local.account_vars.locals.names.dynamodb_table_name}-*"]
  lambda_runtime_sns_topic_arns        = local.account_vars.locals.selected_sns_topic_arns
  lambda_runtime_ecs_cluster_arns     = ["arn:aws:ecs:*:${local.account_vars.locals.aws_account_id}:cluster/${local.account_vars.locals.names.ecs_cluster}-*"]
  lambda_runtime_task_definition_arns = ["arn:aws:ecs:*:${local.account_vars.locals.aws_account_id}:task-definition/${local.account_vars.locals.names.ecs_task_family}-*-dispatcher*"]
  lambda_runtime_passrole_arns        = ["arn:aws:iam::${local.account_vars.locals.aws_account_id}:role/${local.account_vars.locals.names.ecs_task_execution_role}"]
  ecs_runtime_sns_topic_arns           = local.account_vars.locals.selected_sns_topic_arns

}
