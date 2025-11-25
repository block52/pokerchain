package main

import (
	"bufio"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/tx"
	"github.com/cosmos/cosmos-sdk/crypto/hd"
	"github.com/cosmos/cosmos-sdk/crypto/keyring"
	cryptotypes "github.com/cosmos/cosmos-sdk/crypto/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	txtypes "github.com/cosmos/cosmos-sdk/types/tx"
	"github.com/cosmos/cosmos-sdk/types/tx/signing"
	authsigning "github.com/cosmos/cosmos-sdk/x/auth/signing"
	authtx "github.com/cosmos/cosmos-sdk/x/auth/tx"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	banktypes "github.com/cosmos/cosmos-sdk/x/bank/types"
	"github.com/cosmos/go-bip39"
	"github.com/ethereum/go-ethereum/crypto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"cosmossdk.io/math"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/std"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

const (
	chainID       = "pokerchain"
	grpcURL       = "node.texashodl.net:9443"
	addressPrefix = "b52"
)

type EncodingConfig struct {
	InterfaceRegistry codectypes.InterfaceRegistry
	Codec             codec.Codec
	TxConfig          client.TxConfig
	Amino             *codec.LegacyAmino
}

type PokerCLI struct {
	mnemonic       string
	privKey        cryptotypes.PrivKey
	address        sdk.AccAddress
	grpcConn       *grpc.ClientConn
	clientCtx      client.Context
	encodingConfig EncodingConfig
	reader         *bufio.Reader
}

func main() {
	// Set address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(addressPrefix, addressPrefix+"pub")
	config.Seal()

	cli := &PokerCLI{
		reader: bufio.NewReader(os.Stdin),
	}

	cli.encodingConfig = makeEncodingConfig()

	fmt.Println("╔══════════════════════════════════════════════════════════════════╗")
	fmt.Println("║              🎲 Poker CLI - Blockchain Poker Client 🎲          ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// Main menu loop
	for {
		if cli.mnemonic == "" {
			cli.showWelcomeMenu()
		} else {
			cli.showMainMenu()
		}
	}
}

func (cli *PokerCLI) showWelcomeMenu() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Welcome! Please import your seed phrase to continue.")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()
	fmt.Println("1) Import seed phrase")
	fmt.Println("2) Exit")
	fmt.Println()
	fmt.Print("Select option: ")

	choice := cli.readLine()
	fmt.Println()

	switch choice {
	case "1":
		cli.importSeedPhrase()
	case "2":
		fmt.Println("Goodbye! 👋")
		os.Exit(0)
	default:
		fmt.Println("Invalid option. Please try again.\n")
	}
}

func (cli *PokerCLI) showMainMenu() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Address: %s\n", cli.address.String())
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()
	fmt.Println("1) Check balance")
	fmt.Println("2) Create new table")
	fmt.Println("3) Join existing table")
	fmt.Println("4) Perform poker action")
	fmt.Println("5) Query game state")
	fmt.Println("6) Get legal actions")
	fmt.Println("7) Leave game")
	fmt.Println("8) Change seed phrase")
	fmt.Println("9) Exit")
	fmt.Println()
	fmt.Print("Select option: ")

	choice := cli.readLine()
	fmt.Println()

	switch choice {
	case "1":
		cli.checkBalance()
	case "2":
		cli.createTable()
	case "3":
		cli.joinTable()
	case "4":
		cli.performAction()
	case "5":
		cli.queryGameState()
	case "6":
		cli.getLegalActions()
	case "7":
		cli.leaveGame()
	case "8":
		cli.mnemonic = ""
		cli.privKey = nil
		cli.address = nil
		if cli.grpcConn != nil {
			cli.grpcConn.Close()
			cli.grpcConn = nil
		}
		fmt.Println("✓ Seed phrase cleared.\n")
	case "9":
		fmt.Println("Goodbye! 👋")
		os.Exit(0)
	default:
		fmt.Println("Invalid option. Please try again.\n")
	}
}

