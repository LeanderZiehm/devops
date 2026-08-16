#!/bin/bash

# CLI to set up a new web app

# Ask for full domain
read -p "Enter your full domain (e.g., example.website.com): " DOMAIN

# Then ask for port
read -p "Enter the port your app will run on (e.g., 5014): " APP_PORT

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

# Extract subdomain
SUBDOMAIN=$(echo "$DOMAIN" | cut -d'.' -f1)
AUTH_USER="user_$SUBDOMAIN"
AUTH_FILE="/etc/nginx/.htpasswd_$DOMAIN"

# Create Nginx config
echo "Creating Nginx config for $DOMAIN..."
sudo tee $NGINX_AVAILABLE > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;

        # Required for WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Optional: increase timeout for long-lived WebSocket connections
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

# Enable site
sudo ln -sf $NGINX_AVAILABLE $NGINX_ENABLED

# Test Nginx config
echo "Testing Nginx configuration..."
sudo nginx -t && sudo systemctl reload nginx

# Enable HTTPS via Certbot
echo "Enabling HTTPS with Certbot..."
sudo certbot --nginx -d $DOMAIN

# Ask about password protection
read -p "Do you want to password protect this site? (y/n): " PROTECT

if [[ "$PROTECT" =~ ^[Yy]$ ]]; then

    echo "Generating password protection..."

    # Generate password
    PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64)

    # Install apache utils if missing
    if ! command -v htpasswd &> /dev/null; then
        echo "Installing htpasswd utility..."
        sudo apt update
        sudo apt install -y apache2-utils
    fi

    # Create auth file
    echo "$PASSWORD" | sudo htpasswd -i -c "$AUTH_FILE" "$AUTH_USER"

    # Add auth config to nginx location
    sudo sed -i "/location \/ {/a\\
        auth_basic \"Restricted Area\";\\
        auth_basic_user_file $AUTH_FILE;" "$NGINX_AVAILABLE"

    # Reload nginx
    sudo nginx -t && sudo systemctl reload nginx

    echo ""
    echo "=================================="
    echo "Password protection enabled!"
    echo "Username: $AUTH_USER"
    echo "Password: $PASSWORD"
    echo "=================================="
    echo ""

else
    echo "No password protection enabled."
fi

echo "Setup complete! Your app is available at https://$DOMAIN"
