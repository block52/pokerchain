package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/cosmos/cosmos-sdk/crypto/hd"
	"github.com/cosmos/cosmos-sdk/crypto/keyring"
	cryptotypes "github.com/cosmos/cosmos-sdk/crypto/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/go-bip39"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

const (
	mnemonic      = "grow broom cigar crime caught name charge today comfort tourist ethics erode sleep merge bring relax swap clog whale rent unable vehicle thought buddy"
	chainID       = "pokerchain"
	grpcURL       = "node.texashodl.net:9443"
	addressPrefix = "b52"
)

func main() {
	// Check command line arguments
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	gameID := os.Args[1]

	// Set address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(addressPrefix, addressPrefix+"pub")
	config.Seal()

	// Derive private key from mnemonic
	_, addr, err := deriveKey(mnemonic)
	if err != nil {
		fmt.Printf("Error deriving key: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Using address: %s\n", addr.String())

	// Create gRPC connection with TLS
	creds := credentials.NewTLS(nil)
	grpcConn, err := grpc.Dial(
		grpcURL,
		grpc.WithTransportCredentials(creds),
	)
	if err != nil {
		fmt.Printf("Error connecting to gRPC: %v\n", err)
		os.Exit(1)
	}
	defer grpcConn.Close()

	fmt.Printf("\nQuerying legal actions for game: %s\n", gameID)
	fmt.Printf("Player: %s\n\n", addr.String())

	// Query legal actions
	queryClient := pokertypes.NewQueryClient(grpcConn)
	res, err := queryClient.LegalActions(context.Background(), &pokertypes.QueryLegalActionsRequest{
		GameId:        gameID,
		PlayerAddress: addr.String(),
	})
	if err != nil {
		fmt.Printf("Error querying legal actions: %v\n", err)
		os.Exit(1)
	}

	// Parse and pretty print the result
	var actions map[string]interface{}
	if err := json.Unmarshal([]byte(res.Actions), &actions); err != nil {
		fmt.Printf("Error parsing actions: %v\n", err)
		os.Exit(1)
	}

	prettyJSON, _ := json.MarshalIndent(actions, "", "  ")
	fmt.Println("Legal Actions:")
	fmt.Println(string(prettyJSON))
	fmt.Println()

	// Display formatted summary
	if isYourTurn, ok := actions["is_your_turn"].(bool); ok {
		if isYourTurn {
			fmt.Println("✅ It's your turn to act!")
		} else {
			fmt.Println("⏳ Waiting for other players...")
		}
	}

	if availableActions, ok := actions["available_actions"].([]interface{}); ok && len(availableActions) > 0 {
		fmt.Println("\nAvailable actions:")
		for _, action := range availableActions {
			fmt.Printf("  • %v\n", action)
		}
	}

	if currentBet, ok := actions["current_bet"].(float64); ok && currentBet > 0 {
		betUSDC := currentBet / 1_000_000
		fmt.Printf("\nCurrent bet: %.6f USDC\n", betUSDC)
	}

	if minRaise, ok := actions["min_raise"].(float64); ok && minRaise > 0 {
		raiseUSDC := minRaise / 1_000_000
		fmt.Printf("Min raise: %.6f USDC\n", raiseUSDC)
	}

	if maxRaise, ok := actions["max_raise"].(float64); ok {
		maxUSDC := maxRaise / 1_000_000
		fmt.Printf("Max raise: %.6f USDC\n", maxUSDC)
	}
}

func printUsage() {
	fmt.Println("Usage: get-legal-actions <game_id>")
	fmt.Println("")
	fmt.Println("Example:")
	fmt.Println("  get-legal-actions 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1")
	fmt.Println("")
	fmt.Println("Arguments:")
	fmt.Println("  game_id - The game/table ID (hex string starting with 0x)")
}

func deriveKey(mnemonic string) (cryptotypes.PrivKey, sdk.AccAddress, error) {
	// Validate mnemonic
	if !bip39.IsMnemonicValid(mnemonic) {
		return nil, nil, fmt.Errorf("invalid mnemonic")
	}

	// Derive private key using BIP44 path: m/44'/118'/0'/0/0
	algo := hd.Secp256k1
	derivedPriv, err := algo.Derive()(mnemonic, keyring.DefaultBIP39Passphrase, sdk.GetConfig().GetFullBIP44Path())
	if err != nil {
		return nil, nil, err
	}

	privKey := algo.Generate()(derivedPriv)
	addr := sdk.AccAddress(privKey.PubKey().Address())

	return privKey, addr, nil
}