func (cli *PokerCLI) importSeedPhrase() {
	fmt.Println("Enter your 24-word seed phrase:")
	fmt.Print("> ")

	mnemonic := cli.readLine()

	if !bip39.IsMnemonicValid(mnemonic) {
		fmt.Println("❌ Invalid seed phrase. Please try again.\n")
		return
	}

	// Derive private key
	algo := hd.Secp256k1
	derivedPriv, err := algo.Derive()(mnemonic, keyring.DefaultBIP39Passphrase, sdk.GetConfig().GetFullBIP44Path())
	if err != nil {
		fmt.Printf("❌ Error deriving key: %v\n\n", err)
		return
	}

	privKey := algo.Generate()(derivedPriv)
	address := sdk.AccAddress(privKey.PubKey().Address())

	cli.mnemonic = mnemonic
	cli.privKey = privKey
	cli.address = address

	// Connect to gRPC
	if err := cli.connectGRPC(); err != nil {
		fmt.Printf("❌ Error connecting to blockchain: %v\n\n", err)
		cli.mnemonic = ""
		cli.privKey = nil
		cli.address = nil
		return
	}

	fmt.Println()
	fmt.Println("✅ Seed phrase imported successfully!")
	fmt.Printf("Your address: %s\n\n", address.String())
}

func (cli *PokerCLI) connectGRPC() error {
	creds := credentials.NewTLS(nil)
	grpcConn, err := grpc.Dial(grpcURL, grpc.WithTransportCredentials(creds))
	if err != nil {
		return err
	}

	cli.grpcConn = grpcConn
	cli.clientCtx = client.Context{}.
		WithCodec(cli.encodingConfig.Codec).
		WithInterfaceRegistry(cli.encodingConfig.InterfaceRegistry).
		WithTxConfig(cli.encodingConfig.TxConfig).
		WithLegacyAmino(cli.encodingConfig.Amino).
		WithChainID(chainID).
		WithGRPCClient(grpcConn).
		WithAccountRetriever(authtypes.AccountRetriever{})

	return nil
}

func (cli *PokerCLI) checkBalance() {
	fmt.Println("Checking balance...")
	fmt.Println()

	bankClient := banktypes.NewQueryClient(cli.grpcConn)
	res, err := bankClient.AllBalances(context.Background(), &banktypes.QueryAllBalancesRequest{
		Address: cli.address.String(),
	})
	if err != nil {
		fmt.Printf("❌ Error querying balance: %v\n\n", err)
		return
	}

	if len(res.Balances) == 0 {
		fmt.Println("No balances found (account may not be funded yet)")
	} else {
		fmt.Println("Balances:")
		for _, coin := range res.Balances {
			amount := coin.Amount.String()
			denom := coin.Denom

			// Format USDC nicely
			if denom == "uusdc" {
				intVal := coin.Amount.BigInt().Uint64()
				usdc := float64(intVal) / 1_000_000
				fmt.Printf("  %.6f USDC (%s %s)\n", usdc, amount, denom)
				continue
			}

			fmt.Printf("  %s %s\n", amount, denom)
		}
	}

	fmt.Println()
	cli.pressEnterToContinue()
}

func (cli *PokerCLI) createTable() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Create New Table")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	minBuyIn := cli.readUint64("Min buy-in (uusdc, e.g., 100000000 = 100 USDC): ")
	maxBuyIn := cli.readUint64("Max buy-in (uusdc, e.g., 1000000000 = 1000 USDC): ")
	minPlayers := cli.readInt64("Min players (e.g., 2): ")
	maxPlayers := cli.readInt64("Max players (e.g., 9): ")
	smallBlind := cli.readUint64("Small blind (uusdc, e.g., 500000 = 0.5 USDC): ")
	bigBlind := cli.readUint64("Big blind (uusdc, e.g., 1000000 = 1 USDC): ")
	timeout := cli.readInt64("Timeout (seconds, e.g., 60): ")

	fmt.Print("Game type (nlhe): ")
	gameType := cli.readLine()
	if gameType == "" {
		gameType = "nlhe"
	}

	fmt.Println()

	msg := &pokertypes.MsgCreateGame{
		Creator:    cli.address.String(),
		MinBuyIn:   minBuyIn,
		MaxBuyIn:   maxBuyIn,
		MinPlayers: minPlayers,
		MaxPlayers: maxPlayers,
		SmallBlind: smallBlind,
		BigBlind:   bigBlind,
		Timeout:    timeout,
		GameType:   gameType,
	}

	txHash, err := cli.broadcastTx(msg)
	if err != nil {
		fmt.Printf("❌ Transaction failed: %v\n\n", err)
		return
	}

	fmt.Println("✅ Table created successfully!")
	fmt.Printf("Transaction hash: %s\n\n", txHash)
	cli.pressEnterToContinue()
}

