# Phases to Increasing B52 Token Value

> **Purpose**: This document outlines the evolution of our gas token strategy from early testing through to production, where B52 token becomes the primary staking/governance token.

## Executive Summary

| Phase | Focus | Gas Token | Who Pays Gas? |
|-------|-------|-----------|---------------|
| **Phase 1** | Game mechanics work | STAKE (testnet) | Faucet distributes free STAKE |
| **Phase 2** | Stable testnet | STAKE | Fee Grant module pays for users |
| **Phase 3** | Production | B52 | Users stake B52 on Ethereum, validators check |

---

## Visual Overview

```mermaid
timeline
    title Journey to B52 Token Value

    Phase 1 : Game Testing
            : Free STAKE faucet
            : Focus on poker logic
            : Real USDC via bridge

    Phase 2 : Stable Testnet
            : Fee Grant module
            : No tokens needed by users
            : Smoother onboarding

    Phase 3 : Production
            : B52 on Ethereum
            : Validators check B52 stake
            : Full decentralization
```

---

## Phase 1: Game Mechanics (Current)

### Goal
Ensure the poker game works smoothly. Players can deposit real USDC via bridge and play.

### Architecture

```mermaid
flowchart TB
    subgraph Ethereum["Ethereum (Base Chain)"]
        USDC[USDC Token]
        Bridge[CosmosBridge.sol]
    end

    subgraph Cosmos["Pokerchain"]
        BridgeService[Bridge Service]
        PokerModule[x/poker Module]
        BankModule[x/bank Module]
        Validator[Validator Node]
    end

    subgraph User["User Journey"]
        Wallet[User Wallet]
        UI[Poker UI]
    end

    subgraph Faucet["Gas Solution (Manual)"]
        Bob[Bob Genesis Account<br/>~900,000 STAKE]
        Transfer[Transfer Modal<br/>in Dashboard]
    end

    USDC -->|1. Deposit| Bridge
    Bridge -->|2. Event| BridgeService
    BridgeService -->|3. Mint b52USDC| BankModule

    Bob -->|Admin imports Bob| Transfer
    Transfer -->|Sends STAKE| Wallet

    Wallet -->|4. Play poker| UI
    UI -->|5. Tx + gas fee| PokerModule

    style Bob fill:#4ecdc4,stroke:#333,stroke-width:2px
    style Transfer fill:#f9f,stroke:#333,stroke-width:2px
```

### Gas Token: STAKE via Manual Transfer (Current Implementation)

**Problem**: Users need STAKE to pay transaction fees, but they only bring USDC.

**Solution**: Admin imports Bob's genesis account and uses the Transfer feature to send STAKE.

```mermaid
sequenceDiagram
    participant Admin as Admin (Incognito Browser)
    participant Bob as Bob's Wallet
    participant UI as Dashboard
    participant Chain as Pokerchain
    participant NewUser as New User

    Note over Admin,NewUser: One-time setup for admin
    Admin->>UI: Open /admin/genesis page
    UI-->>Admin: Show Bob's mnemonic
    Admin->>Bob: Import Bob's mnemonic

    Note over Admin,NewUser: When new user needs STAKE
    NewUser->>Admin: Request STAKE (share address)
    Admin->>UI: Click "Transfer" button
    UI->>Admin: Show Transfer Modal

    Admin->>UI: Select STAKE token
    Admin->>UI: Enter recipient address
    Admin->>UI: Enter amount (e.g., 100)
    Admin->>UI: Click "Send STAKE"

    UI->>Chain: MsgSend tx
    Chain-->>UI: Tx success
    Chain->>NewUser: +100 STAKE

    NewUser->>UI: Can now play poker!
```

### Current Faucet: Bob's Genesis Account

**Bob is the Phase 1 Faucet!**

| Field | Value |
|-------|-------|
| Address | `b521hg93rsm2f5v3zlepf20ru88uweajt3nf492s2p` |
| Balance | ~899,778 STAKE |
| Mnemonic | `vanish legend pelican blush control spike useful usage into any remove wear flee short october naive swear wall spy cup sort avoid agent credit` |

**How to use:**
1. Open incognito browser
2. Go to `/admin/genesis` and copy Bob's mnemonic
3. Import into wallet
4. Use **Transfer** button → Select **STAKE** → Send to user

