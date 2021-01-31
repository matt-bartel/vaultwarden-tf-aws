# latest ubuntu 20.04 arm64 image
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
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
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_pair_name

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
    region            = var.region
    aws_key_id        = aws_iam_access_key.user.id
    aws_secret_key    = aws_iam_access_key.user.secret
    acme_email        = var.bitwarden_acme_email
    signups_allowed   = var.bitwarden_signups_allowed
    domain            = var.domain
    smtp_host         = var.bitwarden_smtp_host
    smtp_port         = var.bitwarden_smtp_port
    smtp_ssl          = var.bitwarden_smtp_ssl
    smtp_username     = var.bitwarden_smtp_username
    smtp_password     = var.bitwarden_smtp_password
    admin_token       = random_password.admin_token.result
    enable_admin_page = var.bitwarden_enable_admin_page
    backup_schedule   = var.backup_schedule
    bucket            = aws_s3_bucket.bucket.id
  })

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-instance"
    },
  )

  depends_on = [aws_s3_bucket.bucket]
}
