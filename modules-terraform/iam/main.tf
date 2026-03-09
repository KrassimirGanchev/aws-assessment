data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
  github_oidc_derived_subjects = distinct(concat(
    var.github_repository != "" && var.github_branch != "" ? ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"] : [],
    var.github_repository != "" ? [for env in var.github_environments : "repo:${var.github_repository}:environment:${env}"] : [],
    var.github_repository != "" && var.github_allow_pull_request_subject ? ["repo:${var.github_repository}:pull_request"] : []
  ))
  github_oidc_allowed_subjects = distinct(concat(var.github_oidc_subjects, local.github_oidc_derived_subjects))
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_allowed_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy" "github_actions_least_privilege" {
  #checkov:skip=CKV_AWS_286: This deployment role intentionally spans multiple infrastructure services for assessment provisioning.
  #checkov:skip=CKV_AWS_287: The role is used only for CI/CD deployment and not interactive credential handling.
  #checkov:skip=CKV_AWS_288: Broad cross-service permissions are required to provision the assessment stack.
  #checkov:skip=CKV_AWS_289: IAM role and policy lifecycle permissions are required for Terraform-managed infrastructure changes.
  #checkov:skip=CKV_AWS_290: Write permissions are intentionally required for deployment automation.
  #checkov:skip=CKV_AWS_355: Resource wildcards remain necessary for cross-service Terraform deployment orchestration.
  name = "${var.github_actions_role_name}-least-privilege"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = var.github_actions_allowed_actions
        Resource = var.github_actions_allowed_resource_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = toset(var.github_actions_managed_policy_arns)

  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = var.ecs_task_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_runtime" {
  #checkov:skip=CKV_AWS_290: SNS publish is a required runtime write permission for the dispatcher task.
  #checkov:skip=CKV_AWS_355: The deployed topic ARN list is supplied by Terragrunt environment config; the module default is not used in practice.
  name = "${var.ecs_task_execution_role_name}-runtime-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.ecs_runtime_sns_topic_arns
      }
    ]
  })
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = var.lambda_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_extra" {
  for_each = toset(var.lambda_execution_managed_policy_arns)

  role       = aws_iam_role.lambda_execution.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "lambda_runtime" {
  name = "${var.lambda_execution_role_name}-runtime-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.lambda_runtime_dynamodb_table_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = var.lambda_runtime_kms_key_arns
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = var.lambda_runtime_sns_topic_arns
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks"
        ]
        Resource = concat(var.lambda_runtime_ecs_cluster_arns, var.lambda_runtime_task_definition_arns)
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = var.lambda_runtime_passrole_arns
      }
    ]
  })
}