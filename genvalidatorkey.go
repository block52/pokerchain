// go build -o genvalidatorkey genvalidatorkey.go

package main

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cosmos/go-bip39"
)

// PrivValidatorKey matches the structure of priv_validator_key.json
type PrivValidatorKey struct {
	Address string `json:"address"`
	PubKey  PubKey `json:"pub_key"`
	PrivKey PrivKey `json:"priv_key"`
}

type PubKey struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

type PrivKey struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: genvalidatorkey <mnemonic> [output_file]")
		fmt.Println("       genvalidatorkey generate [output_file]")
		fmt.Println("")
		fmt.Println("Examples:")
		fmt.Println("  # Generate new mnemonic and key")
		fmt.Println("  genvalidatorkey generate")
		fmt.Println("")
		fmt.Println("  # Use existing mnemonic")
		fmt.Println("  genvalidatorkey \"word1 word2 ... word24\" priv_validator_key.json")
		os.Exit(1)
	}

	var mnemonic string
	outputFile := "priv_validator_key.json"

	if os.Args[1] == "generate" {
		// Generate new mnemonic
		entropy, err := bip39.NewEntropy(256) // 24 words
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error generating entropy: %v\n", err)
			os.Exit(1)
		}
		mnemonic, err = bip39.NewMnemonic(entropy)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error generating mnemonic: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Generated mnemonic (SAVE THIS SECURELY):")
		fmt.Println(mnemonic)
		fmt.Println("")

		if len(os.Args) > 2 {
			outputFile = os.Args[2]
		}
	} else {
		mnemonic = os.Args[1]
		if len(os.Args) > 2 {
			outputFile = os.Args[2]
		}

		// Validate mnemonic
		if !bip39.IsMnemonicValid(mnemonic) {
			fmt.Fprintf(os.Stderr, "Error: Invalid mnemonic phrase\n")
			os.Exit(1)
		}
	}

	// Generate seed from mnemonic
	seed := bip39.NewSeed(mnemonic, "") // Empty passphrase

	// Derive ed25519 private key from seed
	// We'll use the first 32 bytes of the seed as the private key
	// Note: In production, you might want to use proper BIP32/BIP44 derivation
	hash := sha256.Sum256(seed)
	privKey := ed25519.GenPrivKeyFromSecret(hash[:])

	// Get public key and address
	pubKey := privKey.PubKey()
	address := pubKey.Address()

	// Create the validator key structure
	validatorKey := PrivValidatorKey{
		Address: address.String(),
		PubKey: PubKey{
			Type:  "tendermint/PubKeyEd25519",
			Value: base64.StdEncoding.EncodeToString(pubKey.Bytes()),
		},
		PrivKey: PrivKey{
			Type:  "tendermint/PrivKeyEd25519",
			Value: base64.StdEncoding.EncodeToString(privKey.Bytes()),
		},
	}

	// Marshal to JSON
	jsonBytes, err := json.MarshalIndent(validatorKey, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	// Write to file
	err = os.WriteFile(outputFile, jsonBytes, 0600)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✓ Created validator key file: %s\n", outputFile)
	fmt.Printf("  Address: %s\n", address.String())
	fmt.Printf("  PubKey:  %s\n", base64.StdEncoding.EncodeToString(pubKey.Bytes()))
	fmt.Println("")
	fmt.Println("⚠️  IMPORTANT: Keep your mnemonic phrase secure!")
	fmt.Println("   It can be used to recover this validator key.")
}