func (cli *PokerCLI) joinTable() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Join Table")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	fmt.Print("Game ID (0x...): ")
	gameID := cli.readLine()

	seat := cli.readUint64("Seat number (1-9): ")
	if seat < 1 || seat > 9 {
		fmt.Println("❌ Invalid seat number. Must be between 1 and 9.\n")
		return
	}
	buyIn := cli.readUint64("Buy-in amount (uusdc, e.g., 500000000 = 500 USDC): ")

	fmt.Println()

	msg := &pokertypes.MsgJoinGame{
		Player:      cli.address.String(),
		GameId:      gameID,
		Seat:        seat,
		BuyInAmount: buyIn,
	}

	txHash, err := cli.broadcastTx(msg)
	if err != nil {
		fmt.Printf("❌ Transaction failed: %v\n\n", err)
		return
	}

	fmt.Println("✅ Joined table successfully!")
	fmt.Printf("Transaction hash: %s\n\n", txHash)
	cli.pressEnterToContinue()
}

func (cli *PokerCLI) performAction() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Perform Action")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	fmt.Print("Game ID (0x...): ")
	gameID := cli.readLine()

	fmt.Println()
	fmt.Println("Actions: fold, call, check, bet, raise")
	fmt.Print("Action: ")
	action := strings.ToLower(cli.readLine())

	var amount uint64 = 0
	if action == "bet" || action == "raise" {
		amount = cli.readUint64("Amount (uusdc): ")
	}

	fmt.Println()

	msg := &pokertypes.MsgPerformAction{
		Player: cli.address.String(),
		GameId: gameID,
		Action: action,
		Amount: amount,
	}

	txHash, err := cli.broadcastTx(msg)
	if err != nil {
		fmt.Printf("❌ Transaction failed: %v\n\n", err)
		return
	}

	fmt.Printf("✅ Action '%s' performed successfully!\n", action)
	fmt.Printf("Transaction hash: %s\n\n", txHash)
	cli.pressEnterToContinue()
}

