# Ethereum USDC Bridge

This module implements a bridge to monitor USDC deposits on Ethereum L1 and mint corresponding USDC tokens on the Pokerchain Cosmos network.

## Features

-   **Automatic Monitoring**: Continuously monitors Ethereum L1 for USDC deposit events
-   **Double-Spend Protection**: Tracks processed transactions to prevent double minting
-   **Secure Validation**: Validates all bridge transactions before minting
-   **Event Emission**: Emits Cosmos events for all bridge operations for transparency

## Configuration

Add the following to your app configuration:

```yaml
bridge:
    enabled: true
    ethereum_rpc_url: "https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE"
    deposit_contract_address: "0x..." # Your deposit contract address
    usdc_contract_address: "0xA0b86a33E6d3D24fDbCBFe003eDa2E26A6E73a60"
    polling_interval_seconds: 15
    starting_block: 0
```

## Usage

### Message Handler

The bridge supports the `MsgMint` message type for manual bridging:

```go
msg := &types.MsgMint{
    Creator:   "cosmos1...", // Authority address
    Recipient: "cosmos1...", // Recipient address
    Amount:    1000000,      // Amount in micro-USDC (6 decimals)
    EthTxHash: "0x...",      // Ethereum transaction hash
    Nonce:     1,            // Unique nonce
}
```

### Bridge Service

The bridge service automatically:

1. Monitors the Ethereum deposit contract for Transfer events
2. Parses transaction data to extract recipient and amount
3. Validates transactions haven't been processed before
4. Mints USDC tokens on Cosmos and sends to recipient
5. Marks transaction as processed to prevent double-spending

### Querying

Check if a transaction has been processed:

```bash
pokerchaind query poker is-tx-processed 0x1234...
```

List all processed transactions:

```bash
pokerchaind query poker processed-transactions
```

## Security Features

-   **Transaction Deduplication**: Each Ethereum transaction can only be processed once
-   **Address Validation**: All addresses are validated before processing
-   **Amount Validation**: Ensures amounts are positive and reasonable
-   **Event Logging**: All operations are logged for audit trails

## Integration Example

```go
// In your app.go
bridgeService, err := pokerkeeper.NewBridgeService(
    app.PokerKeeper,
    bridgeConfig.EthereumRPCURL,
    bridgeConfig.DepositContractAddress,
    bridgeConfig.USDCContractAddress,
    logger,
)
if err != nil {
    panic(err)
}

// Start the bridge service
go bridgeService.Start(context.Background())
```

## Ethereum Contract Requirements

Your Ethereum deposit contract should emit Transfer events when USDC is deposited for bridging. The bridge monitors for these events and processes them accordingly.

Example Solidity contract:

```solidity
contract USDCBridge {
    IERC20 public usdc;

    event DepositForBridge(
        address indexed from,
        string cosmosRecipient,
        uint256 amount,
        uint256 nonce
    );

    function depositForBridge(string memory cosmosRecipient, uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        emit DepositForBridge(msg.sender, cosmosRecipient, amount, nonce++);
    }
}
```
