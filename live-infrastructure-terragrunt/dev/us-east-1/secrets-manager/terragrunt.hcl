include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/secrets-manager"
}

inputs = {
  secret_name = local.account_vars.locals.candidate_test_password_secret_name
}
