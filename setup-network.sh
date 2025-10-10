#!/bin/bash

# Pokerchain Multi-Node Setup Guide
# This script helps you set up a two-node pokerchain network

set -e

echo "🔗 Pokerchain Multi-Node Setup Guide"
echo "===============        # Copy the config file with peer configuration
        echo "⚙️ Configuring node connection..."
        cp config.toml "$HOME/.pokerchain/config/"
        echo "✅ Config file copied"
        
        # Handle sync-only vs validator setup
        if [ "$SYNC_ONLY" = true ]; then
            echo "🔄 Configuring sync-only mode..."
            
            # Create minimal validator state file for sync-only node
            mkdir -p "$HOME/.pokerchain/data"
            echo '{"height":"0","round":0,"step":0}' > "$HOME/.pokerchain/data/priv_validator_state.json"
            chmod 600 "$HOME/.pokerchain/data/priv_validator_state.json"
            
            # Remove any validator key to ensure sync-only mode
            rm -f "$HOME/.pokerchain/config/priv_validator_key.json"
            
            echo "✅ Sync-only mode configured"
            echo "   - Node will connect to node1.block52.xyz"
            echo "   - Node will sync blockchain without creating blocks"
            echo "   - No validator keys configured - sync-only"
            
        else
            # Copy validator keys for validator nodes
            if [ "$USE_VALIDATOR_KEY" = true ]; then
                echo "🔑 Copying validator keys for $ACTOR_NAME..."
                if [ -f ".testnets/$VALIDATOR_ID/config/priv_validator_key.json" ] && [ -f ".testnets/$VALIDATOR_ID/data/priv_validator_state.json" ]; then
                    cp ".testnets/$VALIDATOR_ID/config/priv_validator_key.json" "$HOME/.pokerchain/config/"
                    cp ".testnets/$VALIDATOR_ID/data/priv_validator_state.json" "$HOME/.pokerchain/data/"
                    chmod 600 "$HOME/.pokerchain/config/priv_validator_key.json"
                    chmod 600 "$HOME/.pokerchain/data/priv_validator_state.json"
                    echo "✅ Validator keys copied for $ACTOR_NAME"
                else
                    echo "⚠️  Warning: Validator keys not found for $ACTOR_NAME"
                    echo "    The node will run as a non-validator"
                fi
            else
                echo "🔓 Running as non-validator"
                # Remove any existing validator keys to ensure non-validator mode
                rm -f "$HOME/.pokerchain/config/priv_validator_key.json"
                rm -f "$HOME/.pokerchain/data/priv_validator_state.json"
            fi
        fi==============="
echo ""

# Check if we're setting up the first or second node
echo "What are you setting up?"
echo "1) First node (node1.block52.xyz) - Full deployment"
echo "2) First node (node1.block52.xyz) - Manual setup"
echo "3) Second node (local/another server)"
echo ""
read -p "Choose option (1, 2, or 3): " NODE_TYPE

