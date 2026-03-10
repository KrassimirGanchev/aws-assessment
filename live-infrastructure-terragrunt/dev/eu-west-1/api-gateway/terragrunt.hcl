include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "lambda_greeter" {
  config_path = "../lambda-greeter"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    function_name = "mock-greeter"
    invoke_arn    = "arn:aws:lambda:eu-west-1:000000000000:function:mock-greeter"
  }
}

dependency "lambda_dispatcher" {
  config_path = "../lambda-dispatcher"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    function_name = "mock-dispatcher"
    invoke_arn    = "arn:aws:lambda:eu-west-1:000000000000:function:mock-dispatcher"
  }
}

dependency "cognito" {
  config_path = "../../us-east-1/cognito"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    user_pool_id        = "us-east-1_mock"
    user_pool_client_id = "mockclient"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/api-gateway"

  before_hook "module" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    execute  = ["echo", "Working in: ${path_relative_to_include("root")}"]
  }
}

inputs = {
  api_name                        = "${local.account_vars.locals.names.api_name}-${local.region_vars.locals.aws_region}"
  greeter_lambda_function_name    = dependency.lambda_greeter.outputs.function_name
  greeter_lambda_invoke_arn       = dependency.lambda_greeter.outputs.invoke_arn
  dispatcher_lambda_function_name = dependency.lambda_dispatcher.outputs.function_name
  dispatcher_lambda_invoke_arn    = dependency.lambda_dispatcher.outputs.invoke_arn
  cognito_user_pool_id            = dependency.cognito.outputs.user_pool_id
  cognito_user_pool_client_id     = dependency.cognito.outputs.user_pool_client_id
  cognito_user_pool_region        = local.account_vars.locals.auth_region
  throttling_burst_limit          = local.account_vars.locals.api_throttling_burst_limit
  throttling_rate_limit           = local.account_vars.locals.api_throttling_rate_limit
  enable_waf                      = local.account_vars.locals.api_enable_waf
  waf_web_acl_arn                 = local.account_vars.locals.api_waf_web_acl_arn
}
