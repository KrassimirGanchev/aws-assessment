include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "iam" {
  config_path = "../../_global/iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    lambda_execution_role_arn   = "arn:aws:iam::000000000000:role/mock-lambda"
    ecs_task_execution_role_arn = "arn:aws:iam::000000000000:role/mock-ecs"
  }
}

dependency "ecs" {
  config_path = "../ecs"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    cluster_name           = "mock-cluster"
    task_definition_arn    = "arn:aws:ecs:us-east-1:000000000000:task-definition/mock"
    public_subnet_ids      = ["subnet-a", "subnet-b"]
    public_subnet_ids_csv  = "subnet-a,subnet-b"
    task_security_group_id = "sg-12345"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/lambda"
}

inputs = {
  function_name      = "${local.account_vars.locals.names.lambda_dispatcher_function}-${local.region_vars.locals.aws_region}"
  role_arn           = dependency.iam.outputs.lambda_execution_role_arn
  runtime            = local.account_vars.locals.lambda.runtime
  handler            = "dispatcher.lambda_handler"
  source_package     = local.account_vars.locals.lambda.package_path
  timeout            = local.account_vars.locals.lambda.timeout
  memory_size        = local.account_vars.locals.lambda.memory_size
  log_retention_days = local.account_vars.locals.lambda.log_retention_days

  environment_variables = {
    ECS_CLUSTER_NAME        = dependency.ecs.outputs.cluster_name
    ECS_TASK_DEFINITION_ARN = dependency.ecs.outputs.task_definition_arn
    ECS_SUBNET_IDS          = dependency.ecs.outputs.public_subnet_ids_csv
    ECS_SECURITY_GROUP_ID   = dependency.ecs.outputs.task_security_group_id
    EXECUTION_REGION        = local.region_vars.locals.aws_region
  }
}
