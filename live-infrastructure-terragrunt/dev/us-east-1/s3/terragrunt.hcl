include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/s3"
}

inputs = {
  bucket_name       = "${local.account_vars.locals.cicd.artifact_bucket_prefix}-${local.region_vars.locals.aws_region}-${local.account_vars.locals.aws_account_id}"
  enable_versioning = true
}
