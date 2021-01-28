variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "172.16.28.0/24"
}

variable "ssh_cidr" {
  type = string
  default = "0.0.0.0/0"
}

variable "shared_tags" {
  type = map(string)
  default = {
    created_by = "terraform"
    env        = "bitwarden_rs"
  }
}

variable "backup_schedule" {
  type    = string
  default = "0 9 * * *"
}

variable "bitwarden_signups_allowed" {
  type = bool
}

variable "bitwarden_smtp_host" {
  type = string
}

variable "bitwarden_smtp_port" {
  type    = string
  default = "587"
}

variable "bitwarden_smtp_ssl" {
  type    = bool
  default = true
}

variable "bitwarden_smtp_username" {
  type = string
}

variable "bitwarden_smtp_password" {
  type      = string
  sensitive = true
}

variable "hosted_zone_id" {
  type      = string
  sensitive = true
}

variable "domain" {
  type = string
}

variable "bucket_version_expiration_days" {
  type    = number
  default = 30
}

variable "bitwarden_acme_email" {
  type = string
}

variable "iam_user_name" {
  type        = string
  description = "A user that will be created for the ec2 instance to access the s3 bucket"
  default     = "bitwarden"
}

variable "ec2_key_pair_name" {
  type        = string
  description = "Name of an existing ec2 key pair"
}

variable "ec2_instance_type" {
  type    = string
  default = "t4g.micro"
}
