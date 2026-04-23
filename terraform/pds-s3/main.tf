terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Bucket + hardening.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "pds" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = merge(
    var.tags,
    {
      Name      = var.bucket_name
      ManagedBy = "pds-cli"
    },
  )
}

resource "aws_s3_bucket_public_access_block" "pds" {
  bucket                  = aws_s3_bucket.pds.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pds" {
  bucket = aws_s3_bucket.pds.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "pds" {
  bucket = aws_s3_bucket.pds.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle: 30 days Standard, then Deep Archive forever.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "pds" {
  bucket = aws_s3_bucket.pds.id

  rule {
    id     = "hot-to-cold"
    status = "Enabled"

    filter {}

    transition {
      days          = var.standard_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = var.standard_days
      storage_class   = "DEEP_ARCHIVE"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# Least-privilege IAM user for `pds archive` uploads.
# -----------------------------------------------------------------------------

resource "aws_iam_user" "pds_archiver" {
  name = "${var.bucket_name}-archiver"
  path = "/pds/"
  tags = var.tags
}

data "aws_iam_policy_document" "archiver" {
  statement {
    sid     = "WriteArchives"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.pds.arn}/*",
    ]
  }
  statement {
    sid     = "ListForIdempotency"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.pds.arn,
    ]
  }
}

resource "aws_iam_user_policy" "archiver" {
  name   = "write-only"
  user   = aws_iam_user.pds_archiver.name
  policy = data.aws_iam_policy_document.archiver.json
}

resource "aws_iam_access_key" "archiver" {
  user = aws_iam_user.pds_archiver.name
}
