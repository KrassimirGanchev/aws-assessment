data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "dynamodb_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed DynamoDB encryption.
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

resource "aws_kms_key" "dynamodb" {
  description             = "CMK for DynamoDB table ${var.table_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.dynamodb_kms.json
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  tags = {
    Name = var.table_name
  }
}