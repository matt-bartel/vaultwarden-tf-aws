#!/bin/bash

set -e
cd /home/ubuntu

# install docker
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=arm64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose

# install aws cli
sudo apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# set up docker-compose.yml
mkdir compose letsencrypt bitwarden
chown ubuntu:ubuntu bitwarden
cat >> compose/docker-compose.yml << 'EOF'
version: '3.3'

services:
  traefik:
    image: "traefik:v2.4"
    container_name: "traefik"
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.docker.exposedbydefault=false"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${acme_email}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      #- "--log.level=DEBUG"
      #- "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/home/ubuntu/letsencrypt:/letsencrypt"
      - "/var/run/docker.sock:/var/run/docker.sock"
    restart: unless-stopped
  bitwarden:
    image: "bitwardenrs/server"
    container_name: "bitwarden"
    user: 1000:1000
    volumes:
      - "/home/ubuntu/bitwarden:/data"
    environment:
      ROCKET_PORT: "8080"
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "${signups_allowed}"
      %{ if enable_admin_page }ADMIN_TOKEN: "${admin_token}"%{ endif }
      DOMAIN: "https://${domain}"
      LOG_FILE: "/data/bitwarden.log"
      SMTP_HOST: "${smtp_host}"
      SMTP_PORT: "${smtp_port}"
      SMTP_SSL: "${smtp_ssl}"
      SMTP_FROM: "bitwarden@${domain}"
      SMTP_USERNAME: "${smtp_username}"
      SMTP_PASSWORD: "${smtp_password}"
    labels:
      - "traefik.enable=true"
      - "traefik.http.middlewares.redirect-https.redirectScheme.scheme=https"
      - "traefik.http.middlewares.redirect-https.redirectScheme.permanent=true"
      - "traefik.http.routers.bitwarden-ui-https.rule=Host(`${domain}`)"
      - "traefik.http.routers.bitwarden-ui-https.entrypoints=websecure"
      - "traefik.http.routers.bitwarden-ui-https.tls.certresolver=myresolver"
      - "traefik.http.routers.bitwarden-ui-https.tls=true"
      - "traefik.http.routers.bitwarden-ui-https.service=bitwarden-ui"
      - "traefik.http.routers.bitwarden-ui-http.rule=Host(`${domain}`)"
      - "traefik.http.routers.bitwarden-ui-http.entrypoints=web"
      - "traefik.http.routers.bitwarden-ui-http.middlewares=redirect-https"
      - "traefik.http.routers.bitwarden-ui-http.service=bitwarden-ui"
      - "traefik.http.services.bitwarden-ui.loadbalancer.server.port=8080"
      - "traefik.http.routers.bitwarden-websocket-https.rule=Host(`${domain}`) && Path(`/notifications/hub`)"
      - "traefik.http.routers.bitwarden-websocket-https.entrypoints=websecure"
      - "traefik.http.routers.bitwarden-websocket-https.tls=true"
      - "traefik.http.routers.bitwarden-websocket-https.service=bitwarden-websocket"
      - "traefik.http.routers.bitwarden-websocket-http.rule=Host(`${domain}`) && Path(`/notifications/hub`)"
      - "traefik.http.routers.bitwarden-websocket-http.entrypoints=web"
      - "traefik.http.routers.bitwarden-websocket-http.middlewares=redirect-https"
      - "traefik.http.routers.bitwarden-websocket-http.service=bitwarden-websocket"
      - "traefik.http.services.bitwarden-websocket.loadbalancer.server.port=3012"
    depends_on:
      - traefik
    restart: unless-stopped

EOF

# restore a backup if it exists
export AWS_ACCESS_KEY_ID="${aws_key_id}"
export AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
export AWS_DEFAULT_REGION="${region}"
if [ -n "$(aws s3 ls ${bucket}/bitwarden-backup.tar.xz)" ]
then
  echo "bitwarden backup found, restoring"
  aws s3 cp s3://${bucket}/bitwarden-backup.tar.xz bitwarden-backup.tar.xz
  tar --xz -xf bitwarden-backup.tar.xz
  rm bitwarden-backup.tar.xz
fi

# start bitwarden
echo "starting bitwarden in 5 minutes"
cd /home/ubuntu/compose
sleep 300 # wait 5 minutes for other resources to come up
sudo docker-compose up -d
cd ..

# backups
cat >> /home/ubuntu/backup.sh << 'EOF'
#!/bin/bash

set -e
export AWS_ACCESS_KEY_ID="${aws_key_id}"
export AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
export AWS_DEFAULT_REGION="${region}"

cd /home/ubuntu/compose
docker-compose down
cd ..
tar --xz -cf bitwarden-backup.tar.xz bitwarden letsencrypt
/usr/local/bin/aws s3 cp bitwarden-backup.tar.xz s3://${bucket}/bitwarden-backup.tar.xz --sse
rm bitwarden-backup.tar.xz
cd compose
docker-compose pull
docker-compose up -d
EOF
chmod +x /home/ubuntu/backup.sh
sudo cat >> /etc/cron.d/bitwarden-backup << 'EOF'
${backup_schedule} root /home/ubuntu/backup.sh
EOF

# logrotate
sudo cat >> /etc/logrotate.d/bitwarden << 'EOF'
/home/ubuntu/bitwarden/*.log {
  daily
  size 5M
  compress
  rotate 5
  copytruncate
  missingok
  notifempty
}
EOF

# fail2ban
sudo apt-get install fail2ban -y
sudo cat >> "/etc/fail2ban/filter.d/bitwarden.local" << 'EOF'
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <ADDR>\. Username:.*$
ignoreregex =
EOF
sudo cat >> "/etc/fail2ban/jail.d/bitwarden.local" << 'EOF'
[bitwarden]
enabled = true
port = 80,443
filter = bitwarden
action = iptables-allports[chain=FORWARD]
logpath = /home/ubuntu/bitwarden/bitwarden.log
maxretry = 5
bantime = 14400
findtime = 14400
EOF
sudo cat >> "/etc/fail2ban/filter.d/bitwarden-admin.local" << 'EOF'
[INCLUDES]
before = common.conf

[Definition]
failregex = ^.*Invalid admin token\. IP: <ADDR>.*$
ignoreregex =
EOF
sudo cat >> "/etc/fail2ban/jail.d/bitwarden-admin.local" << 'EOF'
[bitwarden-admin]
enabled = true
port = 80,443
filter = bitwarden-admin
action = iptables-allports[chain=FORWARD]
logpath = /home/ubuntu/bitwarden/bitwarden.log
maxretry = 3
bantime = 14400
findtime = 14400
EOF
sudo systemctl reload fail2ban

