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
	rpcURL        = "https://node.texashodl.net/rpc"
	addressPrefix = "b52"
)

type EncodingConfig struct {
	InterfaceRegistry codectypes.InterfaceRegistry
	Codec             codec.Codec
	TxConfig          client.TxConfig
	Amino             *codec.LegacyAmino
}

func main() {
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

	// Create the MsgCreateGame
	msg := &pokertypes.MsgCreateGame{
		Creator:    addr.String(),
		MinBuyIn:   100_000_000,    // 100 USDC
		MaxBuyIn:   1_000_000_000,  // 1000 USDC
		MinPlayers: 2,
		MaxPlayers: 9,
		SmallBlind: 500_000,   // 0.5 USDC
		BigBlind:   1_000_000, // 1 USDC
		Timeout:    60,
		GameType:   "nlhe",
	}

	fmt.Printf("\nCreating game with parameters:\n")
	fmt.Printf("  Min Buy-in: %d uusdc\n", msg.MinBuyIn)
	fmt.Printf("  Max Buy-in: %d uusdc\n", msg.MaxBuyIn)
	fmt.Printf("  Small Blind: %d uusdc\n", msg.SmallBlind)
	fmt.Printf("  Big Blind: %d uusdc\n", msg.BigBlind)
	fmt.Printf("  Players: %d-%d\n", msg.MinPlayers, msg.MaxPlayers)
	fmt.Printf("  Game Type: %s\n\n", msg.GameType)

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
