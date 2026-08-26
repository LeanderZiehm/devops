#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/LeanderZiehm/docker-compose-templates/main/03_wordpress"

APP_DIR="${APP_DIR:-$HOME/wordpress-stack}"

echo "==> Creating install directory: $APP_DIR"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "==> Downloading compose + env scripts"

curl -fsSL "$REPO_RAW_BASE/docker-compose.yml" -o docker-compose.yml
curl -fsSL "$REPO_RAW_BASE/create_env.sh" -o create_env.sh

chmod +x create_env.sh

echo "==> Generating .env using create_env.sh"

if [ ! -f .env ]; then
  ./create_env.sh
else
  echo "==> .env already exists, skipping generation"
fi

echo "==> Detecting Compose runtime"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif podman compose version >/dev/null 2>&1; then
  COMPOSE_CMD="podman compose"
else
  echo "ERROR: Neither docker compose nor podman compose found."
  exit 1
fi

echo "==> Using: $COMPOSE_CMD"

echo "==> Starting WordPress stack"
$COMPOSE_CMD up -d

echo ""
echo "==============================="
echo " WordPress stack installed"
echo " Directory: $APP_DIR"
echo "==============================="
echo ""
echo "Stop:"
echo "  cd $APP_DIR && $COMPOSE_CMD down"
echo ""
echo "Logs:"
echo "  cd $APP_DIR && $COMPOSE_CMD logs -f"
