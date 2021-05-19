resource "random_pet" "s3_name" {
  length    = 3
  prefix    = "bitwarden-backups"
  separator = "-"
}

resource "random_pet" "s3_resources_name" {
  length    = 3
  prefix    = "bitwarden-resources"
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

resource "aws_s3_bucket" "resources" {
  bucket = random_pet.s3_resources_name.id
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = false
  }

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-resources-bucket"
    },
  )
}

resource "aws_s3_bucket_object" "compose" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "bitwarden-docker-compose.yml"
  source                 = "templates/docker-compose.yml"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "backup" {
  bucket = aws_s3_bucket.resources.id
  key    = "bitwarden-backup-script"
  content = templatefile("templates/backup.sh", {
    bucket = aws_s3_bucket.bucket.id
  })
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "logrotate" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "bitwarden-logrotate"
  source                 = "templates/bitwarden-logrotate"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "fail2ban_filter" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "fail2ban/filter"
  source                 = "templates/bitwarden-fail2ban-filter"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "admin_fail2ban_filter" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "fail2ban/admin-filter"
  source                 = "templates/bitwarden-admin-fail2ban-filter"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "fail2ban_jail" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "fail2ban/jail"
  source                 = "templates/bitwarden-fail2ban-jail"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "admin_fail2ban_jail" {
  bucket                 = aws_s3_bucket.resources.id
  key                    = "fail2ban/admin-jail"
  source                 = "templates/bitwarden-admin-fail2ban-jail"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "resources" {
  bucket                  = aws_s3_bucket.resources.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3policy" {
  statement {
    sid       = "AllowBitwardenInstanceProfile"
    effect    = "Allow"
    resources = [aws_s3_bucket.bucket.arn]
    actions   = ["s3:ListBucket"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role.arn]
    }
  }

  statement {
    sid       = "AllowBitwardenInstanceProfileContents"
    effect    = "Allow"
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObjectAcl"
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.role.arn]
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
