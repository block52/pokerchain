#!/bin/bash
# NGINX and SSL Setup Script for Pokerchaind
# Usage: ./setup-nginx.sh <domain> [remote-host] [remote-user]
# Example: ./setup-nginx.sh block52.xyz node1.block52.xyz root
# 
# This script configures:
#   - REST API on https://<domain>
#   - gRPC on grpcs://<domain>:9443
#   - WebSocket PVM on wss://<domain>/ws (port 8545)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get domain from arguments or prompt user
if [ -z "$1" ]; then
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        NGINX & SSL Setup for Pokerchaind                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Enter domain name (e.g., block52.xyz): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}❌ Domain cannot be empty${NC}"
        exit 1
    fi
else
    DOMAIN="$1"
fi

# Get remote host (defaults to domain if not provided)
if [ -z "$2" ]; then
    REMOTE_HOST="$DOMAIN"
else
    REMOTE_HOST="$2"
fi

REMOTE_USER="${3:-root}"
ADMIN_EMAIL="admin@${DOMAIN}"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        NGINX & SSL Setup for Pokerchaind                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Setting up NGINX and SSL on $REMOTE_HOST${NC}"
echo -e "${BLUE}Domain: $DOMAIN${NC}"
echo ""

# Execute on remote server
ssh "$REMOTE_USER@$REMOTE_HOST" "DOMAIN=${DOMAIN} ADMIN_EMAIL=${ADMIN_EMAIL}" bash << 'ENDSSH'
set -e

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Installing NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v nginx &> /dev/null; then
    echo "📦 Installing NGINX..."
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" nginx
    echo "✅ NGINX installed"
else
    echo "✅ NGINX already installed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Installing Certbot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! command -v certbot &> /dev/null; then
    echo "📦 Installing Certbot and NGINX plugin..."
    echo "   This may take a minute..."
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" certbot python3-certbot-nginx
    echo "✅ Certbot installed"
else
    echo "✅ Certbot already installed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Stopping NGINX and Cleaning Existing Configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl stop nginx 2>/dev/null || true
echo "✅ NGINX stopped"

echo ""
echo "Cleaning up old NGINX configurations..."

# Remove all existing site configurations
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/default
rm -f /etc/nginx/sites-available/default.bak

# List any remaining site configs (excluding our target domain)
EXISTING_SITES=$(ls /etc/nginx/sites-available/ 2>/dev/null | grep -v "^${DOMAIN}$" || true)
if [ -n "$EXISTING_SITES" ]; then
    echo "Found existing site configurations:"
    echo "$EXISTING_SITES" | while read site; do
        echo "  - $site"
    done
    echo ""
    echo "These will remain but won't be enabled."
fi

echo "✅ Cleaned up existing NGINX configurations"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Creating Initial HTTP Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Remove existing domain config if it exists
rm -f /etc/nginx/sites-available/${DOMAIN}

