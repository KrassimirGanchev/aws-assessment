variable "create_github_oidc_provider" {
  type    = bool
  default = true
}

variable "github_oidc_provider_arn" {
  type    = string
  default = ""
}

# GitHub Actions OIDC TLS thumbprint for https://token.actions.githubusercontent.com.
# If GitHub rotates certificates, verify/update from:
# - https://token.actions.githubusercontent.com
# - https://token.actions.githubusercontent.com/.well-known/openid-configuration
# - https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
variable "github_oidc_thumbprints" {
  type = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

variable "github_oidc_subjects" {
  type = list(string)
}

variable "github_actions_role_name" {
  type = string
}

variable "github_actions_managed_policy_arns" {
  type = list(string)
}

variable "github_actions_allowed_actions" {
  type = list(string)
  default = [
    "apigateway:*",
    "cloudwatch:*",
    "cognito-idp:*",
    "codebuild:*",
    "codepipeline:*",
    "codestar-connections:UseConnection",
    "dynamodb:*",
    "ec2:*",
    "ecr:*",
    "ecs:*",
    "events:*",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:DeleteRolePolicy",
    "iam:DetachRolePolicy",
    "iam:GetRole",
    "iam:GetRolePolicy",
    "iam:ListAttachedRolePolicies",
    "iam:ListRolePolicies",
    "iam:PassRole",
    "iam:PutRolePolicy",
    "iam:TagRole",
    "iam:UntagRole",
    "iam:UpdateAssumeRolePolicy",
    "lambda:*",
    "logs:*",
    "s3:*",
    "secretsmanager:GetSecretValue",
    "sns:*",
    "ssm:GetParameter",
    "ssm:GetParameters",
    "wafv2:*"
  ]
}

variable "github_actions_allowed_resource_arns" {
  type    = list(string)
  default = ["*"]
}

variable "ecs_task_execution_role_name" {
  type = string
}

variable "lambda_execution_role_name" {
  type = string
}

variable "lambda_execution_managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "lambda_runtime_dynamodb_table_arns" {
  type    = list(string)
  default = ["*"]
}

variable "lambda_runtime_sns_topic_arns" {
  type    = list(string)
  default = ["*"]
}

variable "lambda_runtime_ecs_cluster_arns" {
  type    = list(string)
  default = ["*"]
}

variable "lambda_runtime_task_definition_arns" {
  type    = list(string)
  default = ["*"]
}

variable "lambda_runtime_passrole_arns" {
  type    = list(string)
  default = ["*"]
}

variable "ecs_runtime_sns_topic_arns" {
  type    = list(string)
  default = ["*"]
}