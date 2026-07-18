data "aws_caller_identity" "current" {}

# Bucket names are globally unique across all of AWS, so the account ID
# (always unique to us, never changes) is used as the disambiguating suffix
# rather than a random one - makes the bucket name predictable/reproducible
# instead of something you'd need to look up.
locals {
  state_bucket_name = "calendar-terraform-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # This bucket holds the state for infra/environments/{dev,staging}/, both of
  # which get destroyed and recreated regularly on purpose - but the STATE
  # BUCKET ITSELF must never go with them, or a future `terraform apply` in
  # either environment would think it's creating everything from scratch
  # (real risk of duplicate/orphaned AWS resources). `terraform destroy` in
  # this directory refuses unless this is removed first, on purpose.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_tls_only" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}
