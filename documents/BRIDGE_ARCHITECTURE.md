# Bridge Architecture & Deposit Synchronization

This document explains how the Ethereum-Cosmos bridge works, including the deposit relayer and automatic synchronization mechanism.

## Overview

The bridge enables USDC transfers from Base (Ethereum L2) to Pokerchain (Cosmos). It uses a hybrid approach:
1. **Deposit Relayer** - External service that monitors Ethereum and submits the first deposit
2. **Auto-Sync** - Validators automatically process subsequent deposits in EndBlock

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          BRIDGE ARCHITECTURE                                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│   BASE CHAIN     │         │  DEPOSIT RELAYER │         │   POKERCHAIN     │
│   (Ethereum L2)  │         │   (Off-chain)    │         │   (Cosmos SDK)   │
└────────┬─────────┘         └────────┬─────────┘         └────────┬─────────┘
         │                            │                            │
         │  1. User deposits USDC     │                            │
         │  ───────────────────────►  │                            │
         │  CosmosBridge.deposit()    │                            │
         │                            │                            │
         │  2. Emits Deposited event  │                            │
         │  ◄───────────────────────  │                            │
         │                            │                            │
         │                            │  3. Detects event          │
         │  ─────────────────────────►│                            │
         │                            │                            │
         │                            │  4. Submits MsgProcessDeposit
         │                            │  ─────────────────────────►│
         │                            │  (with eth_block_height)   │
         │                            │                            │
         │                            │                            │  5. Stores:
         │                            │                            │  - eth_block_height
         │                            │                            │  - last_processed_index
         │                            │                            │  - Mints USDC to user
         │                            │                            │
         │                            │                            │  6. EndBlock Auto-Sync
         │  ◄──────────────────────────────────────────────────────│
         │  Query deposits at stored eth_block_height              │
         │  ──────────────────────────────────────────────────────►│
         │                            │                            │  7. Process next deposits
         │                            │                            │
         ▼                            ▼                            ▼
```

## Components

### 1. CosmosBridge Contract (Base Chain)

**Address**: `0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B`

The Solidity contract on Base that:
- Accepts USDC deposits from users
- Stores deposit data: `mapping(uint256 => Deposit) public deposits`
- Emits `Deposited(string account, uint256 amount, uint256 index)` events
- Tracks deposit count with auto-incrementing index

```solidity
struct Deposit {
    string account;   // Cosmos bech32 address (b52...)
    uint256 amount;   // USDC amount in microunits (6 decimals)
}
```

### 2. Deposit Relayer (`cmd/deposit-relayer/`)

An off-chain Go service that:
- Polls Base chain for `Deposited` events
- Submits `MsgProcessDeposit` transactions to Pokerchain
- Provides the initial `eth_block_height` for deterministic queries

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEPOSIT RELAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  ETH Client  │───►│ Event Parser │───►│  TX Builder  │       │
│  │  (Base RPC)  │    │              │    │              │       │
│  └──────────────┘    └──────────────┘    └──────┬───────┘       │
│         │                                        │               │
│         │ FilterLogs(Deposited)                  │ pokerchaind   │
│         ▼                                        ▼ tx poker      │
│  ┌──────────────┐                        ┌──────────────┐       │
│  │ Block Range  │                        │ process-deposit     │
│  │  Tracker     │                        │ <index>       │       │
│  └──────────────┘                        │ <eth_height>  │       │
│                                          └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Configuration** (environment variables):
```bash
ETH_RPC_URL=https://mainnet.base.org
DEPOSIT_CONTRACT=0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B
COSMOS_NODE=http://localhost:26657
COSMOS_CHAIN_ID=pokerchain
RELAYER_KEY=relayer  # Key name in keyring
```

### 3. Poker Module (`x/poker/`)

The Cosmos SDK module that handles deposits:

```
┌─────────────────────────────────────────────────────────────────┐
│                      POKER MODULE                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      KEEPER                                 │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │                                                             │ │
│  │  Collections (State Storage):                               │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │ LastProcessedDepositIndex  Sequence[uint64]         │   │ │
│  │  │ LastEthBlockHeight         Sequence[uint64]         │   │ │
│  │  │ ProcessedEthTxs            KeySet[string]           │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  Bridge Configuration:                                      │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │ ethRPCURL              string                       │   │ │
│  │  │ depositContractAddr    string                       │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ msg_server_      │  │ deposit_sync.go  │  │ bridge_        │ │
│  │ process_deposit  │  │ (EndBlock sync)  │  │ verifier.go    │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬────────┘ │
│           │                     │                     │          │
│           │ MsgProcessDeposit   │ ProcessNextDeposit  │ Query    │
│           ▼                     ▼                     ▼ Ethereum │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    bridge_keeper.go                          ││
│  │                  ProcessBridgeDeposit()                      ││
│  │              (Mints USDC, marks as processed)                ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Deposit Flow (Detailed)

### Step 1: User Deposits on Base

