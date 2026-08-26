#!/usr/bin/env bash
set -e

ENV_FILE=".env"
PROJECT="grafana"
HOST=$(cat /proc/sys/kernel/hostname)

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mv "$ENV_FILE" "$ENV_FILE.backup_$TIMESTAMP"
fi

# Generate a secure, random admin username
RANDOM_USER_SUFFIX=$(openssl rand -base64 8 | tr -dc 'a-zA-Z0-9')
GF_SECURITY_ADMIN_USER="${PROJECT}_admin_${RANDOM_USER_SUFFIX}"

# Generate a secure, random password
RANDOM_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=')
GF_SECURITY_ADMIN_PASSWORD="$RANDOM_PASSWORD"

# Write to .env
cat > "$ENV_FILE" <<EOL
GF_SECURITY_ADMIN_USER=$GF_SECURITY_ADMIN_USER
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
EOL

echo ".env.grafana generated with secure admin credentials."