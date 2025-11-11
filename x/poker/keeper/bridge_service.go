package keeper

import (
	"context"
	"fmt"
	"math/big"
	"sync"
	"time"

	"cosmossdk.io/log"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

// BridgeService handles monitoring Ethereum L1 deposits and bridging USDC to Cosmos
type BridgeService struct {
	keeper             *Keeper
	ethClient          *ethclient.Client
	depositContract    common.Address
	usdcContract       common.Address
	logger             log.Logger
	lastProcessedBlock uint64
	pollingInterval    time.Duration
	pendingDeposits    []DepositEvent
	depositMutex       sync.Mutex
}

// DepositEvent represents a USDC deposit event from Ethereum
type DepositEvent struct {
	From      common.Address `json:"from"`
	Recipient string         `json:"recipient"`
	Amount    *big.Int       `json:"amount"`
	TxHash    string         `json:"txHash"`
	Nonce     uint64         `json:"nonce"`
}

// NewBridgeService creates a new bridge service instance
func NewBridgeService(
	keeper *Keeper,
	ethRPCURL string,
	depositContractAddr string,
	usdcContractAddr string,
	logger log.Logger,
) (*BridgeService, error) {
	client, err := ethclient.Dial(ethRPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum client: %w", err)
	}

	return &BridgeService{
		keeper:             keeper,
		ethClient:          client,
		depositContract:    common.HexToAddress(depositContractAddr),
		usdcContract:       common.HexToAddress(usdcContractAddr),
		logger:             logger,
		pollingInterval:    15 * time.Second, // Poll every 15 seconds
		lastProcessedBlock: 0,                // Should be loaded from state
	}, nil
}

// Start begins monitoring Ethereum deposits
func (bs *BridgeService) Start(ctx context.Context) {
	ticker := time.NewTicker(bs.pollingInterval)
	defer ticker.Stop()

	bs.logger.Info("🌉 Bridge Service Starting",
		"contract", bs.depositContract.Hex(),
		"usdc", bs.usdcContract.Hex(),
		"polling_interval", bs.pollingInterval.String(),
	)

	for {
		select {
		case <-ctx.Done():
			bs.logger.Info("🌉 Bridge service stopped")
			return
		case <-ticker.C:
			bs.logger.Debug("🔍 Checking for new deposits...")
			if err := bs.processNewDeposits(ctx); err != nil {
				bs.logger.Error("❌ Error processing deposits", "error", err)
			}
		}
	}
}

// processNewDeposits checks for new deposit events and processes them
func (bs *BridgeService) processNewDeposits(ctx context.Context) error {
	// Get latest block number
	latestBlock, err := bs.ethClient.BlockNumber(ctx)
	if err != nil {
		return fmt.Errorf("failed to get latest block: %w", err)
	}

	// If this is the first run, start from recent blocks
	if bs.lastProcessedBlock == 0 {
		bs.lastProcessedBlock = latestBlock - 10 // Start from 10 blocks ago
		bs.logger.Info("📊 Starting from recent blocks",
			"starting_block", bs.lastProcessedBlock,
			"latest_block", latestBlock,
		)
	}

	// Process blocks in chunks to avoid "range too large" errors
	const maxBlockRange = 999 // Most RPC providers limit to ~1000 blocks
	startBlock := bs.lastProcessedBlock + 1

	for startBlock <= latestBlock {
		endBlock := startBlock + maxBlockRange
		if endBlock > latestBlock {
			endBlock = latestBlock
		}

		bs.logger.Debug("🔍 Scanning block range",
			"from", startBlock,
			"to", endBlock,
			"range", endBlock-startBlock+1,
		)

		// Query for deposit events in this chunk
		query := ethereum.FilterQuery{
			FromBlock: big.NewInt(int64(startBlock)),
			ToBlock:   big.NewInt(int64(endBlock)),
			Addresses: []common.Address{bs.depositContract},
			Topics: [][]common.Hash{
				{common.HexToHash("0x46008385c8bcecb546cb0a96e5b409f34ac1a8ece8f3ea98488282519372bdf2")}, // Deposited event
			},
		}

		logs, err := bs.ethClient.FilterLogs(ctx, query)
		if err != nil {
			return fmt.Errorf("failed to filter logs (blocks %d-%d): %w", startBlock, endBlock, err)
		}

		if len(logs) > 0 {
			bs.logger.Info("📋 Found deposit events",
				"count", len(logs),
				"block_range", fmt.Sprintf("%d-%d", startBlock, endBlock),
			)
		}

		// Process each deposit event
		for _, vLog := range logs {
			bs.logger.Info("🔍 Processing deposit event", "txHash", vLog.TxHash.Hex(), "block", vLog.BlockNumber)
			if err := bs.processDepositEvent(ctx, vLog); err != nil {
				bs.logger.Error("❌ Failed to process deposit event", "error", err, "txHash", vLog.TxHash.Hex())
			}
		}

		// Move to next chunk
		startBlock = endBlock + 1
	}

	bs.lastProcessedBlock = latestBlock
	return nil
}

// processDepositEvent processes a single deposit event
func (bs *BridgeService) processDepositEvent(ctx context.Context, vLog types.Log) error {
	bs.logger.Info("🔷 trackMint: Entering processDepositEvent", "txHash", vLog.TxHash.Hex(), "block", vLog.BlockNumber)

	// Parse the Deposited event from CosmosBridge contract
	// event Deposited(string indexed account, uint256 amount, uint256 index)

	// Get the transaction to extract the cosmos recipient address from input data
	tx, _, err := bs.ethClient.TransactionByHash(ctx, vLog.TxHash)
	if err != nil {
		return fmt.Errorf("failed to get transaction: %w", err)
	}

	// Parse the deposit details from transaction data and event logs
	recipient, amount, nonce, err := bs.parseDepositEvent(tx.Data(), vLog.Data)
	if err != nil {
		bs.logger.Error("❌ trackMint: Failed to parse deposit event", "error", err)
		return fmt.Errorf("failed to parse deposit event: %w", err)
	}

	bs.logger.Info("✅ trackMint: Deposit event parsed successfully",
		"recipient", recipient,
		"amount", amount.String(),
		"nonce", nonce,
	)

	txHash := vLog.TxHash.Hex()

	// Create deposit event and add to queue
	depositEvent := DepositEvent{
		From:      vLog.Address,
		Recipient: recipient,
		Amount:    amount,
		TxHash:    txHash,
		Nonce:     nonce,
	}

	// Add to pending deposits queue (thread-safe)
	bs.depositMutex.Lock()
	bs.pendingDeposits = append(bs.pendingDeposits, depositEvent)
	bs.depositMutex.Unlock()

	bs.logger.Info("✅ trackMint: Queued deposit for processing",
		"recipient", recipient,
		"amount", amount.String(),
		"txHash", txHash,
		"nonce", nonce,
	)

	bs.logger.Info("📌 trackMint: Deposit queued - will be processed in EndBlocker with proper SDK context", "txHash", txHash)

	return nil
}

// parseDepositEvent extracts recipient, amount, and nonce from Deposited event
func (bs *BridgeService) parseDepositEvent(txData []byte, eventData []byte) (recipient string, amount *big.Int, nonce uint64, err error) {
	// Parse the transaction input data to extract the cosmos recipient address
	// Function signature for depositUnderlying(uint256 amount, string calldata receiver)
	// or deposit(uint256 amount, string calldata receiver, address token)

	if len(txData) < 4 {
		return "", nil, 0, fmt.Errorf("transaction data too short")
	}

	// Extract function selector (first 4 bytes)
	selector := txData[:4]

	// depositUnderlying: 0x3ccfd60b (keccak256("depositUnderlying(uint256,string)"))
	// deposit: 0x47e7ef24 (keccak256("deposit(uint256,string,address)"))

	var recipientStr string

	// For depositUnderlying, params start at byte 4
	// Layout: amount (32 bytes), string offset (32 bytes), string length (32 bytes), string data
	if len(txData) >= 68 {
		// Skip selector (4) + amount (32) + string offset (32) = 68 bytes
		// Read string length from offset
		if len(txData) >= 100 {
			// String length is at bytes 68-100
			strLenBytes := txData[68:100]
			strLen := new(big.Int).SetBytes(strLenBytes).Uint64()

			// String data starts at byte 100
			if len(txData) >= int(100+strLen) {
				recipientStr = string(txData[100 : 100+strLen])
			}
		}
	}

	if recipientStr == "" {
		return "", nil, 0, fmt.Errorf("could not extract recipient address from transaction data")
	}

	// Parse event data: amount (uint256) and index (uint256)
	// Event data contains non-indexed parameters
	if len(eventData) < 64 {
		return "", nil, 0, fmt.Errorf("event data too short: expected 64 bytes, got %d", len(eventData))
	}

	// Amount is first 32 bytes
	amountBytes := eventData[0:32]
	amount = new(big.Int).SetBytes(amountBytes)

	// Index is second 32 bytes
	indexBytes := eventData[32:64]
	nonce = new(big.Int).SetBytes(indexBytes).Uint64()

	bs.logger.Info("📋 Parsed deposit event",
		"recipient", recipientStr,
		"amount", amount.String(),
		"index", nonce,
		"selector", fmt.Sprintf("0x%x", selector),
	)

	return recipientStr, amount, nonce, nil
}

// GetPendingDeposits returns and clears the pending deposits queue (thread-safe)
func (bs *BridgeService) GetPendingDeposits() []DepositEvent {
	bs.depositMutex.Lock()
	defer bs.depositMutex.Unlock()

	deposits := bs.pendingDeposits
	bs.pendingDeposits = []DepositEvent{} // Clear the queue
	return deposits
}

// GetLastProcessedBlock returns the last processed Ethereum block number
func (bs *BridgeService) GetLastProcessedBlock() uint64 {
	return bs.lastProcessedBlock
}

// SetLastProcessedBlock sets the last processed Ethereum block number
func (bs *BridgeService) SetLastProcessedBlock(blockNumber uint64) {
	bs.lastProcessedBlock = blockNumber
}
