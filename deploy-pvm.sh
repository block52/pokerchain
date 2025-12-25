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
DEFAULT_PORT="8545"

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

# Setup Node.js 22.12 using nvm
setup_nodejs() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 4: Setting up Node.js 22.12 via nvm...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ssh "$remote_user@$remote_host" bash << 'ENDSSH'
        set -e

        REQUIRED_NODE_VERSION="22.12.0"

        # Check current Node.js version
        if command -v node &> /dev/null; then
            CURRENT_VERSION=$(node --version | sed 's/v//')
            echo "Current Node.js version: $CURRENT_VERSION"

            # Check if it's exactly 22.12.x
            if [[ "$CURRENT_VERSION" == 22.12.* ]]; then
                echo "✅ Node.js 22.12.x is already installed"
                exit 0
            else
                echo "⚠️  Wrong Node.js version ($CURRENT_VERSION), need 22.12.x"
            fi
        fi

        # Install nvm if not present
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            echo "📦 Installing nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        fi

        # Load nvm
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        # Install Node.js 22.12
        echo "📦 Installing Node.js $REQUIRED_NODE_VERSION via nvm..."
        nvm install $REQUIRED_NODE_VERSION
        nvm use $REQUIRED_NODE_VERSION
        nvm alias default $REQUIRED_NODE_VERSION

        # Verify installation
        echo "Node.js version: $(node --version)"
        echo "npm version: $(npm --version)"

        # Create symlinks for system-wide access (for Docker builds)
        NODE_PATH=$(which node)
        NPM_PATH=$(which npm)

        echo "Creating system symlinks..."
        ln -sf "$NODE_PATH" /usr/local/bin/node
        ln -sf "$NPM_PATH" /usr/local/bin/npm

        # Install yarn globally
        if ! command -v yarn &> /dev/null; then
            echo "📦 Installing Yarn..."
            npm install -g yarn
        fi

        YARN_PATH=$(which yarn)
        ln -sf "$YARN_PATH" /usr/local/bin/yarn

        echo "✅ Node.js $REQUIRED_NODE_VERSION setup complete"
        echo "   node: $(node --version)"
        echo "   npm: $(npm --version)"
        echo "   yarn: $(yarn --version)"
ENDSSH

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to setup Node.js${NC}"
        exit 1
    fi
}

# Build TypeScript
build_typescript() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 5: Building TypeScript...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ssh "$remote_user@$remote_host" bash << 'ENDSSH'
        set -e

        # Load nvm to ensure correct Node version
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        # Verify Node.js version
        echo "Using Node.js: $(node --version)"

        # Check it's 22.12.x
        NODE_VERSION=$(node --version | sed 's/v//')
        if [[ ! "$NODE_VERSION" == 22.12.* ]]; then
            echo "❌ Wrong Node.js version: $NODE_VERSION (expected 22.12.x)"
            echo "   Run 'nvm use 22.12.0' to switch versions"
            exit 1
        fi

        cd /root/poker-vm/pvm/ts

        echo "Yarn version: $(yarn --version)"

        # Install dependencies
        echo "📦 Installing dependencies..."
        yarn install

        # Build TypeScript
        echo "🔨 Building TypeScript..."
        yarn build

        if [ -d "dist" ]; then
            echo "✅ TypeScript build successful"
            ls -la dist/
        else
            echo "❌ TypeScript build failed - dist folder not found"
            exit 1
        fi
ENDSSH

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to build TypeScript${NC}"
        exit 1
    fi
}

# Clean up old Docker resources
cleanup_docker() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 6: Cleaning up old Docker resources...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ssh "$remote_user@$remote_host" bash << 'ENDSSH'
        echo "🧹 Stopping and removing existing poker-vm container..."
        docker stop poker-vm 2>/dev/null || true
        docker rm poker-vm 2>/dev/null || true

        echo "🧹 Removing old poker-vm images..."
        # Remove all poker-vm images (tagged and untagged)
        docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep poker-vm | awk '{print $2}' | xargs -r docker rmi -f 2>/dev/null || true

        echo "🧹 Removing stopped containers..."
        docker container prune -f 2>/dev/null || true

        echo "🧹 Removing dangling images..."
        docker image prune -f 2>/dev/null || true

        echo "🧹 Removing unused volumes..."
        docker volume prune -f 2>/dev/null || true

        echo "🧹 Removing build cache..."
        docker builder prune -f 2>/dev/null || true

        echo "✅ Docker cleanup complete"
        echo ""
        echo "📊 Docker disk usage after cleanup:"
        docker system df
ENDSSH

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠️  Some cleanup operations may have failed (this is usually OK)${NC}"
    fi
}

