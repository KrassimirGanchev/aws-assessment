include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    bucket_id = "mock-bucket"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/cicd-ecs"
}

inputs = {
  aws_region                = local.region_vars.locals.aws_region
  pipeline_name             = "aws-assessment-dev-ecs-pipeline-${local.region_vars.locals.aws_region}"
  build_project_name        = "aws-assessment-dev-ecs-build-${local.region_vars.locals.aws_region}"
  artifact_bucket_name      = dependency.s3.outputs.bucket_id
  codestar_connection_arn   = local.account_vars.locals.codestar_connection_arn
  github_full_repository_id = "${local.account_vars.locals.github_owner}/${local.account_vars.locals.github_repo}"
  github_branch             = local.account_vars.locals.github_branch
  buildspec_path            = local.account_vars.locals.cicd.ecs_buildspec_path
  ecr_repository_name       = local.account_vars.locals.ecs_ecr_repository
  ecs_container_name        = local.account_vars.locals.names.ecs_container
  codepipeline_role_name    = "aws-assessment-dev-cp-ecs-${local.region_vars.locals.aws_region}"
  codebuild_role_name       = "aws-assessment-dev-cb-ecs-${local.region_vars.locals.aws_region}"
}