```
User                    CosmosBridge Contract
  │                            │
  │ depositUnderlying(         │
  │   1000000,                 │  (1 USDC = 1,000,000 microunits)
  │   "b52abc..."              │  (Cosmos address)
  │ )                          │
  │ ──────────────────────────►│
  │                            │
  │                            │ deposits[1] = {
  │                            │   account: "b52abc...",
  │                            │   amount: 1000000
  │                            │ }
  │                            │
  │                            │ emit Deposited(
  │                            │   "b52abc...",
  │                            │   1000000,
  │                            │   1  // index
  │                            │ )
  │ ◄──────────────────────────│
  │  (tx receipt)              │
```

### Step 2: Relayer Detects & Submits

```
Deposit Relayer                           Pokerchain
      │                                        │
      │ (Polling every 15s)                    │
      │ eth.FilterLogs({                       │
      │   topics: [Deposited],                 │
      │   fromBlock: lastProcessed             │
      │ })                                     │
      │                                        │
      │ Found: index=1, block=39060000         │
      │                                        │
      │ pokerchaind tx poker process-deposit   │
      │   1                    (deposit index) │
      │   39060000             (eth_block_height)
      │ ──────────────────────────────────────►│
      │                                        │
      │                                        │ MsgProcessDeposit {
      │                                        │   deposit_index: 1,
      │                                        │   eth_block_height: 39060000
      │                                        │ }
```

### Step 3: Pokerchain Processes Deposit

```
┌─────────────────────────────────────────────────────────────────┐
│                   MsgProcessDeposit Handler                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Validate eth_block_height != 0 (required for determinism)   │
│                                                                  │
│  2. Create BridgeVerifier and query Ethereum:                    │
│     ┌───────────────────────────────────────────────────────┐   │
│     │ verifier.GetDepositByIndex(1, 39060000)               │   │
│     │   → CallContract(deposits(1), block=39060000)         │   │
│     │   → Returns: {account: "b52abc...", amount: 1000000}  │   │
│     └───────────────────────────────────────────────────────┘   │
│                                                                  │
│  3. Generate deterministic txHash:                               │
│     sha256("0xcc391c8f...14FE5B-1") → "0x753cb5fb..."           │
│                                                                  │
│  4. Check not already processed:                                 │
│     ProcessedEthTxs.Has("0x753cb5fb...") → false                │
│                                                                  │
│  5. Process deposit:                                             │
│     ProcessBridgeDeposit(txHash, "b52abc...", 1000000, 1)       │
│       → Mint 1000000 usdc to b52abc...                          │
│       → Mark txHash as processed                                 │
│                                                                  │
│  6. CRITICAL: Store state for auto-sync:                         │
│     ┌───────────────────────────────────────────────────────┐   │
│     │ SetLastEthBlockHeight(39060000)     ← All validators  │   │
│     │ SetLastProcessedDepositIndex(1)        will use this  │   │
│     └───────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4: Auto-Sync in EndBlock

```
┌─────────────────────────────────────────────────────────────────┐
│                    EndBlock (Every Block)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  for i := 0; i < 5; i++ {  // Process up to 5 per block         │
│      ProcessNextDeposit()                                        │
│  }                                                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              ProcessNextDeposit()                            ││
│  ├─────────────────────────────────────────────────────────────┤│
│  │                                                              ││
│  │  1. Get stored eth_block_height:                             ││
│  │     height = GetLastEthBlockHeight() → 39060000              ││
│  │     (If 0, skip - waiting for relayer)                       ││
│  │                                                              ││
│  │  2. Get next index to process:                               ││
│  │     lastIndex = GetLastProcessedDepositIndex() → 1           ││
│  │     nextIndex = lastIndex + 1 → 2                            ││
│  │                                                              ││
│  │  3. Query Ethereum at STORED height (deterministic!):        ││
│  │     ┌─────────────────────────────────────────────────────┐ ││
│  │     │ verifier.GetDepositByIndex(2, 39060000)             │ ││
│  │     │                              ▲                      │ ││
│  │     │                              │                      │ ││
│  │     │        Same height for ALL validators = CONSENSUS   │ ││
│  │     └─────────────────────────────────────────────────────┘ ││
│  │                                                              ││
│  │  4. If deposit found:                                        ││
│  │     - Process it (mint USDC)                                 ││
│  │     - Update LastProcessedDepositIndex = 2                   ││
│  │     - Return true (continue loop)                            ││
│  │                                                              ││
│  │  5. If deposit NOT found or invalid:                         ││
│  │     - Mark as skipped (if invalid address)                   ││
│  │     - Return false (stop loop)                               ││
│  │                                                              ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Determinism Guarantee

