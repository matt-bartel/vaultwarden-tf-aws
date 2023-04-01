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
  type    = string
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

variable "bitwarden_smtp_security" {
  type    = string
  default = "starttls"
}

variable "bitwarden_smtp_username" {
  type = string
}

variable "bitwarden_smtp_password" {
  type      = string
  sensitive = true
}

variable "bitwarden_enable_admin_page" {
  type = bool
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

variable "ec2_key_pair_name" {
  type        = string
  description = "Name of an existing ec2 key pair"
}

variable "ec2_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "ec2_volume_size" {
  type    = number
  default = 8
}

variable "diun_notify_email" {
  type        = string
  description = "Email for docker image update notifications"
}

variable "diun_watch_schedule" {
  type        = string
  default     = "0 */6 * * *"
  description = "Schedule for checking for new docker image versions"
}

variable "diun_gotify_endpoint" {
  type        = string
  default     = ""
  description = "gotify endpoint for docker image update notifications"
}

variable "diun_gotify_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "diun_gotify_priority" {
  type    = string
  default = "1"
}

variable "diun_gotify_timeout" {
  type    = string
  default = "10s"
}

