include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "secrets_manager" {
  config_path = "../secrets-manager"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock-cognito-temp-password"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/cognito"
}

inputs = {
  user_pool_name                          = "${local.account_vars.locals.names.user_pool_name}-${local.region_vars.locals.aws_region}"
  user_pool_client_name                   = "${local.account_vars.locals.names.user_pool_client_name}-${local.region_vars.locals.aws_region}"
  test_user_email                         = local.account_vars.locals.candidate_email
  create_test_user                        = !local.account_vars.locals.post_validation_disable_test_user
  test_user_temporary_password_secret_arn = dependency.secrets_manager.outputs.secret_arn
}
