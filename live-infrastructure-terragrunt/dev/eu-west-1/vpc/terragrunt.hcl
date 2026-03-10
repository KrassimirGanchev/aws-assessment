include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules-terraform/vpc"

  before_hook "module" {
    commands = ["init", "validate", "plan", "apply", "destroy"]
    execute  = ["echo", "Working in: ${path_relative_to_include("root")}"]
  }
}

inputs = {
  name                   = local.region_vars.locals.vpc.name
  vpc_cidr               = local.region_vars.locals.vpc.vpc_cidr
  availability_zones     = local.region_vars.locals.availability_zones
  public_subnet_cidrs    = local.region_vars.locals.vpc.public_subnet_cidrs
  create_private_subnets = local.region_vars.locals.vpc.create_private_subnets
  private_subnet_cidrs   = local.region_vars.locals.vpc.private_subnet_cidrs
  enable_nat_gateway     = local.region_vars.locals.vpc.enable_nat_gateway
  single_nat_gateway     = local.region_vars.locals.vpc.single_nat_gateway
}
