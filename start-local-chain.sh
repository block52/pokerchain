#!/bin/bash

# Start Local Pokerchain with Bridge Configuration
# Wrapper around "ignite chain serve" that ensures .env is loaded

set -e

# Color codes
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
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}         🎲 Starting Local Pokerchain${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if .env exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_error ".env file not found!"
    echo ""
    echo "Bridge service requires .env file with Alchemy API key."
    echo ""
    echo "To set up:"
    echo "  1. cp .env.example .env"
    echo "  2. Edit .env and add your Alchemy API key"
    echo "  3. Get API key from: https://dashboard.alchemy.com/"
    echo ""
    read -p "Continue without bridge? (y/n): " continue_without
    if [[ ! $continue_without =~ ^[Yy]$ ]]; then
        exit 1
    fi
    print_warning "Starting WITHOUT bridge configuration"
    echo ""
else
    source "$SCRIPT_DIR/.env"
    if [ -z "$ALCHEMY_URL" ]; then
        print_warning "ALCHEMY_URL not set in .env"
        print_info "Bridge service may not work correctly"
    else
        print_success ".env loaded successfully"
        print_info "Alchemy URL configured"
    fi
    echo ""
fi

# Function to update bridge config after chain initializes
update_bridge_after_init() {
    # Wait a bit for chain to initialize
    sleep 5

    if [ -f "$HOME/.pokerchain/config/app.toml" ] && [ -f "$SCRIPT_DIR/update-bridge-config.sh" ]; then
        print_info "Updating bridge configuration from .env..."
        "$SCRIPT_DIR/update-bridge-config.sh" 2>&1 | grep -E "(✅|❌|⚠️)" || true
    fi
}

# Check if chain is already initialized
if [ -d "$HOME/.pokerchain" ]; then
    print_info "Chain already initialized"

    # Update bridge config before starting
    if [ -f "$SCRIPT_DIR/update-bridge-config.sh" ] && [ -f "$SCRIPT_DIR/.env" ]; then
        print_info "Updating bridge configuration..."
        "$SCRIPT_DIR/update-bridge-config.sh" 2>&1 | grep -E "(✅|❌|⚠️)" || true
        echo ""
    fi
else
    print_info "Chain will be initialized by ignite"

    # Schedule bridge config update after init
    if [ -f "$SCRIPT_DIR/.env" ]; then
        print_info "Will update bridge config after initialization"
        (update_bridge_after_init &)
    fi
    echo ""
fi

# Parse command line arguments
IGNITE_ARGS=""
RESET_FLAG=""

for arg in "$@"; do
    case $arg in
        --reset-once)
            RESET_FLAG="--reset-once"
            print_warning "Will reset chain state (--reset-once)"
            ;;
        --verbose|-v)
            IGNITE_ARGS="$IGNITE_ARGS --verbose"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --reset-once    Reset chain state on this run"
            echo "  --verbose, -v   Enable verbose output"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Start normally"
            echo "  $0 --reset-once       # Reset and start fresh"
            echo "  $0 --verbose          # Start with verbose logging"
            echo ""
            exit 0
            ;;
        *)
            IGNITE_ARGS="$IGNITE_ARGS $arg"
            ;;
    esac
done

print_info "Starting chain with: ignite chain serve $RESET_FLAG $IGNITE_ARGS"
echo ""
echo -e "${BLUE}Press Ctrl+C to stop${NC}"
echo ""

# Start ignite chain serve
ignite chain serve $RESET_FLAG $IGNITE_ARGS
