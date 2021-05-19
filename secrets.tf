resource "aws_secretsmanager_secret" "config" {
  name_prefix = "bitwarden"
  description = "bitwarden configuration"
}

resource "aws_secretsmanager_secret_version" "config_value" {
  secret_id = aws_secretsmanager_secret.config.id

  secret_string = templatefile("templates/env", {
    acme_email           = var.bitwarden_acme_email
    signups_allowed      = var.bitwarden_signups_allowed
    domain               = var.domain
    smtp_host            = var.bitwarden_smtp_host
    smtp_port            = var.bitwarden_smtp_port
    smtp_ssl             = var.bitwarden_smtp_ssl
    smtp_username        = var.bitwarden_smtp_username
    smtp_password        = var.bitwarden_smtp_password
    enable_admin_page    = var.bitwarden_enable_admin_page
    admin_token          = random_password.admin_token.result
    backup_schedule      = var.backup_schedule
    bucket               = aws_s3_bucket.bucket.id
    diun_notify_email    = var.diun_notify_email
    diun_watch_schedule  = var.diun_watch_schedule
    diun_gotify_endpoint = var.diun_gotify_endpoint
    diun_gotify_token    = var.diun_gotify_token
    diun_gotify_priority = var.diun_gotify_priority
    diun_gotify_timeout  = var.diun_gotify_timeout
  })
}
