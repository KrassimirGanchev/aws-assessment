include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    vpc_id             = "vpc-000000"
    public_subnet_ids  = ["subnet-000001", "subnet-000002"]
    private_subnet_ids = ["subnet-000003", "subnet-000004"]
  }
}

dependency "iam" {
  config_path = "../../_global/iam"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    ecs_task_execution_role_arn = "arn:aws:iam::000000000000:role/mock-ecs-task-execution"
  }
}

dependency "ecr" {
  config_path = "../../us-east-1/ecr"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    repository_urls = {
      aws-assessment-dev-ecs = "000000000000.dkr.ecr.us-east-1.amazonaws.com/aws-assessment-dev-ecs"
    }
  }
}

dependency "sns" {
  config_path = "../../us-east-1/sns"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:000000000000:mock-topic"
  }
}

terraform {
  source = "${get_repo_root()}/modules-terraform/ecs"
}

inputs = {
  aws_region         = local.region_vars.locals.aws_region
  cluster_name       = "${local.account_vars.locals.names.ecs_cluster}-${local.region_vars.locals.aws_region}"
  task_family        = "${local.account_vars.locals.names.ecs_task_family}-${local.region_vars.locals.aws_region}-dispatcher"
  container_name     = local.account_vars.locals.names.ecs_container
  container_image    = "${dependency.ecr.outputs.repository_urls[local.account_vars.locals.ecs_ecr_repository]}:latest"
  container_command  = []
  cpu                = local.account_vars.locals.ecs.cpu
  memory             = local.account_vars.locals.ecs.memory
  vpc_id             = dependency.vpc.outputs.vpc_id
  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  execution_role_arn = dependency.iam.outputs.ecs_task_execution_role_arn
  task_role_arn      = dependency.iam.outputs.ecs_task_execution_role_arn
  environment_variables = {
    SNS_TOPIC_ARNS     = "${local.account_vars.locals.selected_candidate_sns_topic_arn},${local.account_vars.locals.selected_assessor_sns_topic_arn}"
    CANDIDATE_EMAIL    = local.account_vars.locals.candidate_email
    CANDIDATE_REPO_URL = local.account_vars.locals.candidate_repo_url
    EXECUTION_REGION   = local.region_vars.locals.aws_region
  }
  log_retention_days = local.account_vars.locals.ecs.log_retention_days
}
