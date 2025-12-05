package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"log"
	"math/big"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Configuration
var (
	// Base chain RPC URL - defaults to public endpoint, override with ETH_RPC_URL env var
	ethRPCURL = getEnv("ETH_RPC_URL", "https://mainnet.base.org")

	// CosmosBridge contract on Base
	depositContractAddress = getEnv("DEPOSIT_CONTRACT", "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B")

	// Cosmos chain details
	cosmosChainID = getEnv("COSMOS_CHAIN_ID", "pokerchain")
	cosmosNode    = getEnv("COSMOS_NODE", "http://localhost:26657")
	relayerKey    = getEnv("RELAYER_KEY", "relayer") // Key name in keyring

	// Polling interval
	pollingInterval = 15 * time.Second

	// Deposited event topic: keccak256("Deposited(string,uint256,uint256)")
	depositedEventTopic = common.HexToHash("0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2")
)

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

// ProcessedDeposit tracks which deposit indices have been submitted
var processedIndices = make(map[uint64]bool)

func main() {
	log.Println("🌉 Deposit Relayer Starting...")
	log.Printf("   ETH RPC: %s", ethRPCURL)
	log.Printf("   Contract: %s", depositContractAddress)
	log.Printf("   Cosmos Node: %s", cosmosNode)
	log.Printf("   Chain ID: %s", cosmosChainID)
	log.Printf("   Relayer Key: %s", relayerKey)

	// Connect to Ethereum
	ethClient, err := ethclient.Dial(ethRPCURL)
	if err != nil {
		log.Fatalf("❌ Failed to connect to Ethereum: %v", err)
	}
	defer ethClient.Close()

	// Get current block
	currentBlock, err := ethClient.BlockNumber(context.Background())
	if err != nil {
		log.Fatalf("❌ Failed to get current block: %v", err)
	}
	log.Printf("✅ Connected to Base chain, current block: %d", currentBlock)

	// Start from recent blocks
	lastProcessedBlock := currentBlock - 100

	// Handle graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("🛑 Shutting down...")
		cancel()
	}()

	// Main polling loop
	ticker := time.NewTicker(pollingInterval)
	defer ticker.Stop()

	log.Printf("🔄 Starting polling loop (interval: %s)", pollingInterval)

	for {
		select {
		case <-ctx.Done():
			log.Println("👋 Relayer stopped")
			return
		case <-ticker.C:
			latestBlock, err := ethClient.BlockNumber(ctx)
			if err != nil {
				log.Printf("⚠️ Failed to get latest block: %v", err)
				continue
			}

			if lastProcessedBlock >= latestBlock {
				continue // No new blocks
			}

			// Process new blocks
			err = processBlocks(ctx, ethClient, lastProcessedBlock+1, latestBlock)
			if err != nil {
				log.Printf("⚠️ Error processing blocks: %v", err)
				continue
			}

			lastProcessedBlock = latestBlock
		}
	}
}

func processBlocks(ctx context.Context, ethClient *ethclient.Client, fromBlock, toBlock uint64) error {
	const maxBlockRange = 999

	for startBlock := fromBlock; startBlock <= toBlock; startBlock += maxBlockRange + 1 {
		endBlock := startBlock + maxBlockRange
		if endBlock > toBlock {
			endBlock = toBlock
		}

		// Query for Deposited events
		query := ethereum.FilterQuery{
			FromBlock: big.NewInt(int64(startBlock)),
			ToBlock:   big.NewInt(int64(endBlock)),
			Addresses: []common.Address{common.HexToAddress(depositContractAddress)},
			Topics:    [][]common.Hash{{depositedEventTopic}},
		}

		logs, err := ethClient.FilterLogs(ctx, query)
		if err != nil {
			return fmt.Errorf("failed to filter logs: %w", err)
		}

		for _, vLog := range logs {
			// Parse deposit index from event data
			// Event: Deposited(string indexed account, uint256 amount, uint256 index)
			// Non-indexed: amount (32 bytes) + index (32 bytes)
			if len(vLog.Data) < 64 {
				log.Printf("⚠️ Invalid event data length: %d", len(vLog.Data))
				continue
			}

			indexBytes := vLog.Data[32:64]
			depositIndex := new(big.Int).SetBytes(indexBytes).Uint64()

			// Skip if already processed
			if processedIndices[depositIndex] {
				continue
			}

			log.Printf("📥 Found deposit: index=%d, tx=%s, block=%d",
				depositIndex, vLog.TxHash.Hex(), vLog.BlockNumber)

			// Submit to Cosmos chain
			err := submitDeposit(depositIndex, vLog.BlockNumber)
			if err != nil {
				log.Printf("⚠️ Failed to submit deposit %d: %v", depositIndex, err)
				// Don't mark as processed, will retry next time
				continue
			}

			processedIndices[depositIndex] = true
			log.Printf("✅ Deposit %d submitted successfully", depositIndex)
		}
	}

	return nil
}

func submitDeposit(depositIndex uint64, ethBlockHeight uint64) error {
	// Build the command - eth-block-height is now a positional argument
	cmd := exec.Command("pokerchaind", "tx", "poker", "process-deposit",
		fmt.Sprintf("%d", depositIndex),
		fmt.Sprintf("%d", ethBlockHeight),
		"--from", relayerKey,
		"--chain-id", cosmosChainID,
		"--node", cosmosNode,
		"--gas", "auto",
		"--gas-adjustment", "1.5",
		"--yes",
		"--output", "json",
	)

	log.Printf("🚀 Submitting: pokerchaind tx poker process-deposit %d %d",
		depositIndex, ethBlockHeight)

	output, err := cmd.CombinedOutput()
	if err != nil {
		// Check if it's already processed (not an error)
		if strings.Contains(string(output), "already processed") ||
			strings.Contains(string(output), "ErrTxAlreadyProcessed") {
			log.Printf("ℹ️ Deposit %d already processed", depositIndex)
			return nil
		}
		return fmt.Errorf("command failed: %v, output: %s", err, string(output))
	}

	log.Printf("📤 TX Output: %s", truncateString(string(output), 200))
	return nil
}

func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// Helper to decode hex string
func decodeHex(s string) []byte {
	s = strings.TrimPrefix(s, "0x")
	b, _ := hex.DecodeString(s)
	return b
}