func (cli *PokerCLI) queryGameState() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Query Game State")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	fmt.Print("Game ID (0x...): ")
	gameID := cli.readLine()

	fmt.Println()

	queryClient := pokertypes.NewQueryClient(cli.grpcConn)

	var game map[string]interface{}
	authenticated := false

	// Try authenticated query first (to see your own cards)
	fmt.Println("Querying game state (with signature authentication)...")
	timestamp := time.Now().Unix()
	signature, signErr := cli.signQueryMessage(timestamp)
	if signErr == nil {
		res, err := queryClient.GameState(context.Background(), &pokertypes.QueryGameStateRequest{
			GameId:        gameID,
			PlayerAddress: cli.address.String(),
			Timestamp:     timestamp,
			Signature:     signature,
		})
		if err == nil {
			if parseErr := json.Unmarshal([]byte(res.GameState), &game); parseErr == nil {
				authenticated = true
				fmt.Println("✓ Authenticated query successful (showing your cards)")
			}
		} else {
			fmt.Printf("⚠ Authenticated query failed: %v\n", err)
		}
	}

	// Fall back to public query if authenticated failed
	if !authenticated {
		fmt.Println("Falling back to public query (all cards hidden)...")
		res, err := queryClient.Game(context.Background(), &pokertypes.QueryGameRequest{
			GameId: gameID,
		})
		if err != nil {
			fmt.Printf("❌ Error querying game: %v\n\n", err)
			cli.pressEnterToContinue()
			return
		}
		if parseErr := json.Unmarshal([]byte(res.Game), &game); parseErr != nil {
			fmt.Printf("❌ Error parsing game data: %v\n\n", parseErr)
			cli.pressEnterToContinue()
			return
		}

		// For public query, check if gameState is nested
		if gs, ok := game["gameState"].(map[string]interface{}); ok {
			// Merge gameState into root level for consistent display
			for k, v := range gs {
				if _, exists := game[k]; !exists {
					game[k] = v
				}
			}
		}
	}

	fmt.Println()

	// Display formatted game state
	fmt.Println("╔══════════════════════════════════════════════════════════════════╗")
	fmt.Println("║                         GAME STATE                               ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// Helper to get values from game map
	getString := func(key string) string {
		if val, ok := game[key].(string); ok {
			return val
		}
		return ""
	}
	getFloat := func(key string) float64 {
		if val, ok := game[key].(float64); ok {
			return val
		}
		return 0
	}

	// Extract game options (nested in gameOptions for TexasHoldemStateDTO)
	var gameOptions map[string]interface{}
	if opts, ok := game["gameOptions"].(map[string]interface{}); ok {
		gameOptions = opts
	}

	getOptionFloat := func(key string) float64 {
		if gameOptions != nil {
			if val, ok := gameOptions[key].(float64); ok {
				return val
			}
			// Also try string (some values come as strings)
			if val, ok := gameOptions[key].(string); ok {
				if f, err := strconv.ParseFloat(val, 64); err == nil {
					return f
				}
			}
		}
		return 0
	}

	// Game Info
	fmt.Println("┌─ Game Information ────────────────────────────────────────────────┐")
	gameAddr := getString("address")
	if len(gameAddr) > 20 {
		gameAddr = gameAddr[:20] + "..."
	}
	fmt.Printf("│ Game Address:  %s\n", gameAddr)
	fmt.Printf("│ Type:          %v\n", game["type"])
	fmt.Printf("│ Round:         %s\n", getString("round"))
	fmt.Printf("│ Hand #:        %.0f\n", getFloat("handNumber"))

	// Game options
	minBuyIn := getOptionFloat("minBuyIn")
	maxBuyIn := getOptionFloat("maxBuyIn")
	smallBlind := getOptionFloat("smallBlind")
	bigBlind := getOptionFloat("bigBlind")
	if minBuyIn > 0 || maxBuyIn > 0 {
		fmt.Printf("│ Min/Max Buy:   %.0f / %.0f uusdc\n", minBuyIn, maxBuyIn)
	}
	if smallBlind > 0 || bigBlind > 0 {
		fmt.Printf("│ Blinds:        %.0f / %.0f uusdc (SB/BB)\n", smallBlind, bigBlind)
	}

	players := []interface{}{}
	if p, ok := game["players"].([]interface{}); ok {
		players = p
	}
	maxPlayers := getOptionFloat("maxPlayers")
	minPlayers := getOptionFloat("minPlayers")
	fmt.Printf("│ Players:       %d", len(players))
	if maxPlayers > 0 {
		fmt.Printf(" / %.0f (min: %.0f)", maxPlayers, minPlayers)
	}
	fmt.Println()
	fmt.Println("└───────────────────────────────────────────────────────────────────┘")
	fmt.Println()

	// Players Table
	if len(players) > 0 {
		fmt.Println("┌─ Players ─────────────────────────────────────────────────────────┐")
		fmt.Println("│ Seat │ Address                │ Stack         │ Status    │ Cards │")
		fmt.Println("├──────┼────────────────────────┼───────────────┼───────────┼───────┤")

		for _, p := range players {
			player, ok := p.(map[string]interface{})
			if !ok {
				continue
			}

			addr := ""
			if a, ok := player["address"].(string); ok {
				addr = a
				if len(addr) > 20 {
					addr = addr[:8] + "..." + addr[len(addr)-8:]
				}
			}

			seat := float64(0)
			if s, ok := player["seat"].(float64); ok {
				seat = s
			}

			// Stack can be string or float in TexasHoldemStateDTO
			stack := float64(0)
			if s, ok := player["stack"].(string); ok {
				stack, _ = strconv.ParseFloat(s, 64)
			} else if s, ok := player["stack"].(float64); ok {
				stack = s
			}
			stackUSDC := stack / 1_000_000

			status := ""
			if st, ok := player["status"].(string); ok {
				status = st
			}

			// Hole cards (only visible for current player, others show "X")
			cards := ""
			if hc, ok := player["holeCards"].([]interface{}); ok && len(hc) > 0 {
				cardStrs := []string{}
				for _, c := range hc {
					if cs, ok := c.(string); ok {
						cardStrs = append(cardStrs, cs)
					}
				}
				cards = strings.Join(cardStrs, " ")
			}

			fmt.Printf("│ %-4.0f │ %-22s │ %8.2f USDC │ %-9s │ %-5s │\n",
				seat, addr, stackUSDC, status, cards)
		}
		fmt.Println("└───────────────────────────────────────────────────────────────────┘")
		fmt.Println()
	}

	// Current Hand Info
	fmt.Println("┌─ Current Hand ────────────────────────────────────────────────────┐")

	// Community cards
	communityCards := []interface{}{}
	if cc, ok := game["communityCards"].([]interface{}); ok {
		communityCards = cc
	}
	if len(communityCards) > 0 {
		cardStrs := []string{}
		for _, c := range communityCards {
			if cs, ok := c.(string); ok {
				cardStrs = append(cardStrs, cs)
			}
		}
		fmt.Printf("│ Community:     %s\n", strings.Join(cardStrs, " "))
	} else {
		fmt.Println("│ Community:     (no cards dealt yet)")
	}

	// Pot
	pots := []interface{}{}
	if p, ok := game["pots"].([]interface{}); ok {
		pots = p
	}
	if len(pots) > 0 {
		totalPot := float64(0)
		for _, pot := range pots {
			if potStr, ok := pot.(string); ok {
				if potVal, err := strconv.ParseFloat(potStr, 64); err == nil {
					totalPot += potVal
				}
			}
		}
		potUSDC := totalPot / 1_000_000
		fmt.Printf("│ Pot:           %.2f USDC\n", potUSDC)
	} else {
		fmt.Println("│ Pot:           0.00 USDC")
	}

	// Next to act
	nextToAct := getFloat("nextToAct")
	if nextToAct >= 0 {
		fmt.Printf("│ Next to Act:   Seat %.0f\n", nextToAct)
	}

	// Action count
	actionCount := getFloat("actionCount")
	fmt.Printf("│ Action Count:  %.0f\n", actionCount)

	fmt.Println("└───────────────────────────────────────────────────────────────────┘")
	fmt.Println()

	// Ask if they want to see raw JSON
	fmt.Print("Show raw JSON? (y/n): ")
	if strings.ToLower(cli.readLine()) == "y" {
		fmt.Println()
		gameJSON, _ := json.MarshalIndent(game, "", "  ")
		fmt.Println("Raw JSON:")
		fmt.Println("─────────────────────────────────────────────────────────────────────")
		fmt.Println(string(gameJSON))
		fmt.Println("─────────────────────────────────────────────────────────────────────")
		fmt.Println()
	} else {
		fmt.Println()
	}

	cli.pressEnterToContinue()
}