# Create initial HTTP-only NGINX config (Certbot will add SSL later)
cat > /etc/nginx/sites-available/${DOMAIN} << 'ENDNGINX'
# Pokerchaind REST API Configuration (Initial HTTP-only)
# Domain: ${DOMAIN}
# This will be modified by Certbot to add SSL

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # Allow Certbot to verify domain ownership
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Logging
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    # Increase timeouts for blockchain operations
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    # CORS headers for API
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;

    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        return 204;
    }

    # REST API - Cosmos SDK
    location / {
        proxy_pass http://127.0.0.1:1317;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Tendermint RPC
    location /rpc/ {
        proxy_pass http://127.0.0.1:26657/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support for subscriptions
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # PVM WebSocket endpoint on /ws path
    location /ws {
        proxy_pass http://127.0.0.1:8545;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support - critical for PVM
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Prevent connection timeout for long-lived connections
        proxy_read_timeout 86400;
    }
}
ENDNGINX

# Replace ${DOMAIN} placeholder with actual domain
sed -i "s/\${DOMAIN}/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

echo "✅ Created initial HTTP configuration: /etc/nginx/sites-available/$DOMAIN"

# Enable the site
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
# Make this the default site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/default
echo "✅ Enabled site configuration"

# Test NGINX configuration
echo ""
echo "Testing NGINX configuration..."
if nginx -t; then
    echo "✅ NGINX configuration is valid"
else
    echo "❌ NGINX configuration has errors"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Configuring Firewall"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if UFW is installed and active
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | grep -c "Status: active" || echo "0")
    
    if [ "$UFW_STATUS" -gt 0 ]; then
        echo "📋 UFW firewall detected - ensuring required ports are open"
        
        # Check current status of ports
        PORT_80_STATUS=$(ufw status | grep -c "80/tcp.*ALLOW" || echo "0")
        PORT_443_STATUS=$(ufw status | grep -c "443/tcp.*ALLOW" || echo "0")
        PORT_9443_STATUS=$(ufw status | grep -c "9443/tcp.*ALLOW" || echo "0")
        
        # Open port 80 if not already open (needed for certbot)
        if [ "$PORT_80_STATUS" -eq 0 ]; then
            echo "🔓 Opening port 80 (required for SSL certificate verification)..."
            ufw allow 80/tcp comment 'HTTP (Certbot)'
            PORT_80_WAS_CLOSED=1
        else
            echo "✅ Port 80 already open"
            PORT_80_WAS_CLOSED=0
        fi

        # REMOVE: Open port 1317 for REST API (no longer needed)
        # if [ "$PORT_1317_STATUS" -eq 0 ]; then
        #     echo "🔓 Opening port 1317 (REST API)..."
        #     ufw allow 1317/tcp comment 'REST API'
        # else
        #     echo "✅ Port 1317 already open"
        # fi
        
        # Open port 443 if not already open
        if [ "$PORT_443_STATUS" -eq 0 ]; then
            echo "🔓 Opening port 443 (HTTPS)..."
            ufw allow 443/tcp comment 'HTTPS'
        else
            echo "✅ Port 443 already open"
        fi
        
        # Open port 9443 for gRPC HTTPS
        if [ "$PORT_9443_STATUS" -eq 0 ]; then
            echo "🔓 Opening port 9443 (gRPC HTTPS)..."
            ufw allow 9443/tcp comment 'gRPC HTTPS'
        else
            echo "✅ Port 9443 already open"
        fi
        
        echo "✅ Firewall configured"
    else
        echo "⚠️  UFW installed but not active"
        PORT_80_WAS_CLOSED=0
    fi
else
    echo "ℹ️  UFW not installed - skipping firewall configuration"
    PORT_80_WAS_CLOSED=0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Starting NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl start nginx
systemctl enable nginx
echo "✅ NGINX started and enabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Obtaining SSL Certificate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if certificate already exists
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "⚠️  Existing SSL certificate found for $DOMAIN"
    echo "Deleting existing certificate to obtain fresh one..."
    certbot delete --non-interactive --cert-name $DOMAIN 2>/dev/null || true
    echo "✅ Old certificate removed"
fi

echo ""
echo "Requesting fresh SSL certificate for $DOMAIN..."
echo "Email: $ADMIN_EMAIL"
echo ""
echo "Certbot will automatically:"
echo "  • Obtain SSL certificate from Let's Encrypt"
echo "  • Configure NGINX for HTTPS"
echo "  • Set up HTTP to HTTPS redirect"
echo ""

# Use certbot in certonly mode (don't let it modify nginx config)
echo "Obtaining SSL certificate (without automatic nginx configuration)..."
if certbot certonly \
    --webroot \
    --webroot-path=/var/www/html \
    --non-interactive \
    --agree-tos \
    --email $ADMIN_EMAIL \
    --domains $DOMAIN \
    --force-renewal 2>&1 | tee /tmp/certbot-output.log; then
    echo "✅ SSL certificate obtained successfully"
