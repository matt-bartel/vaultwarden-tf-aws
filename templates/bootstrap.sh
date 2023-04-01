#!/bin/bash

set -e
cd /home/ubuntu

# install docker
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
chmod a+r /etc/apt/keyrings/docker.gpg
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# install aws cli
apt-get install -y unzip jq
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# set up docker-compose.yml
mkdir compose letsencrypt bitwarden diun
chown ubuntu:ubuntu compose letsencrypt bitwarden diun
aws secretsmanager get-secret-value --secret-id "${bitwarden_config_secret_arn}" | jq -r '.SecretString' > compose/.env
aws s3 cp s3://${resources_bucket}/${bitwarden_compose_key} compose/docker-compose.yml

# restore a backup if it exists
if [ -n "$(aws s3 ls ${bucket}/bitwarden-backup.tar.xz)" ]
then
  echo "bitwarden backup found, restoring"
  aws s3 cp s3://${bucket}/bitwarden-backup.tar.xz bitwarden-backup.tar.xz
  tar --xz -xf bitwarden-backup.tar.xz
  rm bitwarden-backup.tar.xz
fi

# start bitwarden
echo "starting bitwarden in 2 minutes"
cd /home/ubuntu/compose
sleep 120 # wait 2 minutes for other resources to come up
docker compose up -d
cd ..

# backups
aws s3 cp s3://${resources_bucket}/${backup_script_key} backup.sh
chmod +x /home/ubuntu/backup.sh
cat >> /etc/cron.d/bitwarden-backup << 'EOF'
${backup_schedule} root /home/ubuntu/backup.sh
EOF

# logrotate
aws s3 cp s3://${resources_bucket}/${logrotate_key} /etc/logrotate.d/bitwarden

# fail2ban
apt-get install fail2ban -y
aws s3 cp s3://${resources_bucket}/${fail2ban_filter_key} /etc/fail2ban/filter.d/bitwarden.local
aws s3 cp s3://${resources_bucket}/${fail2ban_jail_key} /etc/fail2ban/jail.d/bitwarden.local
aws s3 cp s3://${resources_bucket}/${admin_fail2ban_filter_key} /etc/fail2ban/filter.d/bitwarden-admin.local
aws s3 cp s3://${resources_bucket}/${admin_fail2ban_jail_key} /etc/fail2ban/jail.d/bitwarden-admin.local
systemctl reload fail2ban

