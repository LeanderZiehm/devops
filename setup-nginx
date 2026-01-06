#!/bin/bash

# CLI to set up a new web app on leanderziehm.com or tandemexchange.de

# Ask for domain first
read -p "Select domain [leanderziehm.com / tandemexchange.de] (default: leanderziehm.com): " CHOSEN_DOMAIN
DOMAIN_BASE=${CHOSEN_DOMAIN:-leanderziehm.com}

# Then ask for app name and port
read -p "Enter your web app name (subdomain, e.g., web-change-tracker): " APP_NAME
read -p "Enter the port your app will run on (e.g., 5014): " APP_PORT

# Construct full domain
DOMAIN="$APP_NAME.$DOMAIN_BASE"

NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

# Create Nginx config
echo "Creating Nginx config for $DOMAIN..."
sudo tee $NGINX_AVAILABLE > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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

echo "Setup complete! Your app is available at https://$DOMAIN"
