data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_kms" {
  #checkov:skip=CKV_AWS_109: Root-admin KMS key policy is required for customer-managed S3 encryption.
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

resource "aws_kms_key" "s3" {
  description             = "CMK for S3 bucket ${var.bucket_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.s3_kms.json
}

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_18: This assessment bucket is an internal artifact/state bucket and separate access-log bucket management is intentionally out of scope.
  #checkov:skip=CKV_AWS_144: Cross-region replication is intentionally not enabled for this single-account assessment environment.
  #checkov:skip=CKV2_AWS_62: Event notifications are not required for this artifact/state bucket.
  bucket        = var.bucket_name
  force_destroy = true
  tags          = { Name = var.bucket_name }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "default-lifecycle"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}