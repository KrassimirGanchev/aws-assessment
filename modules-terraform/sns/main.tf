data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "sns_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed SNS encryption.
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

resource "aws_kms_key" "sns" {
  description             = "CMK for SNS topic ${var.topic_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns_kms.json
}

resource "aws_sns_topic" "this" {
  name              = var.topic_name
  kms_master_key_id = aws_kms_key.sns.arn
  tags              = { Name = var.topic_name }
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscribers)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}