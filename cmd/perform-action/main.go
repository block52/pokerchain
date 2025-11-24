package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

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
	"github.com/cosmos/go-bip39"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	"cosmossdk.io/math"
	"github.com/cosmos/cosmos-sdk/codec"
	codectypes "github.com/cosmos/cosmos-sdk/codec/types"
	"github.com/cosmos/cosmos-sdk/std"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

const (
	mnemonic      = "grow broom cigar crime caught name charge today comfort tourist ethics erode sleep merge bring relax swap clog whale rent unable vehicle thought buddy"
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

func main() {
	// Check command line arguments
	if len(os.Args) < 3 {
		printUsage()
		os.Exit(1)
	}

	gameID := os.Args[1]
	action := strings.ToLower(os.Args[2])
	var amount uint64 = 0

	// Validate action
	validActions := []string{"fold", "call", "check", "bet", "raise"}
	isValidAction := false
	for _, validAction := range validActions {
		if action == validAction {
			isValidAction = true
			break
		}
	}
	if !isValidAction {
		fmt.Printf("Error: Invalid action '%s'\n", action)
		fmt.Printf("Valid actions: %s\n\n", strings.Join(validActions, ", "))
		printUsage()
		os.Exit(1)
	}

	// Parse amount if provided (required for bet/raise)
	if action == "bet" || action == "raise" {
		if len(os.Args) < 4 {
			fmt.Printf("Error: Amount required for %s action\n\n", action)
			printUsage()
			os.Exit(1)
		}
		if _, err := fmt.Sscanf(os.Args[3], "%d", &amount); err != nil {
			fmt.Printf("Error: Invalid amount: %v\n", err)
			os.Exit(1)
		}
	}

	// Set address prefix
	config := sdk.GetConfig()
	config.SetBech32PrefixForAccount(addressPrefix, addressPrefix+"pub")
	config.Seal()

	// Create encoding config
	encodingConfig := makeEncodingConfig()

	// Derive private key from mnemonic
	privKey, addr, err := deriveKey(mnemonic)
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

	// Create client context
	clientCtx := client.Context{}.
		WithCodec(encodingConfig.Codec).
		WithInterfaceRegistry(encodingConfig.InterfaceRegistry).
		WithTxConfig(encodingConfig.TxConfig).
		WithLegacyAmino(encodingConfig.Amino).
		WithChainID(chainID).
		WithGRPCClient(grpcConn).
		WithAccountRetriever(authtypes.AccountRetriever{})

	// Get account info
	account, err := clientCtx.AccountRetriever.GetAccount(clientCtx, addr)
	if err != nil {
		fmt.Printf("Error getting account: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Account number: %d, Sequence: %d\n", account.GetAccountNumber(), account.GetSequence())

	// Create the MsgPerformAction
	msg := &pokertypes.MsgPerformAction{
		Player: addr.String(),
		GameId: gameID,
		Action: action,
		Amount: amount,
	}

	fmt.Printf("\nPerforming action:\n")
	fmt.Printf("  Game ID: %s\n", msg.GameId)
	fmt.Printf("  Action: %s\n", msg.Action)
	if amount > 0 {
		fmt.Printf("  Amount: %d uusdc\n", msg.Amount)
	}
	fmt.Println()

	// Build transaction
	txBuilder := clientCtx.TxConfig.NewTxBuilder()
	err = txBuilder.SetMsgs(msg)
	if err != nil {
		fmt.Printf("Error setting messages: %v\n", err)
		os.Exit(1)
	}

	// Set gas and fees
	txBuilder.SetGasLimit(300_000)
	txBuilder.SetFeeAmount(sdk.NewCoins(sdk.NewCoin("stake", math.NewInt(300))))

	// Sign the transaction
	sigV2 := signing.SignatureV2{
		PubKey: privKey.PubKey(),
		Data: &signing.SingleSignatureData{
			SignMode:  signing.SignMode_SIGN_MODE_DIRECT,
			Signature: nil,
		},
		Sequence: account.GetSequence(),
	}

	err = txBuilder.SetSignatures(sigV2)
	if err != nil {
		fmt.Printf("Error setting signatures: %v\n", err)
		os.Exit(1)
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
		privKey,
		clientCtx.TxConfig,
		account.GetSequence(),
	)
	if err != nil {
		fmt.Printf("Error signing transaction: %v\n", err)
		os.Exit(1)
	}

	err = txBuilder.SetSignatures(sigV2)
	if err != nil {
		fmt.Printf("Error setting final signatures: %v\n", err)
		os.Exit(1)
	}

	// Encode transaction
	txBytes, err := clientCtx.TxConfig.TxEncoder()(txBuilder.GetTx())
	if err != nil {
		fmt.Printf("Error encoding transaction: %v\n", err)
		os.Exit(1)
	}

	// Broadcast transaction using gRPC
	fmt.Println("Broadcasting transaction...")

	txClient := txtypes.NewServiceClient(grpcConn)
	grpcRes, err := txClient.BroadcastTx(
		context.Background(),
		&txtypes.BroadcastTxRequest{
			Mode:    txtypes.BroadcastMode_BROADCAST_MODE_SYNC,
			TxBytes: txBytes,
		},
	)
	if err != nil {
		fmt.Printf("Error broadcasting transaction: %v\n", err)
		os.Exit(1)
	}

	res := grpcRes.TxResponse

	// Print result
	resJSON, _ := json.MarshalIndent(res, "", "  ")
	fmt.Printf("\nTransaction Result:\n%s\n", string(resJSON))

	if res.Code != 0 {
		fmt.Printf("\n❌ Transaction failed with code %d: %s\n", res.Code, res.RawLog)
		os.Exit(1)
	}

	fmt.Printf("\n✅ Transaction successful!\n")
	fmt.Printf("Transaction hash: %s\n", res.TxHash)

	if amount > 0 {
		fmt.Printf("\nPerformed %s for %d uusdc in game %s\n", action, amount, gameID)
	} else {
		fmt.Printf("\nPerformed %s in game %s\n", action, gameID)
	}
}

func printUsage() {
	fmt.Println("Usage: perform-action <game_id> <action> [amount]")
	fmt.Println("")
	fmt.Println("Actions:")
	fmt.Println("  fold   - Fold your hand (no amount needed)")
	fmt.Println("  call   - Call the current bet (no amount needed)")
	fmt.Println("  check  - Check (no amount needed)")
	fmt.Println("  bet    - Place a bet (amount required)")
	fmt.Println("  raise  - Raise the current bet (amount required)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  # Fold")
	fmt.Println("  perform-action 0x89a7c...771df1 fold")
	fmt.Println("")
	fmt.Println("  # Call")
	fmt.Println("  perform-action 0x89a7c...771df1 call")
	fmt.Println("")
	fmt.Println("  # Check")
	fmt.Println("  perform-action 0x89a7c...771df1 check")
	fmt.Println("")
	fmt.Println("  # Bet 1000000 uusdc (1 USDC)")
	fmt.Println("  perform-action 0x89a7c...771df1 bet 1000000")
	fmt.Println("")
	fmt.Println("  # Raise to 5000000 uusdc (5 USDC)")
	fmt.Println("  perform-action 0x89a7c...771df1 raise 5000000")
	fmt.Println("")
	fmt.Println("Arguments:")
	fmt.Println("  game_id - The game/table ID (hex string starting with 0x)")
	fmt.Println("  action  - The poker action to perform")
	fmt.Println("  amount  - Amount in uusdc (required for bet/raise)")
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
