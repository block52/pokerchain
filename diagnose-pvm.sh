#!/bin/bash

# Quick PVM Diagnostics Script
# Usage: ./diagnose-pvm.sh [remote_host] [remote_user]

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get parameters
remote_host="${1:-pvm.block52.xyz}"
remote_user="${2:-root}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 PVM Diagnostics${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Host: $remote_host"
echo "User: $remote_user"
echo ""

echo -e "${YELLOW}1. Systemd Service Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "systemctl status poker-vm --no-pager -l" 2>&1 || true
echo ""

echo -e "${YELLOW}2. Recent Service Logs (last 50 lines):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "journalctl -u poker-vm -n 50 --no-pager" 2>&1 || true
echo ""

echo -e "${YELLOW}3. Docker Container Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "docker ps -a | grep poker-vm || echo 'No poker-vm container found'" 2>&1 || true
echo ""

echo -e "${YELLOW}4. Docker Container Logs (if available):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "docker logs poker-vm 2>&1 | tail -50" 2>&1 || echo "Container not running or no logs available"
echo ""

echo -e "${YELLOW}5. Docker Image Info:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "docker images | grep poker-vm || echo 'No poker-vm image found'" 2>&1 || true
echo ""

echo -e "${YELLOW}6. Test Docker Run (interactive):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing if container can start..."
ssh "$remote_user@$remote_host" "timeout 5 docker run --rm poker-vm:latest echo 'Container can start' 2>&1 || echo 'Container failed to start'" 2>&1 || true
echo ""

echo -e "${YELLOW}7. Check Repository:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh "$remote_user@$remote_host" "ls -la /root/poker-vm/pvm/ts/ 2>&1 || echo 'Directory not found'" 2>&1 || true
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Diagnostics Complete${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Common issues:"
echo "  • Missing dependencies in Dockerfile"
echo "  • Port 3000 not exposed in Dockerfile"
echo "  • Application crashes on startup"
echo "  • Missing environment variables"
echo ""
echo "To investigate further:"
echo "  ssh $remote_user@$remote_host"
echo "  cd /root/poker-vm/pvm/ts"
echo "  docker build -t test-pvm ."
echo "  docker run -it test-pvm /bin/sh  # Interactive shell"
