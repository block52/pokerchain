package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

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
	if len(os.Args) < 4 {
		fmt.Println("Usage: join-game <game_id> <seat> <buy_in_amount>")
		fmt.Println("")
		fmt.Println("Example:")
		fmt.Println("  join-game 0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1 1 500000000")
		fmt.Println("")
		fmt.Println("Arguments:")
		fmt.Println("  game_id       - The game/table ID to join (hex string)")
		fmt.Println("  seat          - Seat number (1-9 for 9-max tables)")
		fmt.Println("  buy_in_amount - Buy-in amount in uusdc (e.g., 500000000 = 500 USDC)")
		os.Exit(1)
	}

	gameID := os.Args[1]
	var seat uint64
	var buyInAmount uint64

	if _, err := fmt.Sscanf(os.Args[2], "%d", &seat); err != nil {
		fmt.Printf("Error: Invalid seat number: %v\n", err)
		os.Exit(1)
	}
	if seat < 1 || seat > 9 {
		fmt.Println("Error: Seat number must be between 1 and 9")
		os.Exit(1)
	}

	if _, err := fmt.Sscanf(os.Args[3], "%d", &buyInAmount); err != nil {
		fmt.Printf("Error: Invalid buy-in amount: %v\n", err)
		os.Exit(1)
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

	// Create the MsgJoinGame
	msg := &pokertypes.MsgJoinGame{
		Player:      addr.String(),
		GameId:      gameID,
		Seat:        seat,
		BuyInAmount: buyInAmount,
	}

	fmt.Printf("\nJoining game with parameters:\n")
	fmt.Printf("  Game ID: %s\n", msg.GameId)
	fmt.Printf("  Seat: %d\n", msg.Seat)
	fmt.Printf("  Buy-in: %d uusdc\n\n", msg.BuyInAmount)

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
	fmt.Printf("\nYou have joined game %s at seat %d with %d uusdc\n", gameID, seat, buyInAmount)
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
