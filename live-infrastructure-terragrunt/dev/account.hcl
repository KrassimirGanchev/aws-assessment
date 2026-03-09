locals {
  environment    = "dev"
  project        = "aws-assessment"
  aws_account_id = "693389441907"
  regions        = ["us-east-1", "eu-west-1"]

  github_owner  = "KrassimirGanchev"
  github_repo   = "aws-assessment"
  github_branch = "main"

  codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:693389441907:connection/101aea7b-0f41-495b-85f7-3b4f9ba182ef"

  candidate_email                     = "krassimir.ganchev@gmail.com"
  candidate_test_password_secret_name = "aws-assessment/dev/cognito-temp-password"
  candidate_repo_url                  = "https://github.com/KrassimirGanchev/aws-assessment"
  unleash_verification_topic_arn      = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
  sns_topic_name                      = "aws-assessment-dev-candidate-verification"
  use_candidate_sns_topic             = true
  use_assessor_sns_topic              = true
  sns_email_subscribers = [
    "krassimir.ganchev@gmail.com"
  ]
  candidate_sns_topic_arn          = "arn:aws:sns:us-east-1:${local.aws_account_id}:${local.sns_topic_name}"
  selected_candidate_sns_topic_arn = lookup({ true = local.candidate_sns_topic_arn, false = "" }, local.use_candidate_sns_topic, "")
  selected_assessor_sns_topic_arn  = lookup({ true = local.unleash_verification_topic_arn, false = "" }, local.use_assessor_sns_topic, "")
  selected_sns_topic_arns          = compact([local.selected_candidate_sns_topic_arn, local.selected_assessor_sns_topic_arn])
  auth_region = "us-east-1"

  api_throttling_burst_limit = 20
  api_throttling_rate_limit  = 10
  api_enable_waf             = false
  api_waf_web_acl_arn        = ""

  post_validation_disable_test_user = false

  state_region = "eu-west-1"
  state_bucket = "aws-assessment-dev-tfstate-693389441907"

  common_tags = {
    Project     = "aws-assessment"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  names = {
    github_actions_role        = "aws-assessment-dev-gha-deploy"
    ecs_task_execution_role    = "aws-assessment-dev-ecs-exec"
    lambda_execution_role      = "aws-assessment-dev-lambda-exec"
    lambda_greeter_function    = "aws-assessment-dev-greeter"
    lambda_dispatcher_function = "aws-assessment-dev-dispatcher"
    ecs_cluster                = "aws-assessment-dev-cluster"
    ecs_task_family            = "aws-assessment-dev-task"
    ecs_container              = "sns-dispatcher"
    api_name                   = "aws-assessment-dev-http-api"
    user_pool_name             = "aws-assessment-dev-user-pool"
    user_pool_client_name      = "aws-assessment-dev-user-pool-client"
    dynamodb_table_name        = "GreetingLogs"
  }

  ecr_repository_names = [
    "aws-assessment-dev-ecs"
  ]

  ecs_ecr_repository = "aws-assessment-dev-ecs"

  lambda = {
    runtime            = "python3.11"
    timeout            = 30
    memory_size        = 256
    package_path       = "${get_repo_root()}/Source/lambda/lambda_bundle.zip"
    log_retention_days = 14
    environment_variables = {
      APP_ENV = "dev"
    }
  }

  ecs = {
    cpu                = 256
    memory             = 512
    assign_public_ip   = true
    log_retention_days = 14
    environment_variables = {
      APP_ENV = "dev"
    }
  }

  cicd = {
    artifact_bucket_prefix = "aws-assessment-dev-artifacts"
    ecs_buildspec_path     = "Source/ecs/buildspec.yml"
    lambda_buildspec_path  = "Source/lambda/buildspec.yml"
  }
}