> **Detailed Guide**: See [HOW_TO_GET_STAKE_TOKENS.md](./HOW_TO_GET_STAKE_TOKENS.md)

### Why This Works for Phase 1

| Pros | Cons |
|------|------|
| Already implemented | Manual process |
| No additional code needed | Requires admin intervention |
| Uses existing Transfer UI | Not scalable |
| Works immediately | Bob's key shared with team |

### Future Faucet Options (Phase 1b)

#### Option A: Express Endpoint in PVM

```mermaid
flowchart LR
    subgraph PVM["PVM Server (Express)"]
        API["/faucet endpoint"]
        Key[Faucet Private Key<br/>NOT validator key!]
    end

    subgraph Genesis["Genesis Accounts"]
        Val[Validator<br/>1M STAKE]
        Faucet[Faucet<br/>100K STAKE]
    end

    User -->|POST /faucet| API
    API -->|Signs tx with| Key
    Key -->|Sends from| Faucet

    style Key fill:#ff6b6b,stroke:#333,stroke-width:2px
    style Val fill:#4ecdc4,stroke:#333,stroke-width:2px
```

| Pros | Cons |
|------|------|
| Automated | Requires implementation |
| Self-service | Need rate limiting |
| No admin needed | Faucet key is hot wallet |

#### Option B: Cosmos SDK Faucet Module

Uses Ignite's built-in faucet (development only).

```yaml
# config.yml
faucet:
  name: bob
  coins: ["10stake"]
  rate_limit_window: "1h"
```

| Pros | Cons |
|------|------|
| Zero code needed | Development mode only |
| Built-in rate limiting | Not for production |

---

## Phase 2: Stable Testnet

### Goal
Smoother onboarding - users don't need to "get gas" manually.

### Architecture Change

```mermaid
flowchart TB
    subgraph Cosmos["Pokerchain"]
        FeeGrant[x/feegrant Module]
        Granter[Granter Account<br/>Pays gas for users]
        PokerModule[x/poker Module]
    end

    subgraph User["User Journey"]
        Wallet[User Wallet<br/>0 STAKE]
        UI[Poker UI]
    end

    Granter -->|Grants allowance| FeeGrant
    FeeGrant -->|User submits tx| PokerModule
    Granter -->|Pays gas fee| PokerModule

    Wallet -->|Submit tx| UI
    UI -->|Tx with fee_granter| PokerModule

    Note1[User never needs STAKE!<br/>Granter pays all gas fees]

    style FeeGrant fill:#4ecdc4,stroke:#333,stroke-width:2px
    style Note1 fill:#ffffcc,stroke:#333
```

### Gas Token: Fee Grant Module

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant Chain as Pokerchain
    participant Granter as Fee Granter

    Note over User,Granter: One-time setup per user
    User->>UI: Connect wallet (new user)
    UI->>Chain: Request fee grant for user
    Chain->>Granter: Create allowance (100 STAKE limit)

    Note over User,Granter: Every transaction after
    User->>UI: Join table
    UI->>Chain: Tx with fee_granter=Granter
    Chain->>Granter: Deduct gas from allowance
    Chain-->>UI: Tx success

    Note over User: User paid 0 STAKE!
```

### Comparison: Faucet vs Fee Grant

```mermaid
flowchart LR
    subgraph Faucet["Phase 1: Faucet"]
        F1[User gets STAKE]
        F2[User pays gas]
        F3[STAKE in user wallet]
    end

    subgraph FeeGrant["Phase 2: Fee Grant"]
        G1[User gets allowance]
        G2[Granter pays gas]
        G3[No STAKE in user wallet]
    end

    F1 --> F2 --> F3
    G1 --> G2 --> G3

    style FeeGrant fill:#90EE90,stroke:#333
