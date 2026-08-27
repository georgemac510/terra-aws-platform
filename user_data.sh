#!/bin/bash
# Runs as root on first boot only. Output goes to /var/log/cloud-init-output.log
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git

# Docker's official repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker ubuntu

# Pull the application source and start it
git clone ${repo_url} /opt/platform
cd /opt/platform

cat > .env <<'ENVEOF'
POSTGRES_DB=platform
POSTGRES_USER=platform
ENVEOF
echo "POSTGRES_PASSWORD=${db_password}" >> .env
echo "PROJECT_NAME=${project}" >> .env

chown -R ubuntu:ubuntu /opt/platform

docker compose up -d --build

echo "user_data finished at $(date -Is)" > /var/log/platform-ready
