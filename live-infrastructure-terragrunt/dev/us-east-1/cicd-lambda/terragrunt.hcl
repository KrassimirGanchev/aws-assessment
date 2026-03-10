include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "lambda" {
  config_path = "../lambda-greeter"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    function_name = "mock-greeter"
  }
}

dependency "dispatcher_lambda" {
  config_path = "../lambda-dispatcher"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    function_name = "mock-dispatcher"
  }
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    bucket_id = "mock-bucket"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/cicd-lambda"

  before_hook "module" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    execute  = ["echo", "Working in: ${path_relative_to_include("root")}"]
  }
}

inputs = {
  pipeline_name                   = "aws-assessment-dev-lambda-pipeline-${local.region_vars.locals.aws_region}"
  build_project_name              = "aws-assessment-dev-lambda-build-${local.region_vars.locals.aws_region}"
  artifact_bucket_name            = dependency.s3.outputs.bucket_id
  codestar_connection_arn         = local.account_vars.locals.codestar_connection_arn
  github_full_repository_id       = "${local.account_vars.locals.github_owner}/${local.account_vars.locals.github_repo}"
  github_branch                   = local.account_vars.locals.github_branch
  buildspec_path                  = local.account_vars.locals.cicd.lambda_buildspec_path
  lambda_function_name            = dependency.lambda.outputs.function_name
  dispatcher_lambda_function_name = dependency.dispatcher_lambda.outputs.function_name
  codepipeline_role_name          = "aws-assessment-dev-cp-lambda-${local.region_vars.locals.aws_region}"
  codebuild_role_name             = "aws-assessment-dev-cb-lambda-${local.region_vars.locals.aws_region}"
}
