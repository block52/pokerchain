# Bridge Architecture & Deposit Synchronization

This document explains how the Ethereum-Cosmos bridge works, including the automatic deposit synchronization mechanism.

## Overview

The bridge enables USDC transfers from Base (Ethereum L2) to Pokerchain (Cosmos). Validators automatically sync deposits from Ethereum in every block - no external relayer required.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          BRIDGE ARCHITECTURE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────┐         ┌────────────────────────────┐
│            BASE CHAIN                 │         │        POKERCHAIN          │
│          (Ethereum L2)                │         │       (Cosmos SDK)         │
└──────────────────┬───────────────────┘         └─────────────┬──────────────┘
                   │                                           │
                   │  1. User deposits USDC                    │
                   │  CosmosBridge.depositUnderlying()         │
                   │                                           │
                   │  2. Contract stores deposit:              │
                   │     deposits[index] = {account, amount}   │
                   │                                           │
                   │                                           │  3. EndBlock runs
                   │                                           │     ProcessNextDeposit()
                   │                                           │
                   │  4. Validator queries contract            │
                   │  ◄────────────────────────────────────────│
                   │  deposits(nextIndex)                      │
                   │  ────────────────────────────────────────►│
                   │                                           │
                   │                                           │  5. If deposit found:
                   │                                           │     - Mint USDC to user
                   │                                           │     - Store eth_block_height
                   │                                           │     - Increment index
                   │                                           │
                   │                                           │  6. All validators do same
                   │                                           │     = CONSENSUS
                   ▼                                           ▼
```

## Key Insight: Index-Based Queries are Deterministic

The bridge works because **deposit data is immutable once written**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     WHY THIS IS DETERMINISTIC                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Ethereum Contract State:                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  deposits[1] = {account: "b52abc...", amount: 1000000}  ← IMMUTABLE │    │
│  │  deposits[2] = {account: "b52def...", amount: 2000000}  ← IMMUTABLE │    │
│  │  deposits[3] = {account: "b52ghi...", amount: 500000}   ← IMMUTABLE │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  When validators query deposits(2):                                          │
│  - Validator A queries at block 39060000 → {b52def, 2000000}                │
│  - Validator B queries at block 39060005 → {b52def, 2000000}  ← SAME!       │
│  - Validator C queries at block 39060010 → {b52def, 2000000}  ← SAME!       │
│                                                                              │
│  The data at index N never changes, so all validators get identical results │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. CosmosBridge Contract (Base Chain)

**Address**: `0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B`

The Solidity contract on Base that:
- Accepts USDC deposits from users via `depositUnderlying(amount, cosmosAddress)`
- Stores deposit data in a mapping: `mapping(uint256 => Deposit) public deposits`
- Auto-increments deposit index for each new deposit
- Emits `Deposited(string account, uint256 amount, uint256 index)` events

```solidity
struct Deposit {
    string account;   // Cosmos bech32 address (b52...)
    uint256 amount;   // USDC amount in microunits (6 decimals)
}

