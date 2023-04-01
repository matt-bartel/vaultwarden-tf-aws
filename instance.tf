# latest ubuntu 20.04 arm64 image
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "random_password" "admin_token" {
  length           = 48
  special          = true
  override_special = "+/_"
}

resource "aws_network_interface" "net" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.public.id]

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-network-interface"
    },
  )
}

resource "aws_instance" "instance" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.ec2_instance_type
  key_name             = var.ec2_key_pair_name
  iam_instance_profile = aws_iam_instance_profile.profile.id

  network_interface {
    network_interface_id = aws_network_interface.net.id
    device_index         = 0
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.ec2_volume_size
    iops        = 3000
    throughput  = 125
  }

  user_data = templatefile("templates/bootstrap.sh", {
    backup_schedule             = var.backup_schedule
    bucket                      = aws_s3_bucket.bucket.id
    resources_bucket            = aws_s3_bucket.resources.id
    bitwarden_config_secret_arn = aws_secretsmanager_secret.config.arn
    bitwarden_compose_key       = aws_s3_bucket_object.compose.key
    backup_script_key           = aws_s3_bucket_object.backup.key
    logrotate_key               = aws_s3_bucket_object.logrotate.key
    fail2ban_filter_key         = aws_s3_bucket_object.fail2ban_filter.key
    fail2ban_jail_key           = aws_s3_bucket_object.fail2ban_jail.key
    admin_fail2ban_filter_key   = aws_s3_bucket_object.admin_fail2ban_filter.key
    admin_fail2ban_jail_key     = aws_s3_bucket_object.admin_fail2ban_jail.key
  })

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-instance"
    },
  )

  depends_on = [
    aws_s3_bucket.bucket,
    aws_secretsmanager_secret_version.config_value
  ]
}
