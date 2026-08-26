#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./github-repo-ssh git@github.com:OWNER/REPO.git
#   ./github-repo-ssh https://github.com/OWNER/REPO.git

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <github-repo-url>"
    echo
    echo "Example:"
    echo "  $0 git@github.com:gitusername/reponame.git"
    exit 1
fi

REPO_URL="$1"
SSH_DIR="$HOME/.ssh/gitkeys"

# ------------------------------------------------------------
# Parse GitHub owner/repo
# ------------------------------------------------------------

if [[ "$REPO_URL" =~ ^git@github\.com:([^/]+)/([^/]+?)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
elif [[ "$REPO_URL" =~ ^https://github\.com/([^/]+)/([^/]+?)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "Error: unsupported GitHub URL:"
    echo "  $REPO_URL"
    echo
    echo "Expected:"
    echo "  git@github.com:OWNER/REPO.git"
    echo "  https://github.com/OWNER/REPO.git"
    exit 1
fi

# Remove possible .git suffix
REPO="${REPO%.git}"

KEY_DIR="$SSH_DIR/$OWNER/$REPO"
KEY_FILE="$KEY_DIR/id_ed25519"
PUB_FILE="$KEY_FILE.pub"
HOST_ALIAS="github-${OWNER}-${REPO}"

# Clone destination
CLONE_DIR="$PWD/$REPO"

echo
echo "GitHub repository:"
echo "  $OWNER/$REPO"
echo
echo "SSH key:"
echo "  $KEY_FILE"
echo
echo "SSH host alias:"
echo "  $HOST_ALIAS"
echo

# ------------------------------------------------------------
# Create key
# ------------------------------------------------------------

mkdir -p "$KEY_DIR"
chmod 700 "$SSH_DIR" "$SSH_DIR/$OWNER" "$KEY_DIR"

if [[ -e "$KEY_FILE" ]]; then
    echo "SSH key already exists:"
    echo "  $KEY_FILE"
    echo
    read -r -p "Use existing key? [Y/n] " ANSWER
    ANSWER="${ANSWER:-Y}"

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    echo "Generating new SSH key..."
    ssh-keygen \
        -t ed25519 \
        -f "$KEY_FILE" \
        -C "github-$OWNER-$REPO" \
        -N ""

    chmod 600 "$KEY_FILE"
    chmod 644 "$PUB_FILE"

    echo "✓ SSH key generated."
fi

# ------------------------------------------------------------
# Configure ~/.ssh/config
# ------------------------------------------------------------

touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# Remove an old block for this exact alias, if one exists.
TMP_CONFIG="$(mktemp)"

awk -v alias="$HOST_ALIAS" '
    BEGIN { skip=0 }

    /^Host / {
        if ($2 == alias) {
            skip=1
            next
        }

        if (skip) {
            skip=0
        }
    }

    !skip { print }
' "$HOME/.ssh/config" > "$TMP_CONFIG"

mv "$TMP_CONFIG" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

cat >> "$HOME/.ssh/config" <<EOF

# GitHub repository: $OWNER/$REPO
Host $HOST_ALIAS
    HostName github.com
    User git
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
EOF

echo "✓ SSH config updated."

# ------------------------------------------------------------
# Show public key
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ADD THIS DEPLOY KEY TO GITHUB"
echo "============================================================"
echo
echo "Repository:"
echo "  https://github.com/$OWNER/$REPO/settings/keys"
echo
echo "IMPORTANT: enable:"
echo
echo "  ☑ Allow write access"
echo
echo "Public key:"
echo
cat "$PUB_FILE"
echo
echo "============================================================"
echo

read -r -p "Press ENTER after you added the key to GitHub..."

# ------------------------------------------------------------
# Test SSH authentication
# ------------------------------------------------------------

echo
echo "Testing SSH authentication..."

if ssh \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    "$HOST_ALIAS" 2>&1 | grep -q "successfully authenticated"; then

    echo "✓ GitHub SSH authentication succeeded."
else
    echo
    echo "SSH authentication failed."
    echo
    echo "Debug output:"
    ssh \
        -o StrictHostKeyChecking=accept-new \
        -T "$HOST_ALIAS" || true

    echo
    echo "Make sure:"
    echo "  1. The deploy key was added to the correct repository."
    echo "  2. 'Allow write access' was enabled."
    echo "  3. You copied the entire public key."
    exit 1
fi

# ------------------------------------------------------------
# Clone
# ------------------------------------------------------------

if [[ -e "$CLONE_DIR" ]]; then
    echo
    echo "Directory already exists:"
    echo "  $CLONE_DIR"
    echo
    echo "Skipping clone."
else
    echo
    echo "Cloning repository..."

    GIT_SSH_COMMAND="ssh -o Host=$HOST_ALIAS" \
        git clone \
        "git@$HOST_ALIAS:$OWNER/$REPO.git" \
        "$CLONE_DIR"

    echo "✓ Repository cloned."
fi

# ------------------------------------------------------------
# Configure repo-local Git SSH command
# ------------------------------------------------------------

cd "$CLONE_DIR"

git config --local core.sshCommand "ssh -o Host=$HOST_ALIAS"

echo "✓ Repository-specific SSH configured."

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "============================================================"
echo " DONE"
echo "============================================================"
echo
echo "Repository:"
echo "  $CLONE_DIR"
echo
echo "SSH key:"
echo "  $KEY_FILE"
echo
echo "Git SSH command:"
git config --local --get core.sshCommand
echo
echo "Remote:"
git remote -v
echo
echo "From this repository (and any subdirectory):"
echo
echo "  git pull"
echo "  git push"
echo
echo "will use:"
echo "  $KEY_FILE"
echo