// Key property: Once written, deposit data NEVER changes
// This enables deterministic cross-chain queries
```

### 2. Poker Module (`x/poker/`)

The Cosmos SDK module that automatically syncs deposits:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           POKER MODULE                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                            KEEPER                                       │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                         │ │
│  │  State (Collections):                                                   │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐ │ │
│  │  │ LastProcessedDepositIndex  Sequence[uint64]  → Current: 18        │ │ │
│  │  │ LastEthBlockHeight         Sequence[uint64]  → Current: 39063051  │ │ │
│  │  │ ProcessedEthTxs            KeySet[string]    → Processed tx hashes│ │ │
│  │  └───────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │  Config (from app.toml):                                                │ │
│  │  ┌───────────────────────────────────────────────────────────────────┐ │ │
│  │  │ ethRPCURL           = "https://base-mainnet.g.alchemy.com/..."    │ │ │
│  │  │ depositContractAddr = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"│ │ │
│  │  └───────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │   module.go         │  │  deposit_sync.go    │  │  bridge_verifier.go │  │
│  │   EndBlock()        │  │  ProcessNextDeposit │  │  GetDepositByIndex  │  │
│  │   ───────────────►  │  │  ───────────────►   │  │  ───────────────►   │  │
│  │   Calls sync loop   │  │  Main sync logic    │  │  Ethereum RPC call  │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        bridge_keeper.go                                 │ │
│  │                      ProcessBridgeDeposit()                             │ │
│  │                    (Mints USDC, marks as processed)                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Auto-Sync Flow (Every Block)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EndBlock → ProcessNextDeposit()                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  for i := 0; i < 5; i++ {    // Process up to 5 deposits per block    │ │
│  │      processed := ProcessNextDeposit()                                  │ │
│  │      if !processed { break }                                            │ │
│  │  }                                                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      ProcessNextDeposit()                               │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                         │ │
│  │  1. GET ETH BLOCK HEIGHT                                                │ │
│  │     ┌─────────────────────────────────────────────────────────────┐    │ │
│  │     │ ethBlockHeight = GetLastEthBlockHeight()                    │    │ │
│  │     │                                                              │    │ │
│  │     │ if ethBlockHeight == 0 {                                    │    │ │
│  │     │     // First run: query current Ethereum block              │    │ │
│  │     │     currentBlock = ethClient.BlockNumber()                  │    │ │
│  │     │     ethBlockHeight = currentBlock - 64  // Finalized        │    │ │
│  │     │     // Don't store yet - only store on successful process   │    │ │
│  │     │ }                                                            │    │ │
│  │     └─────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  │  2. GET NEXT INDEX                                                      │ │
│  │     ┌─────────────────────────────────────────────────────────────┐    │ │
│  │     │ lastIndex = GetLastProcessedDepositIndex()  // e.g., 18     │    │ │
│  │     │ nextIndex = lastIndex + 1                   // e.g., 19     │    │ │
│  │     └─────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  │  3. QUERY ETHEREUM                                                      │ │
│  │     ┌─────────────────────────────────────────────────────────────┐    │ │
│  │     │ depositData = verifier.GetDepositByIndex(19, ethBlockHeight)│    │ │
│  │     │                                                              │    │ │
│  │     │ // eth_call to contract: deposits(19)                       │    │ │
│  │     │ // Returns: {account: "b52xyz...", amount: 1000000}         │    │ │
│  │     └─────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  │  4. PROCESS RESULT                                                      │ │
│  │     ┌─────────────────────────────────────────────────────────────┐    │ │
│  │     │ IF deposit NOT found (index doesn't exist yet):             │    │ │
│  │     │     return false  // Try again next block                   │    │ │
│  │     │                                                              │    │ │
│  │     │ IF deposit found but INVALID (bad address):                 │    │ │
│  │     │     - Mark as processed (skip it)                           │    │ │
│  │     │     - Store eth_block_height                                │    │ │
│  │     │     - Increment LastProcessedDepositIndex                   │    │ │
│  │     │     - Emit "deposit_skipped" event                          │    │ │
│  │     │     return true                                              │    │ │
│  │     │                                                              │    │ │
│  │     │ IF deposit found and VALID:                                 │    │ │
│  │     │     - Mint USDC to recipient                                │    │ │
│  │     │     - Mark txHash as processed                              │    │ │
│  │     │     - Store eth_block_height                                │    │ │
│  │     │     - Increment LastProcessedDepositIndex                   │    │ │
│  │     │     - Emit "deposit_synced" event                           │    │ │
│  │     │     return true                                              │    │ │
│  │     └─────────────────────────────────────────────────────────────┘    │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Consensus Guarantee

All validators produce identical state because:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONSENSUS MECHANISM                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STATE ONLY CHANGES WHEN DEPOSIT IS FOUND                                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                                                                         │ │
│  │  Validator A                  Validator B                Validator C    │ │
│  │       │                            │                          │         │ │
│  │       │ Query deposits(19)         │ Query deposits(19)       │ Query   │ │
│  │       ▼                            ▼                          ▼         │ │
│  │                                                                         │ │
│  │  CASE 1: Deposit 19 doesn't exist yet                                   │ │
│  │  ──────────────────────────────────────────────────────────────────     │ │
│  │       │                            │                          │         │ │
│  │       │ return false               │ return false             │ return  │ │
│  │       │ (no state change)          │ (no state change)        │ false   │ │
│  │       │                            │                          │         │ │
│  │       ▼                            ▼                          ▼         │ │
│  │    NO STATE CHANGE             NO STATE CHANGE           NO STATE CHANGE│ │
│  │                            ✅ CONSENSUS                                 │ │
│  │                                                                         │ │
│  │  CASE 2: Deposit 19 exists                                              │ │
│  │  ──────────────────────────────────────────────────────────────────     │ │
│  │       │                            │                          │         │ │
│  │       │ Got: {b52xyz, 1000000}     │ Got: {b52xyz, 1000000}   │ Got:    │ │
│  │       │      ▲                     │      ▲                   │ same    │ │
│  │       │      │                     │      │                   │         │ │
│  │       │      └─────────────────────┴──────┴───────────────────┘         │ │
│  │       │              SAME DATA (immutable on Ethereum)                  │ │
│  │       │                            │                          │         │ │
│  │       │ Process deposit            │ Process deposit          │ Process │ │
│  │       │ Mint 1 USDC to b52xyz      │ Mint 1 USDC to b52xyz    │ same    │ │
│  │       │ Store eth_block_height     │ Store eth_block_height   │ same    │ │
│  │       │ Set index = 19             │ Set index = 19           │ same    │ │
│  │       ▼                            ▼                          ▼         │ │
│  │    SAME STATE                  SAME STATE                SAME STATE     │ │
│  │                            ✅ CONSENSUS                                 │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Deposit Processing Example

When a user deposits 1 USDC:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DEPOSIT LIFECYCLE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. USER ACTION (Base Chain)                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  User calls: CosmosBridge.depositUnderlying(1000000, "b52xyz...")      │ │
│  │                                                                         │ │
│  │  Contract:                                                              │ │
│  │  - Transfers 1 USDC from user to contract                              │ │
│  │  - depositCount++ (now 20)                                             │ │
│  │  - deposits[20] = {account: "b52xyz...", amount: 1000000}              │ │
│  │  - emit Deposited("b52xyz...", 1000000, 20)                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  2. AUTO-SYNC (Pokerchain - happens automatically)                           │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  EndBlock at height 1000:                                               │ │
│  │  - lastIndex = 19, checking index 20                                    │ │
│  │  - Query Ethereum: deposits(20) → {b52xyz, 1000000}                    │ │
│  │  - Generate txHash: sha256("0xcc39...FE5B-20")                         │ │
│  │  - Check not processed: ProcessedEthTxs.Has(txHash) → false            │ │
│  │  - Mint 1000000 usdc to b52xyz...                                      │ │
│  │  - ProcessedEthTxs.Set(txHash)                                         │ │
│  │  - LastProcessedDepositIndex = 20                                       │ │
│  │  - LastEthBlockHeight = 39063100                                        │ │
│  │  - Emit event: deposit_synced{index: 20, recipient: b52xyz, ...}       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  3. RESULT                                                                   │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  User b52xyz... now has 1 USDC on Pokerchain                           │ │
│  │  Deposit is marked as processed (cannot be replayed)                    │ │
│  │  All validators have identical state                                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## State Storage

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CONSENSUS STATE (x/poker)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Key                            │ Type           │ Description               │
│  ──────────────────────────────┼────────────────┼───────────────────────────│
│  last_processed_deposit_index  │ Sequence[u64]  │ Last processed index      │
│  last_eth_block_height         │ Sequence[u64]  │ Ethereum block for queries│
│  processed_eth_txs             │ KeySet[string] │ Processed tx hashes       │
│                                                                              │
│  Current State Example:                                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ last_processed_deposit_index: 18                                        │ │
│  │ last_eth_block_height: 39063051                                         │ │
│  │ processed_eth_txs: [                                                    │ │
│  │   "0x753cb5fb6ce6664d6ac5e44ff0be1f790c68bfb1dea5dc825efe30ffef05f840", │ │
│  │   "0x8a4b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b", │ │
│  │   ... (one entry per processed deposit)                                 │ │
│  │ ]                                                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Error Handling

### Invalid Deposit Address

Deposits with invalid Cosmos addresses are skipped deterministically:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Query deposits(5) → {account: "0xabc123", amount: 1000000}                  │
│                            ▲                                                 │
│                            │ Invalid! Not a bech32 address                  │
│                                                                              │
│  All validators:                                                             │
│  1. Try to process → fails with "invalid bech32 address"                    │
│  2. Mark txHash as processed (prevent retry)                                 │
│  3. Store eth_block_height                                                   │
│  4. Increment LastProcessedDepositIndex to 5                                 │
│  5. Emit "deposit_skipped" event with reason                                 │
│  6. Move on to index 6                                                       │
│                                                                              │
│  Result: All validators skip the same deposit → CONSENSUS                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Deposit Doesn't Exist Yet

When querying an index that doesn't exist:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Query deposits(25) → {account: "", amount: 0}                               │
│                            ▲                                                 │
│                            │ Empty = deposit not created yet                 │
│                                                                              │
│  All validators:                                                             │
│  1. GetDepositByIndex returns error "deposit not found"                      │
│  2. return false (no state change)                                           │
│  3. Try again next block                                                     │
│                                                                              │
│  Result: All validators wait → CONSENSUS                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

## File Structure

```
x/poker/
├── keeper/
│   ├── keeper.go                     # Keeper with state collections
│   ├── deposit_sync.go               # ProcessNextDeposit(), GetLastProcessedDepositIndex()
│   ├── msg_server_process_deposit.go # Manual MsgProcessDeposit handler (optional)
│   ├── bridge_verifier.go            # GetDepositByIndex() - Ethereum RPC
│   └── bridge_keeper.go              # ProcessBridgeDeposit() - minting logic
├── module/
│   └── module.go                     # EndBlock() calls ProcessNextDeposit loop
└── types/
    └── keys.go                       # Storage key prefixes

