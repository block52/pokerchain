#!/bin/bash

# Deploy Poker VM to Remote Server
# This script deploys the Poker VM Docker container to a remote Linux server
# Usage: ./deploy-pvm.sh [remote_host] [remote_user] [pvm_port]

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default values
DEFAULT_USER="root"
DEFAULT_PORT="3000"

# Print header
print_header() {
    clear
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              🎲 Poker VM Remote Deployment 🎲"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

# Get server details from arguments or prompts
get_server_details() {
    if [ -n "$1" ]; then
        remote_host="$1"
    else
        echo -e "${BLUE}Enter the remote server details:${NC}"
        echo ""
        read -p "Remote host (e.g., pvm.example.com or 192.168.1.100): " remote_host
    fi
    
    if [ -z "$remote_host" ]; then
        echo -e "${RED}❌ Remote host cannot be empty${NC}"
        exit 1
    fi
    
    if [ -n "$2" ]; then
        remote_user="$2"
    else
        read -p "Remote user (default: $DEFAULT_USER): " remote_user
    fi
    remote_user=${remote_user:-$DEFAULT_USER}
    
    if [ -n "$3" ]; then
        pvm_port="$3"
    else
        read -p "PVM port (default: $DEFAULT_PORT): " pvm_port
    fi
    pvm_port=${pvm_port:-$DEFAULT_PORT}
}

# Confirm deployment
confirm_deployment() {
    echo ""
    echo "📋 Deployment Configuration:"
    echo "   Remote Host: $remote_host"
    echo "   Remote User: $remote_user"
    echo "   PVM Port: $pvm_port"
    echo "   Repository: https://github.com/block52/poker-vm.git"
    echo ""
    read -p "Continue with deployment? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
}

# Check SSH connectivity
check_ssh() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 1: Checking SSH connectivity...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if ! ssh -o ConnectTimeout=10 "$remote_user@$remote_host" "echo 'SSH connection successful'" 2>/dev/null; then
        echo -e "${RED}❌ Failed to connect to $remote_host${NC}"
        echo "Please check:"
        echo "  1. Host is reachable"
        echo "  2. SSH keys are set up"
        echo "  3. User has correct permissions"
        exit 1
    fi
    
    echo -e "${GREEN}✅ SSH connection successful${NC}"
}

# Install Docker if needed
install_docker() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 2: Checking and installing Docker...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ssh "$remote_user@$remote_host" bash << 'ENDSSH'
        # Check if Docker is installed
        if command -v docker &> /dev/null; then
            echo "✅ Docker is already installed"
            docker --version
        else
            echo "📦 Installing Docker..."
            
            # Update package index
            apt-get update
            
            # Install prerequisites
            apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # Add Docker's official GPG key
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up the repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            # Enable and start Docker
            systemctl enable docker
            systemctl start docker
            
            echo "✅ Docker installed successfully"
            docker --version
        fi
        
        # Verify Docker is running
        if systemctl is-active --quiet docker; then
            echo "✅ Docker service is running"
        else
            echo "⚠️  Docker service is not running, attempting to start..."
            systemctl start docker
        fi
ENDSSH
}

# Clone poker-vm repository
clone_repository() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 3: Cloning poker-vm repository...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ssh "$remote_user@$remote_host" bash << ENDSSH
        # Remove existing directory if it exists
        if [ -d "/root/poker-vm" ]; then
            echo "🗑️  Removing existing poker-vm directory..."
            rm -rf /root/poker-vm
        fi
        
        # Clone the repository
        echo "📥 Cloning poker-vm repository..."
        cd /root
        git clone https://github.com/block52/poker-vm.git
        
        if [ -d "/root/poker-vm" ]; then
            echo "✅ Repository cloned successfully"
        else
            echo "❌ Failed to clone repository"
            exit 1
        fi
ENDSSH
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to clone repository${NC}"
        exit 1
    fi
}

# Build Docker image
build_docker_image() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Building Docker image...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ssh "$remote_user@$remote_host" bash << ENDSSH
        cd /root/poker-vm/pvm/ts
        
        if [ ! -f "Dockerfile" ]; then
            echo "❌ Dockerfile not found in /root/poker-vm/pvm/ts"
            exit 1
        fi
        
        echo "🐳 Building Docker image (this may take several minutes)..."
        docker build -t poker-vm:latest .
        
        if [ \$? -eq 0 ]; then
            echo "✅ Docker image built successfully"
            docker images | grep poker-vm
        else
            echo "❌ Failed to build Docker image"
            exit 1
        fi
ENDSSH
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to build Docker image${NC}"
        exit 1
    fi
}

# Setup systemd service
setup_systemd_service() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Setting up systemd service...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ssh "$remote_user@$remote_host" bash << ENDSSH
        # Create systemd service file
        cat > /etc/systemd/system/poker-vm.service << 'EOF'
[Unit]
Description=Poker VM Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop poker-vm
ExecStartPre=-/usr/bin/docker rm poker-vm
ExecStart=/usr/bin/docker run --name poker-vm --rm -p ${pvm_port}:3000 poker-vm:latest
ExecStop=/usr/bin/docker stop poker-vm

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd
        systemctl daemon-reload
        
        # Enable the service
        systemctl enable poker-vm
        
        # Start the service
        systemctl start poker-vm
        
        echo "✅ Systemd service created and started"
        
        # Wait a moment for the service to start
        sleep 3
        
        # Check status
        systemctl status poker-vm --no-pager
ENDSSH
}

# Print success summary
print_success() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ PVM Deployment Complete!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   Host: $remote_host"
    echo "   Port: $pvm_port"
    echo "   Service: poker-vm.service"
    echo ""
    echo "🔧 Service Management:"
    echo "   Status:  ssh $remote_user@$remote_host 'systemctl status poker-vm'"
    echo "   Logs:    ssh $remote_user@$remote_host 'journalctl -u poker-vm -f'"
    echo "   Restart: ssh $remote_user@$remote_host 'systemctl restart poker-vm'"
    echo "   Stop:    ssh $remote_user@$remote_host 'systemctl stop poker-vm'"
    echo ""
    echo "🌐 Access PVM:"
    echo "   http://$remote_host:$pvm_port"
    echo ""
}

# Main execution
main() {
    print_header
    get_server_details "$@"
    confirm_deployment
    check_ssh
    install_docker
    clone_repository
    build_docker_image
    setup_systemd_service
    print_success
}

# Run main function
main "$@"
