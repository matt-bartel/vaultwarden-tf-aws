# vaultwarden-tf-aws

> Terraform templates for deploying [vaultwarden](https://github.com/dani-garcia/vaultwarden) (formerly bitwarden_rs) to AWS

## Prerequisites

* Route53 hosted zone
* SMTP credentials
* EC2 key pair

## Features

* HTTPS using LetsEncrypt
* Backups to S3 (daily by default)
* [diun](https://github.com/crazy-max/diun) for image update notifications
* fail2ban and logrotate
