data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "secrets_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed Secrets Manager encryption.
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
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for secret ${var.secret_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.secrets_kms.json
}

resource "random_password" "cognito_temp_password" {
  length           = var.password_length
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "this" {
  #checkov:skip=CKV2_AWS_57: This secret stores a test-user temporary password for assessment validation and is intentionally rotated manually by workflow.
  name                    = var.secret_name
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = aws_kms_key.secrets.arn

  tags = {
    Name = var.secret_name
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = random_password.cognito_temp_password.result
}