```

| Aspect | Faucet (Phase 1) | Fee Grant (Phase 2) |
|--------|------------------|---------------------|
| User holds STAKE | Yes | No |
| UX friction | "Get Gas" button | Invisible |
| Accounting | Tokens scattered | Centralized spending |
| Rate limiting | Custom code | Built-in (allowance limits) |
| Cosmos native | No | Yes |

---

## Phase 3: Production (B52 Token)

### Goal
Full decentralization. B52 token on Ethereum determines validator eligibility and user permissions.

### Architecture

```mermaid
flowchart TB
    subgraph Ethereum["Ethereum (Base Chain)"]
        B52Token[B52 Token Contract]
        StakingContract[B52 Staking Contract]
        USDC[USDC Token]
        Bridge[CosmosBridge.sol]
    end

    subgraph Cosmos["Pokerchain"]
        ValidatorSet[Validator Set]
        OracleModule[B52 Oracle Module]
        PokerModule[x/poker Module]
    end

    subgraph Validator["Validator Requirements"]
        Check1[Has B52 staked on Ethereum?]
        Check2[Meets minimum stake?]
        Check3[Not slashed?]
    end

    B52Token -->|Stake| StakingContract
    StakingContract -->|Query balance| OracleModule
    OracleModule -->|Validator eligible?| ValidatorSet

    ValidatorSet -->|Run consensus| PokerModule

    Check1 --> Check2 --> Check3

    style B52Token fill:#FFD700,stroke:#333,stroke-width:2px
    style StakingContract fill:#FFD700,stroke:#333,stroke-width:2px
```

### Gas Token: TBD (Options)

```mermaid
flowchart TB
    subgraph Options["Phase 3 Gas Options"]
        OptA[Option A: Fee Grant<br/>continues from Phase 2]
        OptB[Option B: B52 as gas token<br/>mint B52 on Cosmos]
        OptC[Option C: Gasless<br/>validators subsidize]
    end

    subgraph Decision["Decision Factors"]
        D1[User experience]
        D2[Economic model]
        D3[Decentralization]
    end

    OptA --> D1
    OptB --> D2
    OptC --> D3

    style Options fill:#E6E6FA,stroke:#333
```

### User Journey in Phase 3

```mermaid
sequenceDiagram
    participant User
    participant Ethereum as Ethereum Wallet
    participant Base as Base Chain
    participant Cosmos as Pokerchain

    Note over User,Cosmos: User only interacts with Ethereum wallet

    User->>Ethereum: Connect wallet
    Ethereum->>Base: Check B52 balance
    Base-->>Ethereum: 1000 B52 staked

    User->>Ethereum: Deposit USDC to bridge
    Base->>Cosmos: Bridge event
    Cosmos-->>Cosmos: Mint b52USDC

    User->>Cosmos: Play poker
    Note over Cosmos: Gas paid by Fee Grant<br/>or B52-based mechanism

    User->>Cosmos: Withdraw winnings
    Cosmos->>Base: Withdrawal to Ethereum
    Base-->>User: USDC in wallet
```

### Validator Economics in Phase 3

```mermaid
flowchart TB
    subgraph Ethereum["Ethereum"]
        B52Stake[B52 Staking Contract]
        Rewards[Reward Distribution]
    end

    subgraph Cosmos["Pokerchain"]
        Rake[Poker Rake<br/>% of each pot]
        Treasury[Protocol Treasury]
    end

    subgraph Validators["Validators"]
        V1[Validator 1<br/>10K B52 staked]
        V2[Validator 2<br/>50K B52 staked]
        V3[Validator 3<br/>25K B52 staked]
    end

    Rake -->|Accumulates| Treasury
    Treasury -->|Distribute| Rewards
    Rewards -->|Pro-rata by stake| V1
    Rewards -->|Pro-rata by stake| V2
    Rewards -->|Pro-rata by stake| V3

    V1 -->|Must maintain| B52Stake
    V2 -->|Must maintain| B52Stake
    V3 -->|Must maintain| B52Stake

    style Rake fill:#90EE90,stroke:#333
    style Treasury fill:#FFD700,stroke:#333
```

---

## Implementation Roadmap

```mermaid
gantt
    title Implementation Phases
    dateFormat  YYYY-MM

    section Phase 1
    Faucet account in genesis     :done, p1a, 2024-10, 1d
    Express /faucet endpoint      :active, p1b, after p1a, 3d
    UI "Get Gas" button           :p1c, after p1b, 2d
    Rate limiting                 :p1d, after p1c, 2d

    section Phase 2
    Fee Grant module research     :p2a, after p1d, 3d
    Implement granter account     :p2b, after p2a, 3d
    UI integration                :p2c, after p2b, 3d
    Remove faucet                 :p2d, after p2c, 1d

    section Phase 3
    B52 contract design           :p3a, after p2d, 5d
    Oracle module                 :p3b, after p3a, 10d
    Validator staking             :p3c, after p3b, 10d
    Production launch             :milestone, after p3c, 0d
