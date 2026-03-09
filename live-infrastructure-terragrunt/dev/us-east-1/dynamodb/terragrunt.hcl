include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/dynamoDB"
}

inputs = {
  table_name = "${local.account_vars.locals.names.dynamodb_table_name}-${local.region_vars.locals.aws_region}"
  hash_key   = "id"
}
