package keeper

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"cosmossdk.io/log"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
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

	// Query for deposit events
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(bs.lastProcessedBlock + 1)),
		ToBlock:   big.NewInt(int64(latestBlock)),
		Addresses: []common.Address{bs.depositContract},
		Topics: [][]common.Hash{
			{common.HexToHash("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")}, // Transfer event
		},
	}

	logs, err := bs.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to filter logs: %w", err)
	}

	if len(logs) > 0 {
		bs.logger.Info("📋 Found deposit events", "count", len(logs))
	}

	// Process each deposit event
	for _, vLog := range logs {
		bs.logger.Info("🔍 Processing deposit event", "txHash", vLog.TxHash.Hex())
		if err := bs.processDepositEvent(ctx, vLog); err != nil {
			bs.logger.Error("❌ Failed to process deposit event", "error", err, "txHash", vLog.TxHash.Hex())
		}
	}

	bs.lastProcessedBlock = latestBlock
	return nil
}

// processDepositEvent processes a single deposit event
func (bs *BridgeService) processDepositEvent(ctx context.Context, vLog types.Log) error {
	// Parse the transfer event to extract deposit details
	// This is a simplified version - in production you'd parse the actual ABI

	// Extract recipient from transaction data or logs
	tx, _, err := bs.ethClient.TransactionByHash(ctx, vLog.TxHash)
	if err != nil {
		return fmt.Errorf("failed to get transaction: %w", err)
	}

	// For this example, we'll assume the recipient address is encoded in the transaction data
	// In a real implementation, you'd parse the contract call data properly
	recipient, amount, nonce, err := bs.parseTransactionData(tx.Data())
	if err != nil {
		return fmt.Errorf("failed to parse transaction data: %w", err)
	}

	// Check if this transaction has already been processed
	txHash := vLog.TxHash.Hex()
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	if exists, err := bs.keeper.ProcessedEthTxs.Has(sdkCtx, txHash); err != nil {
		return fmt.Errorf("failed to check processed transactions: %w", err)
	} else if exists {
		bs.logger.Debug("Transaction already processed", "txHash", txHash)
		return nil
	}

	// Create mint message and execute it
	depositEvent := DepositEvent{
		From:      vLog.Address,
		Recipient: recipient,
		Amount:    amount,
		TxHash:    txHash,
		Nonce:     nonce,
	}

	return bs.executeMint(ctx, depositEvent)
}

// parseTransactionData extracts recipient, amount, and nonce from transaction data
func (bs *BridgeService) parseTransactionData(data []byte) (recipient string, amount *big.Int, nonce uint64, err error) {
	// This is a placeholder implementation
	// In a real scenario, you'd decode the contract call data using the ABI

	// For demonstration, we'll return mock data
	// In production, this would parse the actual contract call data
	recipient = "cosmos1..."     // Extract from contract call data
	amount = big.NewInt(1000000) // Extract from contract call data (in micro-USDC)
	nonce = 1                    // Extract from contract call data

	return recipient, amount, nonce, nil
}

// executeMint performs the actual minting on the Cosmos side
func (bs *BridgeService) executeMint(ctx context.Context, event DepositEvent) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// Convert amount from wei to micro-USDC
	amountMicroUSDC := event.Amount.Uint64()

	// Create coins to mint
	coins := sdk.NewCoins(sdk.NewInt64Coin("uusdc", int64(amountMicroUSDC)))

	// Mint coins to the module account
	if err := bs.keeper.bankKeeper.MintCoins(ctx, pokertypes.ModuleName, coins); err != nil {
		return fmt.Errorf("failed to mint coins: %w", err)
	}

	// Convert recipient address
	recipientAddr, err := bs.keeper.addressCodec.StringToBytes(event.Recipient)
	if err != nil {
		return fmt.Errorf("invalid recipient address: %w", err)
	}

	// Send coins to recipient
	if err := bs.keeper.bankKeeper.SendCoinsFromModuleToAccount(ctx, pokertypes.ModuleName, recipientAddr, coins); err != nil {
		return fmt.Errorf("failed to send coins to recipient: %w", err)
	}

	// Mark transaction as processed
	if err := bs.keeper.ProcessedEthTxs.Set(sdkCtx, event.TxHash); err != nil {
		return fmt.Errorf("failed to mark transaction as processed: %w", err)
	}

	bs.logger.Info("✅ Successfully bridged USDC",
		"recipient", event.Recipient,
		"amount", amountMicroUSDC,
		"txHash", event.TxHash,
		"nonce", event.Nonce,
	)

	return nil
}

// GetLastProcessedBlock returns the last processed Ethereum block number
func (bs *BridgeService) GetLastProcessedBlock() uint64 {
	return bs.lastProcessedBlock
}

// SetLastProcessedBlock sets the last processed Ethereum block number
func (bs *BridgeService) SetLastProcessedBlock(blockNumber uint64) {
	bs.lastProcessedBlock = blockNumber
}
