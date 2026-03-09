include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "iam" {
  config_path = "../../_global/iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    lambda_execution_role_arn = "arn:aws:iam::000000000000:role/mock-lambda"
  }
}

dependency "dynamodb" {
  config_path = "../dynamodb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    table_name = "GreetingLogs-eu-west-1"
  }
}

dependency "sns" {
  config_path = "../../us-east-1/sns"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:000000000000:mock-topic"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/lambda"
}

inputs = {
  function_name      = "${local.account_vars.locals.names.lambda_greeter_function}-${local.region_vars.locals.aws_region}"
  role_arn           = dependency.iam.outputs.lambda_execution_role_arn
  runtime            = local.account_vars.locals.lambda.runtime
  handler            = "greeter.lambda_handler"
  source_package     = local.account_vars.locals.lambda.package_path
  timeout            = local.account_vars.locals.lambda.timeout
  memory_size        = local.account_vars.locals.lambda.memory_size
  log_retention_days = local.account_vars.locals.lambda.log_retention_days

  environment_variables = {
    DYNAMODB_TABLE     = dependency.dynamodb.outputs.table_name
    SNS_TOPIC_ARNS     = "${local.account_vars.locals.selected_candidate_sns_topic_arn},${local.account_vars.locals.selected_assessor_sns_topic_arn}"
    CANDIDATE_EMAIL    = local.account_vars.locals.candidate_email
    CANDIDATE_REPO_URL = local.account_vars.locals.candidate_repo_url
    EXECUTION_REGION   = local.region_vars.locals.aws_region
  }
}
