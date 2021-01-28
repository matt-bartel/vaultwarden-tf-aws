resource "aws_iam_user" "user" {
  name = var.iam_user_name
  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-user"
    },
  )
}

resource "aws_iam_access_key" "user" {
  user = aws_iam_user.user.name
}

resource "aws_iam_user_policy" "s3_rw" {
  user   = aws_iam_user.user.name
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": [
          "*"
          
        ]
      }
    ]
  }
  EOF
}
