data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ecr_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed ECR encryption.
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

resource "aws_kms_key" "ecr" {
  description             = "CMK for ECR repositories"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ecr_kms.json
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name = each.value
  }
}