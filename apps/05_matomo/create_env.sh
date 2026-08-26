#!/usr/bin/env bash
set -e

ENV_FILE=".env"
PROJECT="postgres"
HOST=$(cat /proc/sys/kernel/hostname)

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mv "$ENV_FILE" "$ENV_FILE.backup_$TIMESTAMP"
fi

# Structured defaults
POSTGRES_DB="${PROJECT}_${HOST}_db"
RANDOM_SUFFIX=$(openssl rand -base64 8 | tr -dc 'a-z0-9')
RANDOM_SUFFIX2=$(openssl rand -base64 8 | tr -dc 'a-z0-9')
POSTGRES_USER="${PROJECT}_user_${RANDOM_SUFFIX}${RANDOM_SUFFIX2}"
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=')
POSTGRES_VOLUME="${PROJECT}_data_${RANDOM_SUFFIX}"
POSTGRES_PORT=5432

# Write to .env
cat > "$ENV_FILE" <<EOL
POSTGRES_DB=$POSTGRES_DB
POSTGRES_PORT=$POSTGRES_PORT
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_VOLUME=$POSTGRES_VOLUME
EOL

echo ".env generated with secure, randomized credentials."