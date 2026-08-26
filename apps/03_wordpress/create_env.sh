#!/usr/bin/env bash
set -e

ENV_FILE=".env"
PROJECT="wordpress"
HOST=$(cat /proc/sys/kernel/hostname)

# Backup existing .env
if [ -f "$ENV_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mv "$ENV_FILE" "$ENV_FILE.backup_$TIMESTAMP"
fi

# Structured defaults
WORDPRESS_DB_NAME="${PROJECT}_${HOST}_db"
WORDPRESS_DB_USER="${PROJECT}_db_user"

MYSQL_RANDOM_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')
RANDOM_SUFFIX=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')  # secure random
WORDPRESS_DB_PASSWORD="${PROJECT}_${HOST}_db_${RANDOM_SUFFIX}"

# Write to .env
cat > "$ENV_FILE" <<EOL
WORDPRESS_DB_NAME=$WORDPRESS_DB_NAME
WORDPRESS_DB_USER=$WORDPRESS_DB_USER
WORDPRESS_DB_PASSWORD=$WORDPRESS_DB_PASSWORD
MYSQL_RANDOM_ROOT_PASSWORD=$MYSQL_RANDOM_ROOT_PASSWORD
EOL

echo ".env generated with structured, secure defaults."