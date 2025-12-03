# Cosmos SDK Gas and Fees Explained

> **Purpose**: This document explains why we need to set `gasPrice` in our client code even when the chain's `minimum-gas-prices` is set to 0.

## The Confusion

You might expect:
- If `minimum-gas-prices = 0` on the chain → No fees needed
- But in practice: `gasPrice: "0stake"` causes transactions to fail!

**Why?** Because gas price and minimum gas prices serve different purposes.

---

## The Two Sides of Gas

```mermaid
flowchart TB
    subgraph Client["Client Side (Your App)"]
        GP[gasPrice setting]
        GL[gasLimit setting]
        FEE[fee = gasPrice × gasLimit]
    end

    subgraph Chain["Chain Side (Validator)"]
        MGP[minimum-gas-prices]
        CHECK{fee ≥ gasUsed × minPrice?}
        ACCEPT[Accept Transaction]
        REJECT[Reject Transaction]
    end

    GP --> FEE
    GL --> FEE
    FEE -->|Attached to TX| CHECK
    MGP --> CHECK
    CHECK -->|Yes| ACCEPT
    CHECK -->|No| REJECT

    style Client fill:#e3f2fd,stroke:#1565c0
    style Chain fill:#e8f5e9,stroke:#1b5e20
```

---

## Key Concepts

### 1. Gas Limit (`gasLimit` / `gas_wanted`)

**What**: Maximum gas units the transaction is allowed to consume.

```mermaid
flowchart LR
    TX[Transaction] --> SIM[Gas Simulation]
    SIM --> USED[gas_used: 67,777]
    USED --> LIMIT[gas_wanted: 200,000]
    LIMIT --> CHECK{gas_used ≤ gas_wanted?}
    CHECK -->|Yes| OK[TX Executes]
    CHECK -->|No| FAIL[Out of Gas!]
```

- **Your transaction**: `gas_used: 67,777` / `gas_wanted: 200,000`
- The 200,000 is a safe upper bound
- You only "pay" for what you use (sort of - see below)

### 2. Gas Price (`gasPrice`)

**What**: How much you're willing to pay per unit of gas.

```
fee = gasPrice × gasLimit
```

**Your transaction**:
```
fee = 0.025 stake × 200,000 gas = 5,000 stake
```

### 3. Minimum Gas Prices (`minimum-gas-prices`)

**What**: Chain/validator setting that rejects transactions below a threshold.

```yaml
# app.toml on validator
minimum-gas-prices = "0.001stake"
```

---

## Why `gasPrice: "0stake"` Fails

Even with `minimum-gas-prices = ""` (empty/zero):

```mermaid
sequenceDiagram
    participant App as Your App
    participant SDK as Cosmos SDK
    participant Chain as Pokerchain

    App->>SDK: sendTokens with gasPrice 0stake
    SDK->>SDK: Calculate fee = 0 x 200000 = 0
    SDK->>Chain: Submit TX with fee 0stake

    Note over Chain: Even with min-gas-prices = 0<br/>the transaction still needs<br/>a fee field to be valid

    Chain-->>App: Error insufficient fees
```

**The Issue**: When gasPrice is 0, the SDK calculates `fee = 0`. But Cosmos SDK transactions require a non-empty fee field for the signature to be valid.

---

## The Real Fee Calculation

```mermaid
flowchart TD
    subgraph Input["Your Settings"]
        GP["gasPrice: 0.025stake"]
        GL["gasLimit: 200,000"]
    end

    subgraph Calculation["Fee Calculation"]
        CALC["fee = 0.025 × 200,000"]
        RESULT["fee = 5,000 stake"]
    end

    subgraph Transaction["TX Submission"]
        TX["Transaction"]
        FEE["fee: 5000stake"]
        GAS["gas_limit: 200000"]
    end

    subgraph Execution["On Chain"]
        USED["gas_used: 67,777"]
        REFUND["Unused gas: 132,223"]
        NOTE["Note: Fee is NOT refunded!"]
    end

    GP --> CALC
    GL --> CALC
    CALC --> RESULT
    RESULT --> FEE
    GL --> GAS
    FEE --> TX
    GAS --> TX
    TX --> USED
    USED --> REFUND
    REFUND --> NOTE

    style NOTE fill:#ffcdd2,stroke:#c62828
```

**Important**: You pay for `gasLimit`, not `gasUsed`! The fee (5000 stake) is deducted regardless of actual gas consumption.

---

## Breaking Down Your Transaction

| Field | Value | Explanation |
|-------|-------|-------------|
| `gas_wanted` | 200,000 | Maximum gas allowed |
| `gas_used` | 67,777 | Actual gas consumed |
| `fee` | 5,000 stake | `0.025 × 200,000` |
| `from_address` | Bob's address | Sender |
| `to_address` | Your address | Recipient |
| `amount` | 10,000,000 ustake | 10 STAKE |

### Transaction Events Explained

