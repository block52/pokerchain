#!/bin/bash

# run-tests.sh
# Main test runner for pokerchain functionality

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎲 Pokerchain Test Suite${NC}"
echo "======================="
echo ""

# Check if node is running
echo -e "${YELLOW}📡 Checking node status...${NC}"
if ! curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo -e "${RED}❌ Local node is not running on port 26657${NC}"
    echo -e "${YELLOW}💡 Please start the node first:${NC}"
    echo "   ./start-node.sh"
    exit 1
fi
echo -e "${GREEN}✅ Node is running${NC}"

# Show menu
show_menu() {
    echo ""
    echo -e "${BLUE}🎮 Available Tests:${NC}"
    echo "=================="
    echo "1. 💰 Mint tokens"
    echo "2. 🎲 Create game"
    echo "3. 🚪 Join game"
    echo "4. 🔍 Query games"
    echo "5. 📊 Full game workflow test"
    echo "6. 🔄 Reset and clean test"
    echo "0. 🚪 Exit"
    echo ""
}

# Full workflow test
run_full_workflow() {
    echo -e "${BLUE}🔄 Running full game workflow test...${NC}"
    echo "==================================="
    
    # Step 1: Mint tokens
    echo -e "${YELLOW}Step 1: Minting tokens...${NC}"
    ./test/mint-tokens-test.sh 1000000
    
    # Step 2: Create game
    echo ""
    echo -e "${YELLOW}Step 2: Creating game...${NC}"
    ./test/create-game-test.sh
    
    # Step 3: Query games
    echo ""
    echo -e "${YELLOW}Step 3: Querying games...${NC}"
    ./test/query-games-test.sh
    
    echo ""
    echo -e "${GREEN}🎉 Full workflow test completed!${NC}"
}

# Main loop
while true; do
    show_menu
    read -p "Choose an option (0-6): " choice
    
    case $choice in
        1)
            echo -e "${YELLOW}💰 Running mint tokens test...${NC}"
            read -p "Enter amount to mint (default: 1000000): " amount
            ./test/mint-tokens-test.sh ${amount:-1000000}
            ;;
        2)
            echo -e "${YELLOW}🎲 Running create game test...${NC}"
            ./test/create-game-test.sh
            ;;
        3)
            echo -e "${YELLOW}🚪 Running join game test...${NC}"
            read -p "Enter game ID: " game_id
            if [ -n "$game_id" ]; then
                ./test/join-game-test.sh $game_id
            else
                echo -e "${RED}❌ Game ID required${NC}"
            fi
            ;;
        4)
            echo -e "${YELLOW}🔍 Running query games test...${NC}"
            read -p "Enter specific game ID (optional): " game_id
            ./test/query-games-test.sh $game_id
            ;;
        5)
            run_full_workflow
            ;;
        6)
            echo -e "${YELLOW}🔄 Running reset and clean test...${NC}"
            echo -e "${RED}⚠️  This will remove all local blockchain data!${NC}"
            read -p "Are you sure? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                pkill pokerchaind 2>/dev/null || true
                rm -rf ~/.pokerchain/data/*
                echo -e "${GREEN}✅ Local data cleaned${NC}"
                echo -e "${YELLOW}💡 Restart node with: ./start-node.sh${NC}"
            else
                echo -e "${BLUE}ℹ️  Clean cancelled${NC}"
            fi
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option. Please choose 0-6.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done