func (cli *PokerCLI) getLegalActions() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Get Legal Actions")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	fmt.Print("Game ID (0x...): ")
	gameID := cli.readLine()

	fmt.Println()
	fmt.Println("Querying legal actions...")
	fmt.Println()

	// Query legal actions
	queryClient := pokertypes.NewQueryClient(cli.grpcConn)
	res, err := queryClient.LegalActions(context.Background(), &pokertypes.QueryLegalActionsRequest{
		GameId:        gameID,
		PlayerAddress: cli.address.String(),
	})
	if err != nil {
		fmt.Printf("❌ Error querying legal actions: %v\n\n", err)
		cli.pressEnterToContinue()
		return
	}

	// Parse the actions JSON string - it's an array of LegalActionDTO
	var actions []map[string]interface{}
	if err := json.Unmarshal([]byte(res.Actions), &actions); err != nil {
		fmt.Printf("❌ Error parsing actions data: %v\n\n", err)
		cli.pressEnterToContinue()
		return
	}

	// Display legal actions
	fmt.Println("┌─ Legal Actions ───────────────────────────────────────────────────┐")

	if len(actions) == 0 {
		fmt.Println("│ No legal actions available (not your turn or not in game)       │")
	} else {
		fmt.Println("│ ✓ You have legal actions available                              │")
		fmt.Println("│                                                                   │")
		fmt.Println("│ Available actions:                                                │")

		for _, action := range actions {
			actionType := ""
			if a, ok := action["action"].(string); ok {
				actionType = a
			}

			// Format action with min/max if present
			actionStr := actionType
			if min, ok := action["min"].(string); ok && min != "" {
				if max, ok := action["max"].(string); ok && max != "" {
					// Convert to USDC for display
					minVal, _ := strconv.ParseFloat(min, 64)
					maxVal, _ := strconv.ParseFloat(max, 64)
					actionStr = fmt.Sprintf("%s (min: %.2f, max: %.2f USDC)", actionType, minVal/1_000_000, maxVal/1_000_000)
				} else {
					minVal, _ := strconv.ParseFloat(min, 64)
					actionStr = fmt.Sprintf("%s (min: %.2f USDC)", actionType, minVal/1_000_000)
				}
			}

			fmt.Printf("│   • %-60s│\n", actionStr)
		}
	}

	fmt.Println("└───────────────────────────────────────────────────────────────────┘")
	fmt.Println()

	// Ask if they want to see raw JSON
	fmt.Print("Show raw JSON? (y/n): ")
	if strings.ToLower(cli.readLine()) == "y" {
		fmt.Println()
		actionsJSON, _ := json.MarshalIndent(actions, "", "  ")
		fmt.Println("Raw JSON:")
		fmt.Println("─────────────────────────────────────────────────────────────────────")
		fmt.Println(string(actionsJSON))
		fmt.Println("─────────────────────────────────────────────────────────────────────")
		fmt.Println()
	} else {
		fmt.Println()
	}

	cli.pressEnterToContinue()
}