Configuration in ~/.pokerchain/config/app.toml:
[bridge]
enabled = true
ethereum_rpc_url = "https://base-mainnet.g.alchemy.com/v2/..."
deposit_contract_address = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
```

## Monitoring

```bash
# Watch deposit processing in real-time
journalctl -u pokerchaind -f | grep -E "(deposit|eth_block)"

# Example output:
# INF Checking for next deposit eth_block_height=39063051 next_index=19
# INF Found deposit to process account=b52xyz... amount=1000000 index=19
# INF Successfully processed deposit amount=1000000 index=19 recipient=b52xyz...

# Check current sync status
curl -s localhost:26657/status | jq '.result.sync_info.latest_block_height'
```

## Security Considerations

1. **Double-Spending Prevention**: `ProcessedEthTxs` KeySet tracks all processed deposits by deterministic txHash
2. **Deterministic txHash**: Generated from `sha256(contractAddress + "-" + depositIndex)` - same for all validators
3. **Immutable Deposit Data**: Once written to Ethereum, deposit data never changes
4. **Finalized Block Height**: Use 64 blocks behind current for reorg safety
5. **No External Trust**: No relayer needed - validators query Ethereum directly

## Optional: Deposit Relayer

While not required for normal operation, a deposit relayer (`cmd/deposit-relayer/`) can be used to:
- Process deposits faster (submit explicit transactions instead of waiting for EndBlock)
- Monitor for deposit events and alert operators
- Handle edge cases or stuck deposits

```bash
# Run deposit relayer (optional)
export ETH_RPC_URL="https://mainnet.base.org"
export DEPOSIT_CONTRACT="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
export COSMOS_NODE="http://localhost:26657"
export RELAYER_KEY="relayer"

cd cmd/deposit-relayer && go run main.go
```

---

*Last updated: v0.1.26 - Fully automatic deposit sync without relayer requirement*