```mermaid
sequenceDiagram
    participant Bob as Bob's Account
    participant FeeCollector as Fee Collector
    participant You as Your Account

    Note over Bob,You: Step 1: Fee Payment
    Bob->>FeeCollector: 5,000 stake (fee)

    Note over Bob,You: Step 2: Token Transfer
    Bob->>You: 10,000,000 ustake (10 STAKE)

    Note over Bob: Bob's balance reduced by:<br/>5,000 (fee) + 10,000,000 (transfer)
```

From your events:
1. **Fee payment**: `coin_spent: 5000stake` → `coin_received` by fee collector
2. **Transfer**: `coin_spent: 10000000stake` → `coin_received` by recipient

---

## The Golden Rule

```mermaid
flowchart LR
    subgraph Rule["The Golden Rule"]
        R1["Always set gasPrice > 0"]
        R2["Even if chain allows 0"]
        R3["SDK needs it for fee calculation"]
    end

    style Rule fill:#fff9c4,stroke:#f57f17
```

### Recommended Values

| Environment | `gasPrice` | Rationale |
|-------------|------------|-----------|
| Local testnet | `"0.001stake"` | Minimal fees |
| Shared testnet | `"0.025stake"` | Safe buffer |
| Production | `"0.025stake"` | Competitive |

---

## Code Pattern

```typescript
// ❌ WRONG - Will fail even if chain allows 0 fees
const signingClient = await createSigningClientFromMnemonic({
    gasPrice: "0stake"  // Results in fee = 0
}, mnemonic);

// ✅ CORRECT - Always provide a gas price
const signingClient = await createSigningClientFromMnemonic({
    gasPrice: "0.025stake"  // Results in reasonable fee
}, mnemonic);
```

---

## Why Does This Design Exist?

```mermaid
flowchart TB
    subgraph Reasons["Why Require Non-Zero Fees?"]
        R1[Spam Prevention]
        R2[Validator Incentives]
        R3[Priority Ordering]
        R4[Economic Security]
    end

    R1 --> S1[Even tiny fees deter<br/>millions of spam TXs]
    R2 --> S2[Validators earn fees<br/>for processing TXs]
    R3 --> S3[Higher fee = faster<br/>inclusion in block]
    R4 --> S4[Cost to attack<br/>the network]

    style Reasons fill:#e8f5e9,stroke:#1b5e20
```

Even when `minimum-gas-prices = 0`:
1. **SDK Design**: The SDK expects a fee to be calculated
2. **Signature**: The fee is part of what gets signed
3. **Validation**: Empty fees can cause validation issues

---

## Visual: Your Transaction Flow

```mermaid
flowchart TB
    subgraph YourApp["Your App (Dashboard)"]
        SEND["Click 'Send STAKE'"]
        CONFIG["gasPrice: 0.025stake<br/>gasLimit: 200,000"]
    end

    subgraph SDK["@bitcoinbrisbane/block52"]
        CALC["Calculate fee:<br/>0.025 × 200,000 = 5,000"]
        BUILD["Build transaction"]
        SIGN["Sign with private key"]
    end

    subgraph Broadcast["Network"]
        RPC["RPC Node<br/>texashodl.net:26657"]
        MEMPOOL["Mempool"]
    end

    subgraph Validator["Validator"]
        VALIDATE["Validate TX"]
        EXECUTE["Execute MsgSend"]
        BLOCK["Include in Block #55455"]
    end

    subgraph Result["Result"]
        SUCCESS["TX Success!"]
        HASH["Hash: 299067AF..."]
    end

    SEND --> CONFIG
    CONFIG --> CALC
    CALC --> BUILD
    BUILD --> SIGN
    SIGN --> RPC
    RPC --> MEMPOOL
    MEMPOOL --> VALIDATE
    VALIDATE --> EXECUTE
    EXECUTE --> BLOCK
    BLOCK --> SUCCESS
    SUCCESS --> HASH

    style YourApp fill:#e3f2fd,stroke:#1565c0
    style SDK fill:#fff3e0,stroke:#e65100
    style Validator fill:#e8f5e9,stroke:#1b5e20
```

---

## Summary

| Concept | Client-Side | Chain-Side |
|---------|-------------|------------|
| **Gas Price** | `gasPrice: "0.025stake"` | `minimum-gas-prices: "0.001stake"` |
| **Purpose** | Calculate fee to attach | Reject low-fee TXs |
| **Set Where** | SDK client config | Validator app.toml |
| **When 0** | Fee = 0 → TX fails | Accepts any fee ≥ 0 |

**Key Takeaway**: Always set `gasPrice > 0` in your client code, regardless of chain settings. The SDK needs it to calculate and attach a valid fee to your transaction.

---

## Reference: Your Working Configuration

```typescript
// From useCosmosWallet.ts
const signingClient = await createSigningClientFromMnemonic(
    {
        rpcEndpoint: currentNetwork.rpc,
        restEndpoint: currentNetwork.rest,
        chainId: "pokerchain",
        prefix: "b52",
        denom: "stake",
        gasPrice: "0.025stake"  // ← This is required!
    },
    mnemonic
);
```

This produces transactions like:
- **Gas Wanted**: 200,000
- **Gas Used**: ~67,000 (for MsgSend)
- **Fee**: 5,000 stake
- **Result**: Success!
