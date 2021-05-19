resource "aws_iam_instance_profile" "profile" {
  name_prefix = "bitwarden"
  role        = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name_prefix        = "bitwarden"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "rolepolicy" {
  name_prefix = "bitwarden"
  role        = aws_iam_role.role.id
  policy      = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.bucket.arn}"
      },
      {
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.bucket.arn}/*"
      },
      {
        "Action": [
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.resources.arn}"
      },
      {
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.resources.arn}/*"
      },
      {
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsemanager:DescribeSecret"
        ],
        "Effect": "Allow",
        "Resource": "${aws_secretsmanager_secret.config.arn}"
      }
    ]
  }
  EOF
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
