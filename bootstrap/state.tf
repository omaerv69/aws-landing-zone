# Bucket holding every Terraform state of the landing zone, one key per stack.
# Locking uses the native S3 lock file (use_lockfile), so no DynamoDB table.
resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Server access logging needs a second bucket. API activity on this bucket is already recorded by CloudTrail.
  #checkov:skip=CKV_AWS_144:Single-region lab. Versioning already protects against accidental deletion or corruption.
  #checkov:skip=CKV_AWS_145:SSE-S3 is enough for states that hold no secrets and avoids a paid KMS key (ADR 0002).
  #checkov:skip=CKV2_AWS_62:Event notifications have no use for a state bucket.
  bucket = local.state_bucket_name

  # Every other state lives here: Terraform must never delete this bucket.
  lifecycle {
    prevent_destroy = true
  }
}

# ACLs disabled: access is controlled by IAM and the bucket policy only.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Each apply writes a new version: a broken state can always be rolled back.
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

# Old state versions are kept 90 days, long enough to recover from a mistake
# without paying for an ever-growing history.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# Refuse any request that does not use TLS.
data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
