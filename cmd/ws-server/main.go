package main

import (
	"log"

	sdk "github.com/cosmos/cosmos-sdk/types"

	"github.com/block52/pokerchain/pkg/wsserver"
)

func main() {
	// Load configuration from environment variables
	cfg := wsserver.ConfigFromEnv()

	// Set Cosmos SDK address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(cfg.AddressPrefix, cfg.AddressPrefix+"pub")
	config.Seal()

	// Start the WebSocket server (blocks)
	log.Println("Starting Poker WebSocket Server...")
	if err := wsserver.Start(cfg); err != nil {
		log.Fatalf("WebSocket server error: %v", err)
	}
}
