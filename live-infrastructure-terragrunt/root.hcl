locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = try(read_terragrunt_config(find_in_parent_folders("region.hcl")), { locals = { aws_region = local.account_vars.locals.state_region } })
}

terraform {
  before_hook "module" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    execute  = ["echo", "Working in: ${path_relative_to_include()}"]
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = local.account_vars.locals.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.account_vars.locals.state_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
	required_version = ">= 1.14.0"
	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = ">= 6.0"
		}
	}
}

provider "aws" {
	region = "${local.region_vars.locals.aws_region}"

	default_tags {
		tags = ${jsonencode(local.account_vars.locals.common_tags)}
	}
}
EOF
}
