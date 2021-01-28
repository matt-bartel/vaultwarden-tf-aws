resource "random_pet" "s3_name" {
  length    = 3
  prefix    = "bitwarden-backups"
  separator = "-"
}

# data "aws_canonical_user_id" "current_user" {}

resource "aws_s3_bucket" "bucket" {
  bucket = random_pet.s3_name.id
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    noncurrent_version_expiration {
      days = var.bucket_version_expiration_days
    }
  }

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-bucket"
    },
  )

  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3policy" {
  statement {
    sid       = "AllowBitwardenIAMUser"
    effect    = "Allow"
    resources = [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"]
    actions   = ["s3:*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.user.arn]
    }
  }

  statement {
    sid       = "DenyNotBitwardenVPCE"
    effect    = "Deny"
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    actions   = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.s3.id]
    }
  }

  statement {
    sid       = "DenyIncorrectEncryptionHeader"
    effect    = "Deny"
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    actions   = ["s3:PutObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }
  }

  statement {
    sid       = "DenyUnencryptedObjectUploads"
    effect    = "Deny"
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    actions   = ["s3:PutObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["true"]
    }
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3policy.json
}
