resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-vpc"
    },
  )
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-public-subnet"
    },
  )
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-igw"
    },
  )
}

resource "aws_default_route_table" "r" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-igw"
    },
  )
}

resource "aws_security_group" "public" {
  vpc_id = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-security-group"
    },
  )
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "route_table_association" {
  route_table_id  = aws_default_route_table.r.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_eip" "ip" {
  instance = aws_instance.instance.id
  vpc      = true
  tags = merge(
    var.shared_tags,
    {
      Name = "bitwarden-eip"
    },
  )
}

resource "aws_route53_record" "bw" {
  zone_id = var.hosted_zone_id
  name    = var.domain
  type    = "A"
  ttl     = "300"
  records = [aws_eip.ip.public_ip]
}
