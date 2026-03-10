include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/ecr"

  before_hook "module" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    execute  = ["echo", "Working in: ${path_relative_to_include("root")}"]
  }
}

inputs = {
  repository_names = local.account_vars.locals.ecr_repository_names
}
