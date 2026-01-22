#!/usr/bin/env bash

set -euo pipefail

# ---- config ----
DESCRIPTION="ssh-gen-request"
KEY_DIR="$HOME/.ssh"

# automatically generate name from hostname
HOSTNAME=$(hostname)
KEY_NAME="${HOSTNAME}" 
KEY_PATH="$KEY_DIR/id_${KEY_NAME}"
API_URL="https://ssh-request.leanderziehm.com/register"

# ---- ensure ssh dir exists ----
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# ---- generate key ----
if [[ -f "$KEY_PATH" ]]; then
  echo "Key already exists: $KEY_PATH"
  exit 1
fi

ssh-keygen \
  -t ed25519 \
  -f "$KEY_PATH" \
  -N "" \
  -C "$KEY_NAME"

# ---- read public key ----
PUBLIC_KEY=$(cat "${KEY_PATH}.pub")

# ---- send to API ----
curl -X POST "$API_URL" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg name "$KEY_NAME" \
    --arg description "$DESCRIPTION" \
    --arg public_key "$PUBLIC_KEY" \
    '{
      name: $name,
      description: $description,
      public_key: $public_key
    }'
  )"

echo "✅ SSH key generated and uploaded successfully"
echo "Private key path: $KEY_PATH"