else
    echo "❌ Failed to obtain SSL certificate"
    echo "Please check:"
    echo "  1. DNS is correctly pointing to this server"
    echo "  2. Port 80 is accessible from the internet"
    echo "  3. No firewall blocking Let's Encrypt validation"
    cat /tmp/certbot-output.log
    exit 1
fi

echo ""
echo "Manually configuring NGINX for SSL..."

# Now manually add SSL configuration to our existing HTTP config
# We'll create the HTTPS server block ourselves
cat > /etc/nginx/sites-available/${DOMAIN}-ssl << 'ENDSSL'
# HTTPS - REST API
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN}/chain.pem;

    # Logging
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    # Increase timeouts for blockchain operations
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    # CORS headers for API
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;

    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        return 204;
    }

    # REST API - Cosmos SDK
    location / {
        proxy_pass http://127.0.0.1:1317;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Tendermint RPC
    location /rpc/ {
        proxy_pass http://127.0.0.1:26657/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # WebSocket support for subscriptions
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # PVM WebSocket endpoint on /ws path
    location /ws {
        proxy_pass http://127.0.0.1:8545;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port 443;
        
        # WebSocket support - critical for PVM
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Prevent connection timeout for long-lived connections
        proxy_read_timeout 86400;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    
    # Allow Certbot to verify domain ownership
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
ENDSSL

# Replace ${DOMAIN} placeholder
sed -i "s/\${DOMAIN}/$DOMAIN/g" /etc/nginx/sites-available/${DOMAIN}-ssl

# Remove the old HTTP-only config and replace with SSL version
rm -f /etc/nginx/sites-available/${DOMAIN}
mv /etc/nginx/sites-available/${DOMAIN}-ssl /etc/nginx/sites-available/${DOMAIN}

# Enable the site
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/default

echo "✅ SSL configuration created manually"

echo ""

# Close port 80 if we opened it earlier (only if UFW was active and we opened it)
if [ "${PORT_80_WAS_CLOSED:-0}" -eq 1 ]; then
    echo "🔒 Closing port 80 (no longer needed after SSL setup)..."
    ufw delete allow 80/tcp
    echo "✅ Port 80 closed"
fi

echo ""
echo "✅ SSL certificate obtained and NGINX configured for HTTPS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Fixing SSL Proxy Headers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# After certbot runs, we need to ensure proxy headers are correct in SSL block
# Update the SSL server block to have proper headers
if grep -q "listen 443 ssl" /etc/nginx/sites-available/$DOMAIN; then
    echo "Updating SSL configuration with proper proxy headers..."
    
    # Use sed to replace X-Forwarded-Proto $scheme with X-Forwarded-Proto https in SSL block
    # This ensures the backend knows it's receiving HTTPS traffic
    sed -i '/listen 443 ssl/,/^}/ {
        s|proxy_set_header X-Forwarded-Proto \$scheme;|proxy_set_header X-Forwarded-Proto https;|g
    }' /etc/nginx/sites-available/$DOMAIN
    
    echo "✅ Updated proxy headers for SSL"
else
    echo "⚠️  No SSL configuration found yet"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Adding gRPC HTTPS Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Now add gRPC server block to the existing config
# Append to the end of the file before the last closing brace
# Only add gRPC server block if not already present
if ! grep -q 'listen 9443 ssl http2;' /etc/nginx/sites-available/$DOMAIN; then
cat >> /etc/nginx/sites-available/$DOMAIN << 'ENDGRPC'

# HTTPS - gRPC
server {
    listen 9443 ssl http2;
    listen [::]:9443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates (configured by certbot)
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Logging
    access_log /var/log/nginx/${DOMAIN}_grpc_access.log;
    error_log /var/log/nginx/${DOMAIN}_grpc_error.log;

    # gRPC proxy
    location / {
        grpc_pass grpc://127.0.0.1:9090;
        grpc_set_header Host $host;
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto https;
        grpc_set_header X-Forwarded-Host $host;
        grpc_set_header X-Forwarded-Port 9443;

        # Error handling
        error_page 502 = /error502grpc;
    }

    location = /error502grpc {
        internal;
        default_type application/grpc;
        add_header grpc-status 14;
        add_header content-length 0;
        return 204;
    }
}
ENDGRPC

# Replace ${DOMAIN} placeholder in the gRPC section
sed -i "s/\${DOMAIN}/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

echo "✅ Added gRPC HTTPS configuration"
else
    echo "gRPC HTTPS configuration already present, skipping duplicate."
fi

# Test the updated configuration
echo ""
echo "Testing updated NGINX configuration..."
if nginx -t; then
    echo "✅ NGINX configuration is valid"
else
    echo "❌ NGINX configuration has errors"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Finalizing Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Restart NGINX to apply all changes
systemctl restart nginx
echo "✅ NGINX restarted with full SSL configuration"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 11: Setting up Auto-renewal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test certbot renewal
certbot renew --dry-run

echo "✅ Auto-renewal configured and tested"

# Show final status
echo ""
echo "NGINX Status:"
systemctl status nginx --no-pager -l | head -n 15

ENDSSH

# Back to local machine
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        NGINX & SSL SETUP COMPLETE!                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📋 Configuration Summary:${NC}"
echo ""
echo "✅ NGINX installed and configured"
echo "✅ SSL certificate obtained from Let's Encrypt"
echo "✅ HTTP to HTTPS redirect enabled"
echo "✅ gRPC HTTPS configured on port 9443"
echo "✅ WebSocket PVM configured at /ws path (port 8545)"
echo "✅ Auto-renewal configured"
echo ""
echo -e "${YELLOW}🌐 Your endpoints:${NC}"
echo ""
echo "  REST API (HTTPS):"
echo "    https://${DOMAIN}/"
echo ""
echo "  Tendermint RPC (via HTTPS):"
echo "    https://${DOMAIN}/rpc/status"
echo ""
echo "  gRPC (HTTPS):"
echo "    grpcs://${DOMAIN}:9443"
echo ""
echo "  WebSocket PVM (HTTPS):"
echo "    wss://${DOMAIN}/ws"
echo "    (Poker Virtual Machine - port 8545)"
echo ""
echo -e "${YELLOW}🧪 Test your endpoints:${NC}"
echo ""
echo "  # REST API"
echo "  curl https://${DOMAIN}/cosmos/base/tendermint/v1beta1/node_info"
echo ""
echo "  # RPC via HTTPS"
echo "  curl https://${DOMAIN}/rpc/status"
echo ""
echo -e "${YELLOW}📊 Monitor NGINX:${NC}"
echo ""
echo "  # View logs"
echo "  ssh $REMOTE_USER@$REMOTE_HOST 'tail -f /var/log/nginx/${DOMAIN}_access.log'"
echo ""
echo "  # Check status"
echo "  ssh $REMOTE_USER@$REMOTE_HOST 'systemctl status nginx'"
echo ""
echo "  # Test SSL certificate"
echo "  ssh $REMOTE_USER@$REMOTE_HOST 'certbot certificates'"
echo ""
echo -e "${YELLOW}🔄 Certificate auto-renewal:${NC}"
echo "  Certbot will automatically renew certificates before expiry."
echo "  Test renewal: ssh $REMOTE_USER@$REMOTE_HOST 'certbot renew --dry-run'"
echo ""
echo -e "${GREEN}🎉 Your node is now secured with HTTPS!${NC}"
echo ""

echo ""
echo "Disabling port 80 on UFW (HTTP no longer needed after SSL)..."
if command -v ufw &> /dev/null; then
    ufw deny 80/tcp || true
    echo "✅ Port 80 closed on UFW"
fi