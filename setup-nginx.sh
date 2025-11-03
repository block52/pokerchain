#!/bin/bash
# NGINX and SSL Setup Script for Pokerchaind
# Usage: ./setup-nginx.sh <domain> [remote-host] [remote-user]
# Example: ./setup-nginx.sh block52.xyz node1.block52.xyz root

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
echo -e "${YELLOW}Configuration:${NC}"
echo "  Domain:       $DOMAIN"
echo "  Remote Host:  $REMOTE_HOST"
echo "  Remote User:  $REMOTE_USER"
echo "  Admin Email:  $ADMIN_EMAIL"
echo ""
echo -e "${YELLOW}Services to be configured:${NC}"
echo "  • REST API (HTTPS) - Port 1317 → 443"
echo "  • gRPC (HTTPS) - Port 9090"
echo "  • SSL Certificates via Certbot"
echo ""
read -p "Continue with this configuration? (y/n): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Setting up NGINX and SSL on $REMOTE_HOST${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
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
echo "Step 3: Stopping NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl stop nginx 2>/dev/null || true
echo "✅ NGINX stopped"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Creating NGINX Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Remove existing config if it exists
rm -f /etc/nginx/sites-enabled/${DOMAIN}
rm -f /etc/nginx/sites-available/${DOMAIN}

# Create NGINX config
cat > /etc/nginx/sites-available/${DOMAIN} << 'ENDNGINX'
# Pokerchaind REST API and gRPC Proxy Configuration
# Domain: ${DOMAIN}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS - REST API
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # CORS headers for API
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization" always;
    add_header Access-Control-Expose-Headers "Content-Length,Content-Range" always;

    # Handle preflight requests
    if (\$request_method = 'OPTIONS') {
        return 204;
    }

    # Logging
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    # Increase timeouts for blockchain operations
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    # REST API - Cosmos SDK
    location / {
        proxy_pass http://127.0.0.1:1317;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Tendermint RPC (optional - you may want to keep this on port 26657)
    location /rpc/ {
        proxy_pass http://127.0.0.1:26657/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support for subscriptions
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# HTTPS - gRPC
server {
    listen 9443 ssl http2;
    listen [::]:9443 ssl http2;
    server_name ${DOMAIN};

    # SSL certificates (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/${DOMAIN}_grpc_access.log;
    error_log /var/log/nginx/${DOMAIN}_grpc_error.log;

    # gRPC proxy
    location / {
        grpc_pass grpc://127.0.0.1:9090;
        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto \$scheme;

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
ENDNGINX

# Replace ${DOMAIN} placeholder with actual domain
sed -i "s/\\\${DOMAIN}/$DOMAIN/g" /etc/nginx/sites-available/$DOMAIN

echo "✅ Created NGINX configuration: /etc/nginx/sites-available/$DOMAIN"

# Enable the site
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
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
echo "Step 5: Configuring Firewall for SSL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if UFW is installed and active
if command -v ufw &> /dev/null; then
    UFW_STATUS=\$(ufw status | grep -c "Status: active" || echo "0")
    
    if [ "\$UFW_STATUS" -gt 0 ]; then
        echo "📋 UFW firewall detected - ensuring required ports are open"
        
        # Check current status of ports
        PORT_80_STATUS=\$(ufw status | grep -c "80/tcp.*ALLOW" || echo "0")
        PORT_443_STATUS=\$(ufw status | grep -c "443/tcp.*ALLOW" || echo "0")
        
        # Open port 80 if not already open (needed for certbot)
        if [ "\$PORT_80_STATUS" -eq 0 ]; then
            echo "🔓 Opening port 80 (required for SSL certificate verification)..."
            ufw allow 80/tcp comment 'HTTP (Certbot)'
            PORT_80_WAS_CLOSED=1
        else
            echo "✅ Port 80 already open"
            PORT_80_WAS_CLOSED=0
        fi
        
        # Open port 443 if not already open
        if [ "\$PORT_443_STATUS" -eq 0 ]; then
            echo "🔓 Opening port 443 (HTTPS)..."
            ufw allow 443/tcp comment 'HTTPS'
        else
            echo "✅ Port 443 already open"
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

echo "Requesting SSL certificate for $DOMAIN..."
echo "Email: $ADMIN_EMAIL"
echo ""

# Run certbot to get certificate and auto-configure nginx
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email $ADMIN_EMAIL \
    --domains $DOMAIN \
    --redirect \
    --hsts \
    --staple-ocsp

echo ""
echo "✅ SSL certificate obtained and configured"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Securing Firewall"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Close port 80 if we opened it and user wants it closed
if command -v ufw &> /dev/null && [ "\$PORT_80_WAS_CLOSED" -eq 1 ]; then
    UFW_STATUS=\$(ufw status | grep -c "Status: active" || echo "0")
    if [ "\$UFW_STATUS" -gt 0 ]; then
        echo "🔒 Closing port 80 (initial certificate obtained)..."
        echo ""
        echo "⚠️  Important: Port 80 is needed for certificate renewals!"
        echo ""
        echo "Options:"
        echo "  1) Keep port 80 open (recommended - allows automatic renewals)"
        echo "  2) Close port 80 now (you'll need to open it manually for renewals)"
        echo ""
        
        # Default to keeping it open for automatic operation
        # If you want interactive choice, uncomment the read below
        CLOSE_PORT_80="n"
        # read -p "Close port 80? (y/n) [default: n]: " CLOSE_PORT_80
        
        if [[ "\$CLOSE_PORT_80" =~ ^[Yy]\$ ]]; then
            ufw delete allow 80/tcp
            echo "🔒 Port 80 closed"
            echo ""
            echo "⚠️  Remember: You'll need to temporarily open port 80 for renewals:"
            echo "   ufw allow 80/tcp"
            echo "   certbot renew"
            echo "   ufw delete allow 80/tcp"
        else
            echo "✅ Port 80 remains open for automatic certificate renewals"
            echo "   This is the recommended configuration."
        fi
    fi
else
    echo "ℹ️  Port 80 configuration unchanged"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Setting up Auto-renewal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test certbot renewal
certbot renew --dry-run

echo "✅ Auto-renewal configured (certbot timer runs daily)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Final Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Restart NGINX to apply all changes
systemctl restart nginx
echo "✅ NGINX restarted with SSL configuration"

# Show status
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
echo "  Direct RPC (HTTP - still available):"
echo "    http://${DOMAIN}:26657/status"
echo ""
echo -e "${YELLOW}🧪 Test your endpoints:${NC}"
echo ""
echo "  # REST API"
echo "  curl https://${DOMAIN}/cosmos/base/tendermint/v1beta1/node_info"
echo ""
echo "  # RPC via NGINX"
echo "  curl https://${DOMAIN}/rpc/status"
echo ""
echo "  # Direct RPC (if port 26657 is open)"
echo "  curl http://${DOMAIN}:26657/status"
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