# Build Docker image
build_docker_image() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Step 7: Building Docker image...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    ssh "$remote_user@$remote_host" bash << ENDSSH
        cd /root/poker-vm/pvm/ts

        if [ ! -f "Dockerfile" ]; then
            echo "❌ Dockerfile not found in /root/poker-vm/pvm/ts"
            exit 1
        fi

        if [ ! -d "dist" ]; then
            echo "❌ dist folder not found - TypeScript build may have failed"
            exit 1
        fi

        echo "🐳 Building Docker image with --no-cache (this may take several minutes)..."
        docker build --no-cache -t poker-vm:latest .

        if [ \$? -eq 0 ]; then
            echo "✅ Docker image built successfully"

            # Clean up any dangling images created during build
            echo "🧹 Cleaning up build artifacts..."
            docker image prune -f

            echo ""
            echo "📦 Final poker-vm images:"
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
    echo -e "${BLUE}Step 8: Setting up systemd service...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    ssh "$remote_user@$remote_host" bash << ENDSSH
        # Create docker network if it doesn't exist
        docker network create poker-network 2>/dev/null || true

        # Create systemd service file
        cat > /etc/systemd/system/poker-vm.service << EOF
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
ExecStart=/usr/bin/docker run --name poker-vm --rm -p ${pvm_port}:8545 --network poker-network poker-vm:latest
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

# Check PVM health
check_pvm_health() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Checking PVM Health...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "Waiting for PVM to be ready..."
    local max_attempts=30
    local attempt=0
    local success=false
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        echo -n "  Attempt $attempt/$max_attempts: "
        
        # Check if service is running first
        if ! ssh "$remote_user@$remote_host" "systemctl is-active --quiet poker-vm" 2>/dev/null; then
            echo -e "${RED}✗ Service not running${NC}"
            
            # Show service status and logs if failing
            if [ $attempt -eq 5 ] || [ $attempt -eq 15 ]; then
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo -e "${YELLOW}Service Status:${NC}"
                ssh "$remote_user@$remote_host" "systemctl status poker-vm --no-pager -l" 2>/dev/null || true
                echo ""
                echo -e "${YELLOW}Recent Logs:${NC}"
                ssh "$remote_user@$remote_host" "journalctl -u poker-vm -n 20 --no-pager" 2>/dev/null || true
                echo ""
                echo -e "${YELLOW}Docker Logs (if container exists):${NC}"
                ssh "$remote_user@$remote_host" "docker logs poker-vm 2>&1 | tail -20" 2>/dev/null || echo "No container logs available"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
            fi
            sleep 2
            continue
        fi
        
        # Try to curl the PVM endpoint
        if response=$(curl -s -f -m 5 "http://$remote_host:$pvm_port" 2>/dev/null); then
            echo -e "${GREEN}✅ PVM is responding!${NC}"
            success=true
            break
        else
            echo -e "${YELLOW}⏳ Not ready yet...${NC}"
            sleep 2
        fi
    done
    
    echo ""
    
    if [ "$success" = true ]; then
        echo -e "${GREEN}✅ Health check passed!${NC}"
        echo ""
        echo "PVM Response:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        curl -s "http://$remote_host:$pvm_port" | head -20
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo -e "${RED}⚠️  Warning: PVM did not respond within $((max_attempts * 2)) seconds${NC}"
        echo ""
        echo "Diagnostics:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Service Status:"
        ssh "$remote_user@$remote_host" "systemctl status poker-vm --no-pager -l" 2>/dev/null || true
        echo ""
        echo "Recent Service Logs:"
        ssh "$remote_user@$remote_host" "journalctl -u poker-vm -n 30 --no-pager" 2>/dev/null || true
        echo ""
        echo "Docker Container Logs:"
        ssh "$remote_user@$remote_host" "docker logs poker-vm 2>&1 | tail -30" 2>/dev/null || echo "No container logs available"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "To troubleshoot manually:"
        echo "  ssh $remote_user@$remote_host"
        echo "  journalctl -u poker-vm -f              # Watch service logs"
        echo "  docker logs poker-vm -f                # Watch container logs"
        echo "  docker ps -a                           # Check container status"
        echo "  docker run -it poker-vm:latest /bin/sh # Test container interactively"
    fi
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
}

# Main execution
main() {
    print_header
    get_server_details "$@"
    confirm_deployment
    check_ssh
    install_docker
    clone_repository
    setup_nodejs
    build_typescript
    cleanup_docker
    build_docker_image
    setup_systemd_service
    check_pvm_health
    print_success
}

# Run main function
main "$@"
