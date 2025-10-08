#!/bin/bash

# Pokerchain Multi-Node Setup Guide
# This script helps you set up a two-node pokerchain network

set -e

echo "🔗 Pokerchain Multi-Node Setup Guide"
echo "===================================="
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
        
        # For the second node (local)
        echo "Setting up local node to connect to node1.block52.xyz"
        echo ""
        
        # Check if pokerchaind is installed
        if ! command -v pokerchaind &> /dev/null; then
            echo "❌ pokerchaind not found. Building from source..."
            make install
            echo "✅ pokerchaind installed"
        else
            echo "✅ pokerchaind found"
        fi
        
        # Run the connection script
        echo ""
        echo "🔗 Configuring connection to network..."
        ./connect-to-network.sh
        
        echo ""
        echo "🚀 Setup complete!"
        echo ""
        echo "To start your local node:"
        echo "pokerchaind start"
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