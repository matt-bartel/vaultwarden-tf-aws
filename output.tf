output "instance_public_ip" {
  value = aws_eip.ip.public_ip
}

output "backup_bucket" {
  value = aws_s3_bucket.bucket.id
}

output "domain" {
  value = "https://${aws_route53_record.bw.name}"
}

