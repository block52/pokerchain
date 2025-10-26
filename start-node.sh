#!/bin/bash

# Quick Start Script for Pokerchaind
# Starts your local pokerchaind node with smart detection

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HOME_DIR="$HOME/.pokerchain"
RPC_PORT=26657
API_PORT=1317

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check if node is initialized
if [ ! -d "$HOME_DIR" ]; then
    print_error "Pokerchaind not initialized"
    echo ""
    echo "Please set up a node first:"
    echo "  ./setup-sync-node.sh"
    echo "  OR"
    echo "  ./setup-network.sh → Option 2"
    exit 1
fi

# Check if pokerchaind is installed
if ! command -v pokerchaind &> /dev/null; then
    print_error "pokerchaind not found in PATH"
    echo ""
    echo "Please install pokerchaind:"
    echo "  make install"
    echo ""
    echo "Or add to PATH:"
    echo "  export PATH=\"\$HOME/go/bin:\$PATH\""
    exit 1
fi

print_success "pokerchaind found: $(which pokerchaind)"

# Check if already running
if pgrep -x pokerchaind > /dev/null; then
    print_warning "pokerchaind is already running"
    echo ""
    
    # Show status
    if systemctl is-active --quiet pokerchaind 2>/dev/null; then
        echo "Running as systemd service:"
        sudo systemctl status pokerchaind --no-pager -l | head -20
    else
        echo "Running as standalone process (PID: $(pgrep -x pokerchaind))"
    fi
    
    echo ""
    
    # Check if RPC is responding
    if curl -s --max-time 3 http://localhost:$RPC_PORT/status > /dev/null 2>&1; then
        print_success "RPC is responding"
        echo ""
        echo "Current status:"
        curl -s http://localhost:$RPC_PORT/status | jq -r '
            "  Chain ID: " + .result.node_info.network,
            "  Latest Block: " + .result.sync_info.latest_block_height,
            "  Catching Up: " + (.result.sync_info.catching_up | tostring)
        ' 2>/dev/null || echo "  (jq not installed - use: curl http://localhost:$RPC_PORT/status)"
    else
        print_warning "RPC not responding yet (node may be starting)"
    fi
    
    echo ""
    echo "Quick commands:"
    echo "  Stop:    sudo systemctl stop pokerchaind  (or kill \$(pgrep pokerchaind))"
    echo "  Logs:    journalctl -u pokerchaind -f"
    echo "  Status:  curl http://localhost:$RPC_PORT/status"
    echo ""
    exit 0
fi


# Ensure priv_validator_state.json exists
if [ ! -f "$HOME_DIR/data/priv_validator_state.json" ]; then
    echo "Copying priv_validator_state_template.json to $HOME_DIR/data/priv_validator_state.json ..."
    mkdir -p "$HOME_DIR/data"
    cp "$(dirname "$0")/priv_validator_state_template.json" "$HOME_DIR/data/priv_validator_state.json"
fi

# Node is not running, let's start it
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Starting Pokerchaind Node${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if systemd service exists
if systemctl list-units --full -all 2>/dev/null | grep -q "pokerchaind.service"; then
    print_info "Starting via systemd service..."
    echo ""
    
    sudo systemctl start pokerchaind
    sleep 3
    
    if systemctl is-active --quiet pokerchaind; then
        print_success "Service started successfully!"
        echo ""
        sudo systemctl status pokerchaind --no-pager -l | head -20
        echo ""
        print_info "Waiting for RPC to be ready..."
        
        # Wait up to 30 seconds for RPC
        for i in {1..30}; do
            if curl -s --max-time 2 http://localhost:$RPC_PORT/status > /dev/null 2>&1; then
                echo ""
                print_success "RPC is now responding!"
                echo ""
                curl -s http://localhost:$RPC_PORT/status | jq -r '
                    "Node Information:",
                    "  Chain ID: " + .result.node_info.network,
                    "  Latest Block: " + .result.sync_info.latest_block_height,
                    "  Catching Up: " + (.result.sync_info.catching_up | tostring)
                ' 2>/dev/null || echo "RPC is responding at http://localhost:$RPC_PORT"
                break
            fi
            echo -n "."
            sleep 1
        done
        
        echo ""
        echo ""
        echo "✨ Node is running!"
        echo ""
        echo "Monitor with:"
        echo "  journalctl -u pokerchaind -f"
        echo ""
        echo "Check status:"
        echo "  curl http://localhost:$RPC_PORT/status | jq"
        echo ""
        echo "Stop with:"
        echo "  sudo systemctl stop pokerchaind"
        echo ""
    else
        print_error "Service failed to start"
        echo ""
        echo "Check logs for errors:"
        echo "  journalctl -u pokerchaind -n 100"
        exit 1
    fi
else
    # No systemd service - start manually
    print_info "No systemd service found - starting manually"
    echo ""
    print_warning "This will run in the foreground. Press Ctrl+C to stop."
    echo ""
    
    # Ask for confirmation
    read -p "Start pokerchaind manually? (y/n): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Starting pokerchaind..."
        echo "Press Ctrl+C to stop"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Start in foreground
        pokerchaind start --minimum-gas-prices="0.01stake"
    else
        echo "Cancelled."
        echo ""
        echo "To create a systemd service, run:"
        echo "  ./setup-sync-node.sh"
        echo "  OR"
        echo "  ./setup-network.sh → Option 2"
    fi
fi