resource "aws_iam_instance_profile" "profile" {
  name_prefix = "bitwarden"
  role        = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name               = "bwtest_role"
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
  name   = "bwtest_role_policy"
  role   = aws_iam_role.role.id
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${random_pet.s3_name.id}"
      },
      {
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${random_pet.s3_name.id}/*"
      },
      {
        "Action": [
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${random_pet.s3_resources_name.id}"
      },
      {
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${random_pet.s3_resources_name.id}/*"
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