func (cli *PokerCLI) leaveGame() {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Leave Game")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	fmt.Print("Game ID (0x...): ")
	gameID := cli.readLine()

	fmt.Println()

	msg := &pokertypes.MsgLeaveGame{
		Creator: cli.address.String(),
		GameId:  gameID,
	}

	txHash, err := cli.broadcastTx(msg)
	if err != nil {
		fmt.Printf("❌ Transaction failed: %v\n\n", err)
		cli.pressEnterToContinue()
		return
	}

	fmt.Println("✅ Left game successfully!")
	fmt.Printf("Transaction hash: %s\n\n", txHash)
	cli.pressEnterToContinue()
}

func (cli *PokerCLI) broadcastTx(msg sdk.Msg) (string, error) {
	// Get account info
	account, err := cli.clientCtx.AccountRetriever.GetAccount(cli.clientCtx, cli.address)
	if err != nil {
		return "", fmt.Errorf("error getting account: %w", err)
	}

	// Build transaction
	txBuilder := cli.clientCtx.TxConfig.NewTxBuilder()
	if err := txBuilder.SetMsgs(msg); err != nil {
		return "", fmt.Errorf("error setting messages: %w", err)
	}

	// Set gas and fees
	txBuilder.SetGasLimit(300_000)
	txBuilder.SetFeeAmount(sdk.NewCoins(sdk.NewCoin("stake", math.NewInt(300))))

	// Sign the transaction
	sigV2 := signing.SignatureV2{
		PubKey: cli.privKey.PubKey(),
		Data: &signing.SingleSignatureData{
			SignMode:  signing.SignMode_SIGN_MODE_DIRECT,
			Signature: nil,
		},
		Sequence: account.GetSequence(),
	}

	if err := txBuilder.SetSignatures(sigV2); err != nil {
		return "", fmt.Errorf("error setting signatures: %w", err)
	}

	signerData := authsigning.SignerData{
		ChainID:       chainID,
		AccountNumber: account.GetAccountNumber(),
		Sequence:      account.GetSequence(),
	}

	ctx := context.Background()
	sigV2, err = tx.SignWithPrivKey(
		ctx,
		signing.SignMode_SIGN_MODE_DIRECT,
		signerData,
		txBuilder,
		cli.privKey,
		cli.clientCtx.TxConfig,
		account.GetSequence(),
	)
	if err != nil {
		return "", fmt.Errorf("error signing transaction: %w", err)
	}

	if err := txBuilder.SetSignatures(sigV2); err != nil {
		return "", fmt.Errorf("error setting final signatures: %w", err)
	}

	// Encode transaction
	txBytes, err := cli.clientCtx.TxConfig.TxEncoder()(txBuilder.GetTx())
	if err != nil {
		return "", fmt.Errorf("error encoding transaction: %w", err)
	}

	// Broadcast transaction
	fmt.Println("Broadcasting transaction...")

	txClient := txtypes.NewServiceClient(cli.grpcConn)
	grpcRes, err := txClient.BroadcastTx(
		context.Background(),
		&txtypes.BroadcastTxRequest{
			Mode:    txtypes.BroadcastMode_BROADCAST_MODE_SYNC,
			TxBytes: txBytes,
		},
	)
	if err != nil {
		return "", fmt.Errorf("error broadcasting: %w", err)
	}

	res := grpcRes.TxResponse
	if res.Code != 0 {
		return "", fmt.Errorf("transaction failed with code %d: %s", res.Code, res.RawLog)
	}

	return res.TxHash, nil
}

