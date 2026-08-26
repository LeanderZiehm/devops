#!/usr/bin/env bash
set -e

ENV_FILE=".env"
PROJECT="umami"
HOST=$(cat /proc/sys/kernel/hostname)

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mv "$ENV_FILE" "$ENV_FILE.backup_$TIMESTAMP"
fi

APP_SECRET="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=')"

# Write to .env
cat > "$ENV_FILE" <<EOL
DATABASE_URL=postgresql://umami:umami@db:5432/umami
APP_SECRET=$APP_SECRET
EOL

echo ".env generated with secure secret. YOU NEED TO STILL ADD THE DATABASE_URL!!!"