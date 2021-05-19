#!/bin/bash

set -e

cd /home/ubuntu/compose
docker-compose down
cd ..
tar --xz -cf bitwarden-backup.tar.xz bitwarden letsencrypt
/usr/local/bin/aws s3 cp bitwarden-backup.tar.xz s3://${bucket}/bitwarden-backup.tar.xz --sse
rm bitwarden-backup.tar.xz
cd compose
docker-compose up -d

