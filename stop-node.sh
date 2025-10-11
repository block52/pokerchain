#!/bin/bash

# Quick Stop Script for Pokerchaind
# Gracefully stops your local pokerchaind node

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Stopping Pokerchaind Node${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if pokerchaind is running
if ! pgrep -x pokerchaind > /dev/null; then
    print_info "pokerchaind is not running"
    echo ""
    echo "Start it with:"
    echo "  ./start-node.sh"
    echo "  OR"
    echo "  sudo systemctl start pokerchaind"
    exit 0
fi

print_warning "pokerchaind is currently running"

# Check if running as systemd service
if systemctl is-active --quiet pokerchaind 2>/dev/null; then
    echo ""
    print_info "Stopping systemd service..."
    
    sudo systemctl stop pokerchaind
    
    # Wait a moment
    sleep 2
    
    # Verify it stopped
    if systemctl is-active --quiet pokerchaind 2>/dev/null; then
        print_error "Service is still running"
        echo ""
        echo "Try forcing stop:"
        echo "  sudo systemctl kill pokerchaind"
        exit 1
    else
        print_success "Service stopped successfully"
        
        # Also disable if user wants
        if systemctl is-enabled --quiet pokerchaind 2>/dev/null; then
            echo ""
            read -p "Disable auto-start on boot? (y/n): " disable
            if [[ $disable =~ ^[Yy]$ ]]; then
                sudo systemctl disable pokerchaind
                print_success "Auto-start disabled"
            fi
        fi
    fi
else
    # Running as standalone process
    echo ""
    print_info "Stopping standalone process..."
    
    # Get PID
    local pid=$(pgrep -x pokerchaind)
    echo "PID: $pid"
    
    # Try graceful shutdown first (SIGTERM)
    print_info "Sending SIGTERM (graceful shutdown)..."
    kill -TERM $pid 2>/dev/null || true
    
    # Wait up to 10 seconds for graceful shutdown
    for i in {1..10}; do
        if ! pgrep -x pokerchaind > /dev/null; then
            print_success "Process stopped gracefully"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    
    # If still running, force kill
    if pgrep -x pokerchaind > /dev/null; then
        print_warning "Graceful shutdown timeout, forcing stop..."
        kill -KILL $(pgrep -x pokerchaind) 2>/dev/null || true
        sleep 1
        
        if pgrep -x pokerchaind > /dev/null; then
            print_error "Failed to stop pokerchaind"
            echo ""
            echo "Processes still running:"
            ps aux | grep pokerchaind | grep -v grep
            exit 1
        else
            print_success "Process stopped (forced)"
        fi
    fi
fi

# Verify nothing is running
if pgrep -x pokerchaind > /dev/null; then
    print_error "pokerchaind is still running!"
    echo ""
    echo "Running processes:"
    ps aux | grep pokerchaind | grep -v grep
    exit 1
else
    echo ""
    print_success "All pokerchaind processes stopped"
fi

echo ""
echo "✨ Node stopped successfully!"
echo ""
echo "Start again with:"
echo "  ./start-node.sh"
echo "  OR"
echo "  sudo systemctl start pokerchaind"
echo ""