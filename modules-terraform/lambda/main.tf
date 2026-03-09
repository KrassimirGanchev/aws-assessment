data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  lambda_log_group_name = "/aws/lambda/${var.function_name}"
  lambda_log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.lambda_log_group_name}"
}

data "aws_iam_policy_document" "lambda_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed Lambda encryption.
  #checkov:skip=CKV_AWS_111: Root-admin KMS key policy is intentionally broad for bootstrap ownership of the CMK.
  #checkov:skip=CKV_AWS_356: AWS KMS root administration requires the standard wildcard resource policy shape.
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsUseOfKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [local.lambda_log_group_arn]
    }
  }
}

resource "aws_kms_key" "lambda" {
  description             = "CMK for Lambda ${var.function_name} logs and environment variables"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.lambda_kms.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.lambda_log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.lambda.arn
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_117: These assessment Lambdas are intentionally not placed in a VPC to keep the API path simple and public.
  #checkov:skip=CKV_AWS_116: DLQ is not configured because the functions are synchronous handlers without async event sources.
  #checkov:skip=CKV_AWS_272: Code signing is intentionally omitted for this assessment packaging flow.
  function_name                  = var.function_name
  role                           = var.role_arn
  runtime                        = var.runtime
  handler                        = var.handler
  filename                       = var.source_package
  source_code_hash               = filebase64sha256(var.source_package)
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  kms_key_arn                    = aws_kms_key.lambda.arn
  reserved_concurrent_executions = var.reserved_concurrent_executions

  tracing_config {
    mode = "Active"
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}