func (cli *PokerCLI) readLine() string {
	line, _ := cli.reader.ReadString('\n')
	return strings.TrimSpace(line)
}

func (cli *PokerCLI) readUint64(prompt string) uint64 {
	for {
		fmt.Print(prompt)
		input := cli.readLine()
		val, err := strconv.ParseUint(input, 10, 64)
		if err != nil {
			fmt.Println("Invalid number. Please try again.")
			continue
		}
		return val
	}
}

func (cli *PokerCLI) readInt64(prompt string) int64 {
	for {
		fmt.Print(prompt)
		input := cli.readLine()
		val, err := strconv.ParseInt(input, 10, 64)
		if err != nil {
			fmt.Println("Invalid number. Please try again.")
			continue
		}
		return val
	}
}

func (cli *PokerCLI) pressEnterToContinue() {
	fmt.Print("Press Enter to continue...")
	cli.reader.ReadString('\n')
	fmt.Println()
}

func makeEncodingConfig() EncodingConfig {
	amino := codec.NewLegacyAmino()
	interfaceRegistry := codectypes.NewInterfaceRegistry()
	cdc := codec.NewProtoCodec(interfaceRegistry)
	txCfg := authtx.NewTxConfig(cdc, authtx.DefaultSignModes)

	std.RegisterLegacyAminoCodec(amino)
	std.RegisterInterfaces(interfaceRegistry)
	authtypes.RegisterInterfaces(interfaceRegistry)
	pokertypes.RegisterInterfaces(interfaceRegistry)

	return EncodingConfig{
		InterfaceRegistry: interfaceRegistry,
		Codec:             cdc,
		TxConfig:          txCfg,
		Amino:             amino,
	}
}

// signQueryMessage signs a message for authenticated queries using Ethereum personal_sign format
func (cli *PokerCLI) signQueryMessage(timestamp int64) (string, error) {
	// Create the message: "pokerchain-query:<timestamp>"
	message := fmt.Sprintf("pokerchain-query:%d", timestamp)

	// Add Ethereum signed message prefix
	prefixedMessage := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(message), message)
	hash := crypto.Keccak256Hash([]byte(prefixedMessage))

	// Get the secp256k1 private key bytes
	privKeyBytes := cli.privKey.Bytes()

	// Convert to ECDSA private key for ethereum signing
	ecdsaPrivKey, err := crypto.ToECDSA(privKeyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to convert to ECDSA key: %w", err)
	}

	// Sign the hash
	signature, err := crypto.Sign(hash.Bytes(), ecdsaPrivKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign message: %w", err)
	}

	// Adjust v value for Ethereum compatibility (add 27)
	if signature[64] < 27 {
		signature[64] += 27
	}

	return "0x" + hex.EncodeToString(signature), nil
}