```

---

## Decision Matrix: Phase 1 Faucet Options

For team discussion - which faucet approach for Phase 1?

```mermaid
quadrantChart
    title Faucet Options: Complexity vs Security
    x-axis Low Complexity --> High Complexity
    y-axis Low Security --> High Security
    quadrant-1 Ideal
    quadrant-2 Overkill for Phase 1
    quadrant-3 Avoid
    quadrant-4 Good for Phase 1

    Express Endpoint: [0.25, 0.4]
    Ignite Faucet: [0.15, 0.2]
    Fee Grant: [0.6, 0.8]
    Custom Module: [0.85, 0.9]
```

| Option | Complexity | Security | Time to Implement | Recommendation |
|--------|------------|----------|-------------------|----------------|
| **A: Express Endpoint** | Low | Medium | 1-2 days | **Phase 1** |
| **B: Ignite Faucet** | Very Low | Low | 0 days | Local dev only |
| **C: Fee Grant Module** | Medium | High | 3-5 days | **Phase 2** |
| **D: Custom x/faucet** | High | High | 1-2 weeks | Not recommended |

---

## Security Considerations

```mermaid
flowchart TB
    subgraph Critical["CRITICAL: Never Use Validator Key for Faucet"]
        ValidatorKey[Validator Private Key]
        Staked[Controls staked tokens]
        Consensus[Signs consensus votes]
        Danger[If compromised = chain at risk]
    end

    subgraph Safe["SAFE: Dedicated Faucet Account"]
        FaucetKey[Faucet Private Key]
        Limited[Limited STAKE balance]
        Refillable[Can be refilled]
        Isolated[If compromised = only faucet funds at risk]
    end

    ValidatorKey --> Staked --> Consensus --> Danger
    FaucetKey --> Limited --> Refillable --> Isolated

    style Critical fill:#ffcccc,stroke:#ff0000,stroke-width:2px
    style Safe fill:#ccffcc,stroke:#00ff00,stroke-width:2px
```

---

## Open Questions for Team Discussion

1. **Phase 1 Rate Limiting**: How many STAKE per address per day?
   - Suggestion: 100 STAKE/day, 10 STAKE per request

2. **Phase 2 Fee Grant Limits**: How much gas allowance per user?
   - Suggestion: 1000 STAKE allowance, auto-refill monthly

3. **Phase 3 B52 Integration**:
   - Minimum B52 stake to become validator?
   - How to handle Ethereum ↔ Cosmos state sync?
   - Slashing mechanism on Ethereum or Cosmos?

---

## Appendix: Genesis Changes by Phase

### Phase 1 Genesis (Current + Faucet)

```json
{
  "app_state": {
    "bank": {
      "balances": [
        {
          "address": "b521...validator...",
          "coins": [{"denom": "stake", "amount": "1000000000000"}]
        },
        {
          "address": "b521...faucet...",
          "coins": [{"denom": "stake", "amount": "100000000000"}]
        }
      ]
    }
  }
}
```

### Phase 2 Genesis (+ Fee Granter)

```json
{
  "app_state": {
    "bank": {
      "balances": [
        {
          "address": "b521...validator...",
          "coins": [{"denom": "stake", "amount": "1000000000000"}]
        },
        {
          "address": "b521...granter...",
          "coins": [{"denom": "stake", "amount": "500000000000"}]
        }
      ]
    },
    "feegrant": {
      "allowances": []
    }
  }
}
```

---

## Summary

| Phase | User Experience | Technical Approach | B52 Token Role |
|-------|----------------|-------------------|----------------|
| **1** | "Get Gas" button | Express faucet endpoint | None |
| **2** | Invisible gas | Fee Grant module | None |
| **3** | Connect Ethereum wallet | B52 staking oracle | Validator eligibility + governance |

**Next Steps for Team**:
1. Decide on Phase 1 faucet implementation (Option A recommended)
2. Define rate limiting parameters
3. Plan Phase 2 Fee Grant integration timeline
4. Research B52 staking contract requirements for Phase 3