The key insight is that **all validators must produce identical state**. This is achieved by:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DETERMINISM MECHANISM                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PROBLEM: Validators query Ethereum at different times           │
│           → Different block heights → Different results          │
│           → Consensus failure (AppHash mismatch)                 │
│                                                                  │
│  SOLUTION: Store eth_block_height in consensus state             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Validator A          Validator B          Validator C   │    │
│  │      │                    │                    │        │    │
│  │      │ Read stored        │ Read stored        │ Read   │    │
│  │      │ eth_block_height   │ eth_block_height   │ stored │    │
│  │      ▼                    ▼                    ▼        │    │
│  │  39060000             39060000             39060000     │    │
│  │      │                    │                    │        │    │
│  │      │ Query Ethereum     │ Query Ethereum     │ Query  │    │
│  │      │ at block 39060000  │ at block 39060000  │ at     │    │
│  │      │                    │                    │ 39060000    │
│  │      ▼                    ▼                    ▼        │    │
│  │  SAME DATA            SAME DATA            SAME DATA    │    │
│  │      │                    │                    │        │    │
│  │      │ Process deposit    │ Process deposit    │ Process│    │
│  │      ▼                    ▼                    ▼        │    │
│  │  SAME STATE           SAME STATE           SAME STATE   │    │
│  │                                                          │    │
│  │                    ✅ CONSENSUS!                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## State Storage

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONSENSUS STATE (x/poker)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Key                           │ Type           │ Purpose        │
│  ─────────────────────────────┼────────────────┼────────────────│
│  last_processed_deposit_index │ Sequence[u64]  │ Track progress │
│  last_eth_block_height        │ Sequence[u64]  │ Deterministic  │
│                               │                │ Ethereum queries│
│  processed_eth_txs            │ KeySet[string] │ Prevent double │
│                               │                │ processing     │
│                                                                  │
│  Example state:                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ last_processed_deposit_index: 5                         │    │
│  │ last_eth_block_height: 39060000                         │    │
│  │ processed_eth_txs: [                                    │    │
│  │   "0x753cb5fb6ce6664d...",  // Deposit 1                │    │
│  │   "0x8a4b2c3d4e5f6a7b...",  // Deposit 2                │    │
│  │   ...                                                    │    │
│  │ ]                                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
x/poker/
├── keeper/
│   ├── keeper.go                    # Keeper with state collections
│   ├── deposit_sync.go              # ProcessNextDeposit, state getters/setters
│   ├── msg_server_process_deposit.go # MsgProcessDeposit handler
│   ├── bridge_verifier.go           # Ethereum RPC queries
│   └── bridge_keeper.go             # ProcessBridgeDeposit (minting)
├── module/
│   └── module.go                    # EndBlock with auto-sync loop
└── types/
    ├── keys.go                      # Storage key prefixes
    └── tx.pb.go                     # MsgProcessDeposit definition

cmd/deposit-relayer/
└── main.go                          # Off-chain relayer service
```

## Running the System

### 1. Start Pokerchain Validators

```bash
# On each validator node
systemctl start pokerchaind
```

### 2. Start Deposit Relayer (one instance)

```bash
# Environment setup
export ETH_RPC_URL="https://mainnet.base.org"
export DEPOSIT_CONTRACT="0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B"
export COSMOS_NODE="http://localhost:26657"
export RELAYER_KEY="relayer"

# Run relayer
cd cmd/deposit-relayer
go run main.go
```

### 3. Monitor Deposits

```bash
# Check last processed index
pokerchaind query poker params

# Watch logs for deposit processing
journalctl -u pokerchaind -f | grep -i deposit
```

## Error Handling

### Invalid Deposit Address

If a deposit has an invalid Cosmos address (e.g., hex instead of bech32):

```
┌─────────────────────────────────────────────────────────────────┐
│  1. ProcessNextDeposit queries deposit index N                   │
│  2. GetDepositByIndex returns account="0xabc123..." (invalid)   │
│  3. ProcessBridgeDeposit fails: "invalid bech32 address"        │
│  4. CONSENSUS CRITICAL: Must handle deterministically!           │
│     ┌─────────────────────────────────────────────────────────┐ │
│     │ - Mark txHash as processed (prevent retry)              │ │
│     │ - Increment LastProcessedDepositIndex                   │ │
│     │ - Emit "deposit_skipped" event                          │ │
│     │ - ALL validators skip the same deposit                  │ │
│     └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Fresh Chain (No eth_block_height Set)

```
┌─────────────────────────────────────────────────────────────────┐
│  EndBlock runs...                                                │
│  ProcessNextDeposit() called                                     │
│  GetLastEthBlockHeight() returns 0                               │
│  → Skip processing, log: "waiting for relayer to process first" │
│  → Return false (no deposit processed)                           │
│                                                                  │
│  Once relayer submits first MsgProcessDeposit:                   │
│  → eth_block_height stored in state                              │
│  → Auto-sync kicks in for subsequent deposits                    │
└─────────────────────────────────────────────────────────────────┘
```

## Security Considerations

1. **Double-Spending Prevention**: `ProcessedEthTxs` KeySet tracks all processed deposits
2. **Deterministic txHash**: Generated from `sha256(contractAddress-depositIndex)`
3. **Block Height Finality**: Use height at least 64 blocks behind current (for reorg safety)
4. **Relayer Trust**: Relayer only triggers processing; actual deposit data is verified on-chain

---

*Last updated: v0.1.25 - Re-enabled auto-deposit sync with deterministic eth_block_height*