case $NODE_TYPE in
    1)
        echo ""
        echo "� Full deployment to node1.block52.xyz..."
        echo ""
        
        read -p "Enter username for node1.block52.xyz: " REMOTE_USER
        REMOTE_HOST="node1.block52.xyz"
        
        echo "Starting complete deployment..."
        ./deploy-node.sh "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_HOST"
        
        echo ""
        echo "✅ Full deployment complete!"
        echo "Your node is ready to start on $REMOTE_HOST"
        ;;
        
    2)
        echo ""
        echo "🖥️  Manual setup for node1.block52.xyz..."
        echo ""
        
        # For the first node (node1.block52.xyz)
        echo "Steps for node1.block52.xyz:"
        echo "1. Install Go 1.24.7+ and pokerchaind"
        echo "2. Copy genesis.json and app.toml to the server"
        echo "3. Run the second-node.sh script"
        echo ""
        
        read -p "Do you want to copy the scripts and genesis to node1.block52.xyz? (y/n): " COPY_FILES
        
        if [[ $COPY_FILES == "y" ]]; then
            read -p "Enter username for node1.block52.xyz: " REMOTE_USER
            REMOTE_HOST="node1.block52.xyz"
            
            echo "Copying files to $REMOTE_USER@$REMOTE_HOST..."
            
            # Copy necessary files
            scp genesis.json "$REMOTE_USER@$REMOTE_HOST:~/"
            scp app.toml "$REMOTE_USER@$REMOTE_HOST:~/"
            scp second-node.sh "$REMOTE_USER@$REMOTE_HOST:~/"
            scp install-from-source.sh "$REMOTE_USER@$REMOTE_HOST:~/"
            scp get-node-info.sh "$REMOTE_USER@$REMOTE_HOST:~/"
            
            echo ""
            echo "Files copied! Now SSH to node1.block52.xyz and run:"
            echo "chmod +x *.sh"
            echo "./install-from-source.sh"
            echo "./second-node.sh node1.block52.xyz"
            echo ""
            echo "After setup, get the peer ID with:"
            echo "./get-node-info.sh"
        fi
        ;;
        
    3)
        echo ""
        echo "💻 Setting up local/second node..."
        echo ""
        
        # Ask which actor to use
        echo "What type of local node would you like to setup?"
        echo "0) Sync-only node (recommended - syncs from node1.block52.xyz without creating blocks)"
        echo "1) Bob validator node"
        echo "2) Charlie validator node"  
        echo "3) Diana validator node"
        echo "4) Eve validator node"
        echo ""
        read -p "Choose option (0-4): " ACTOR_CHOICE
        
        case $ACTOR_CHOICE in
            0)
                ACTOR_NAME="sync-node"
                VALIDATOR_ID=""
                echo "✅ Selected sync-only mode (will sync from node1.block52.xyz without creating blocks)"
                USE_VALIDATOR_KEY=false
                SYNC_ONLY=true
                ;;
            1)
                ACTOR_NAME="bob"
                VALIDATOR_ID="validator1"
                echo "✅ Selected Bob"
                USE_VALIDATOR_KEY=true
                SYNC_ONLY=false
                ;;
            2)
                ACTOR_NAME="charlie"
                VALIDATOR_ID="validator2"
                echo "✅ Selected Charlie"
                USE_VALIDATOR_KEY=true
                SYNC_ONLY=false
                ;;
            3)
                ACTOR_NAME="diana"
                VALIDATOR_ID="validator3"
                echo "✅ Selected Diana"
                USE_VALIDATOR_KEY=true
                SYNC_ONLY=false
                ;;
            4)
                ACTOR_NAME="eve"
                VALIDATOR_ID="validator4"
                echo "✅ Selected Eve"
                USE_VALIDATOR_KEY=true
                SYNC_ONLY=false
                ;;
            *)
                echo "❌ Invalid choice. Defaulting to sync-only mode."
                ACTOR_NAME="sync-node"
                VALIDATOR_ID=""
                USE_VALIDATOR_KEY=false
                SYNC_ONLY=true
                ;;
        esac
        
        # For the second node (local)
        echo ""
        echo "Setting up local node ($ACTOR_NAME) to connect to node1.block52.xyz"
        echo ""
        
        # Check if pokerchaind is installed
        if ! command -v pokerchaind &> /dev/null; then
            echo "❌ pokerchaind not found. Building from source..."
            make install
            echo "✅ pokerchaind installed"
        else
            echo "✅ pokerchaind found"
        fi
        
        # For sync-only mode, completely reset the node
        if [ "$SYNC_ONLY" = true ]; then
            echo ""
            echo "🔄 Setting up sync-only node (will remove existing data)..."
            
            # Stop any running pokerchaind processes
            echo "🛑 Stopping any running pokerchaind processes..."
            pkill pokerchaind 2>/dev/null || true
            sleep 2
            
            # Remove existing node data completely
            echo "🗑️  Removing existing blockchain data..."
            rm -rf "$HOME/.pokerchain"
            echo "✅ Existing data removed"
            
            # Initialize fresh node
            echo "🔧 Initializing fresh sync node..."
            pokerchaind init "$ACTOR_NAME" --chain-id pokerchain
            echo "✅ Fresh node initialized"
            
        else
            # Initialize the node if not already done (for validator nodes)
            if [ ! -d "$HOME/.pokerchain" ]; then
                echo "🔧 Initializing local node..."
                pokerchaind init "$ACTOR_NAME-node" --chain-id pokerchain
                echo "✅ Node initialized"
            else
                echo "✅ Node already initialized"
            fi
        fi
        
        # Copy the genesis file
        echo "📋 Copying genesis file..."
        cp genesis.json "$HOME/.pokerchain/config/"
        echo "✅ Genesis file copied"
        
        # Copy the config file with peer configuration
        echo "� Configuring node connection..."
        cp config.toml "$HOME/.pokerchain/config/"
        echo "✅ Config file copied"
        
        # Copy validator keys if requested
        if [ "$USE_VALIDATOR_KEY" = true ]; then
            echo "🔑 Copying validator keys for $ACTOR_NAME..."
            if [ -f ".testnets/$VALIDATOR_ID/config/priv_validator_key.json" ] && [ -f ".testnets/$VALIDATOR_ID/data/priv_validator_state.json" ]; then
                cp ".testnets/$VALIDATOR_ID/config/priv_validator_key.json" "$HOME/.pokerchain/config/"
                cp ".testnets/$VALIDATOR_ID/data/priv_validator_state.json" "$HOME/.pokerchain/data/"
                chmod 600 "$HOME/.pokerchain/config/priv_validator_key.json"
                chmod 600 "$HOME/.pokerchain/data/priv_validator_state.json"
                echo "✅ Validator keys copied for $ACTOR_NAME"
            else
                echo "⚠️  Warning: Validator keys not found for $ACTOR_NAME"
                echo "    The node will run as a non-validator"
            fi
        else
            echo "🔓 Running as non-validator (Alice keys will not be copied to avoid conflicts)"
            # Remove any existing validator keys to ensure non-validator mode
            rm -f "$HOME/.pokerchain/config/priv_validator_key.json"
            rm -f "$HOME/.pokerchain/data/priv_validator_state.json"
        fi
        
        echo ""
        echo "🚀 Setup complete!"
        echo ""
        if [ "$SYNC_ONLY" = true ]; then
            echo "Your sync-only node is ready!"
            echo ""
            echo "To start syncing from node1.block52.xyz:"
            echo "pokerchaind start --minimum-gas-prices=\"0.01stake\""
            echo ""
            echo "The node will:"
            echo "• Connect to node1.block52.xyz"
            echo "• Download and sync the blockchain"
            echo "• Run in read-only mode (no block creation)"
            echo "• Provide API access on localhost:1317"
        else
            echo "To start your local node ($ACTOR_NAME):"
            echo "pokerchaind start --minimum-gas-prices=\"0.01stake\""
        fi
        echo ""
        echo "To check your node info:"
        echo "./get-node-info.sh"
        ;;
        
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac

echo ""
echo "📋 Next Steps Summary:"
echo "====================="
echo ""
echo "For a complete two-node setup:"
echo ""
echo "1. 🖥️  Node1 (node1.block52.xyz):"
echo "   - Install pokerchaind: ./install-from-source.sh"
echo "   - Setup node: ./second-node.sh node1.block52.xyz"
echo "   - Get peer info: ./get-node-info.sh"
echo "   - Start: pokerchaind start"
echo ""
echo "2. 💻 Node2 (local/other server):"
echo "   - Connect to network: ./connect-to-network.sh"
echo "   - Add peer ID from node1"
echo "   - Start: pokerchaind start"
echo ""
echo "3. 🔍 Verify connection:"
echo "   - Check status: curl http://localhost:26657/status"
echo "   - Check peers: curl http://localhost:26657/net_info"
echo ""
echo "🌐 Network ports:"
echo "   - P2P: 26656"
echo "   - RPC: 26657"
echo "   - API: 1317"
echo ""
echo "Make sure these ports are open in your firewall!"