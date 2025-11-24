#!/bin/bash

# Update Binary on Running Node
# Downloads and installs a new pokerchaind binary on a running node

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
REMOTE_HOST="${1:-node.texashodl.net}"
REMOTE_USER="${2:-root}"
GITHUB_REPO="block52/pokerchain"
VERSION="${3:-v0.1.8}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Updating pokerchaind binary on ${REMOTE_HOST}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}"
echo "Version: ${VERSION}"
echo ""

# Stop the service
echo -e "${YELLOW}Step 1: Stopping pokerchaind service...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "systemctl stop pokerchaind"
echo -e "${GREEN}✓ Service stopped${NC}"
echo ""

# Backup current binary
echo -e "${YELLOW}Step 2: Backing up current binary...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "cp /usr/local/bin/pokerchaind /usr/local/bin/pokerchaind.backup.$(date +%Y%m%d_%H%M%S) || true"
echo -e "${GREEN}✓ Binary backed up${NC}"
echo ""

# Download new binary
echo -e "${YELLOW}Step 3: Downloading new binary (${VERSION})...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} << ENDSSH
set -e

# Download from GitHub release
cd /tmp
wget -q https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/pokerchaind-linux-amd64-${VERSION}.tar.gz

# Extract
tar -xzf pokerchaind-linux-amd64-${VERSION}.tar.gz

# Install
mv pokerchaind-linux-amd64 /usr/local/bin/pokerchaind
chmod +x /usr/local/bin/pokerchaind

# Cleanup
rm pokerchaind-linux-amd64-${VERSION}.tar.gz

echo "Binary updated successfully"
ENDSSH
echo -e "${GREEN}✓ Binary downloaded and installed${NC}"
echo ""

# Verify version
echo -e "${YELLOW}Step 4: Verifying version...${NC}"
NEW_VERSION=$(ssh ${REMOTE_USER}@${REMOTE_HOST} "/usr/local/bin/pokerchaind version")
echo "Installed version: ${NEW_VERSION}"
echo -e "${GREEN}✓ Version verified${NC}"
echo ""

# Start the service
echo -e "${YELLOW}Step 5: Starting pokerchaind service...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "systemctl start pokerchaind"
sleep 3
echo -e "${GREEN}✓ Service started${NC}"
echo ""

# Check status
echo -e "${YELLOW}Step 6: Checking service status...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "systemctl status pokerchaind --no-pager | head -20"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Binary update completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "New version: ${NEW_VERSION}"
echo ""
echo "To check logs:"
echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'journalctl -u pokerchaind -f'"
