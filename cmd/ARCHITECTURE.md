# Pokerchain Architecture Documentation

This document provides a comprehensive overview of the Pokerchain system architecture, including data flows, component dependencies, and real-time WebSocket integration.

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Dependencies](#component-dependencies)
3. [Network Infrastructure](#network-infrastructure)
4. [Game Action Flows](#game-action-flows)
5. [WebSocket Real-Time Updates](#websocket-real-time-updates)
6. [Reverse Proxy Configuration](#reverse-proxy-configuration)

---

## System Overview

Pokerchain is a Cosmos SDK blockchain for decentralized poker gaming with real-time WebSocket updates.

```mermaid
flowchart TB
    subgraph "Client Layer"
        UI[React Poker UI<br/>poker-vm/ui]
        SDK[Block52 SDK<br/>@bitcoinbrisbane/block52]
    end

    subgraph "Transport Layer"
        NGINX[Nginx Reverse Proxy<br/>node.texashodl.net]
        WS[WebSocket Server<br/>:8585]
    end

    subgraph "Blockchain Layer"
        RPC[Tendermint RPC<br/>:26657]
        GRPC[gRPC Server<br/>:9090]
        REST[REST API<br/>:1317]
        KEEPER[Poker Keeper<br/>x/poker/keeper]
    end

    subgraph "Game Engine Layer"
        PVM[Poker Virtual Machine<br/>localhost:8545]
    end

    subgraph "External"
        BASE[Base Chain<br/>USDC Bridge]
    end

    UI --> SDK
    SDK --> NGINX
    NGINX --> RPC
    NGINX --> REST
    NGINX --> WS

    WS --> RPC
    WS --> GRPC

    KEEPER --> PVM
    KEEPER --> BASE

    RPC --> KEEPER

    style UI fill:#61dafb
    style SDK fill:#f7df1e
    style NGINX fill:#009639
    style WS fill:#4fc08d
    style RPC fill:#00d4aa
    style GRPC fill:#00d4aa
    style REST fill:#00d4aa
    style KEEPER fill:#667eea
    style PVM fill:#ff6b6b
    style BASE fill:#0052ff
```

---

## Component Dependencies

### Dependency Graph

```mermaid
flowchart TD
    subgraph "Frontend Dependencies"
        UI[React UI]
        SDK[Block52 SDK]
        WC[WalletConnect/Reown]
        ETHERS[Ethers.js]
    end

    subgraph "Backend Dependencies"
        COSMOS[Cosmos SDK v0.53.2]
        COMET[CometBFT v0.38.17]
        IBC[IBC v10.2.0]
        GRPCLIB[gRPC-Go]
    end

    subgraph "Poker Module"
        KEEPER[Poker Keeper]
        TYPES[Types/Messages]
        QUERIES[Query Handlers]
        MSGS[Message Handlers]
    end

    subgraph "External Services"
        PVM[Poker VM Engine<br/>TypeScript]
        MONGO[MongoDB<br/>Game State]
        BRIDGE[Base Chain Bridge<br/>USDC]
    end

    UI --> SDK
    UI --> WC
    SDK --> ETHERS
    SDK --> REST_CLIENT[REST Client]

    KEEPER --> COSMOS
    KEEPER --> COMET
    KEEPER --> IBC

    MSGS --> KEEPER
    QUERIES --> KEEPER
    TYPES --> MSGS
    TYPES --> QUERIES

    KEEPER --> PVM
    KEEPER --> BRIDGE
    PVM --> MONGO

    style KEEPER fill:#667eea
    style PVM fill:#ff6b6b
    style COSMOS fill:#00d4aa
```

### Module Dependency Tree

```mermaid
flowchart LR
    subgraph "Cosmos SDK Modules"
        AUTH[x/auth]
        BANK[x/bank]
        STAKING[x/staking]
        GOV[x/gov]
    end

    subgraph "IBC Modules"
        TRANSFER[x/ibc-transfer]
        ICA[x/ica]
    end

    subgraph "Custom Module"
        POKER[x/poker]
    end

    POKER --> BANK
    POKER --> AUTH
    POKER --> STAKING

    ICA --> AUTH
    TRANSFER --> BANK

    style POKER fill:#667eea
    style BANK fill:#4fc08d
    style AUTH fill:#4fc08d
```

---

## Network Infrastructure

### Production Topology

```mermaid
flowchart TB
    subgraph "Internet"
        USERS[Users/Players]
    end

    subgraph "node.texashodl.net"
        NGINX[Nginx<br/>:443 SSL]

        subgraph "Services"
            CHAIN[pokerchaind<br/>Cosmos Node]
            WSSERVER[ws-server<br/>:8585]
            PVMENGINE[PVM Engine<br/>:8545]
        end

        subgraph "Ports"
            P26657[":26657<br/>Tendermint RPC"]
            P9090[":9090<br/>gRPC"]
            P1317[":1317<br/>REST API"]
            P26656[":26656<br/>P2P"]
        end
    end

    subgraph "node1.block52.xyz"
        VAL1[Validator Node<br/>pokerchaind]
    end

    USERS --> NGINX
    NGINX --> P26657
    NGINX --> WSSERVER
    NGINX --> P1317

    CHAIN --> P26657
    CHAIN --> P9090
    CHAIN --> P1317
    CHAIN --> P26656

    WSSERVER --> P26657
    WSSERVER --> P9090

    VAL1 <--> P26656

    style NGINX fill:#009639
    style CHAIN fill:#00d4aa
    style WSSERVER fill:#4fc08d
    style PVMENGINE fill:#ff6b6b
```

### Reverse Proxy Routes

```mermaid
flowchart LR
    subgraph "External URLs"
        WS_URL["wss://node.texashodl.net/ws"]
        RPC_URL["https://node.texashodl.net/rpc"]
        API_URL["https://node.texashodl.net/api"]
    end

    subgraph "Nginx Routes"
        WS_ROUTE["/ws<br/>WebSocket Upgrade"]
        RPC_ROUTE["/rpc<br/>Tendermint RPC"]
        API_ROUTE["/api<br/>REST API"]
    end

    subgraph "Internal Services"
        WS_INT["127.0.0.1:8585"]
        RPC_INT["127.0.0.1:26657"]
        API_INT["127.0.0.1:1317"]
    end

    WS_URL --> WS_ROUTE --> WS_INT
    RPC_URL --> RPC_ROUTE --> RPC_INT
    API_URL --> API_ROUTE --> API_INT

    style WS_ROUTE fill:#4fc08d
    style RPC_ROUTE fill:#00d4aa
    style API_ROUTE fill:#00d4aa
```

---

## Game Action Flows

### Join Game Flow

When a player joins a poker game:

```mermaid
sequenceDiagram
    participant UI as React UI
    participant SDK as Block52 SDK
    participant RPC as Tendermint RPC
    participant KEEPER as Poker Keeper
    participant BANK as Bank Keeper
    participant PVM as Poker VM Engine
    participant WS as WebSocket Server

    UI->>SDK: joinGame(gameId, seat, buyInAmount)
    SDK->>RPC: BroadcastTx(MsgJoinGame)

    RPC->>KEEPER: JoinGame(ctx, msg)

    Note over KEEPER: Validate player address
    Note over KEEPER: Check game exists
    Note over KEEPER: Verify buy-in limits

    KEEPER->>BANK: Check player balance
    BANK-->>KEEPER: Balance OK

    KEEPER->>BANK: SendCoinsFromAccountToModule()
    Note over BANK: Transfer buy-in to module

    KEEPER->>PVM: callGameEngine("join", seat, amount)
    PVM->>PVM: Update game state
    PVM-->>KEEPER: Updated state JSON

    KEEPER->>KEEPER: Store updated GameState
    KEEPER->>KEEPER: Add player to game.Players

    Note over KEEPER: EmitEvent("player_joined_game")

    KEEPER-->>RPC: MsgJoinGameResponse
    RPC-->>SDK: TxResult
    SDK-->>UI: Transaction hash

    Note over RPC: Tendermint broadcasts event

    RPC->>WS: Event: player_joined_game
    WS->>WS: Query updated game state
    WS->>UI: Broadcast to subscribers

    UI->>UI: Update game display
```

### Perform Action Flow

When a player performs a poker action (bet, call, raise, fold, etc.):

```mermaid
sequenceDiagram
    participant UI as React UI
    participant SDK as Block52 SDK
    participant RPC as Tendermint RPC
    participant KEEPER as Poker Keeper
    participant PVM as Poker VM Engine
    participant WS as WebSocket Server

    UI->>SDK: performAction(gameId, "raise", amount)
    SDK->>RPC: BroadcastTx(MsgPerformAction)

    RPC->>KEEPER: PerformAction(ctx, msg)

    Note over KEEPER: Validate player address
    Note over KEEPER: Validate action type
    Note over KEEPER: Check game exists

    KEEPER->>KEEPER: Fetch GameState
    KEEPER->>KEEPER: Fetch Game options

    alt action == "new-hand"
        KEEPER->>KEEPER: InitializeAndShuffleDeck()
        Note over KEEPER: Generate deterministic<br/>deck from block hash
    end

    KEEPER->>PVM: JSON-RPC perform_action
    Note over PVM: params: [playerId, gameId,<br/>action, amount, index,<br/>gameState, gameOptions,<br/>seatData, timestamp]

    PVM->>PVM: Execute poker logic
    PVM->>PVM: Update game state
    PVM-->>KEEPER: {data: updatedState, signature}

    KEEPER->>KEEPER: Store updated GameState

    Note over KEEPER: EmitEvent("action_performed")

    KEEPER-->>RPC: MsgPerformActionResponse
    RPC-->>SDK: TxResult
    SDK-->>UI: Transaction hash

    Note over RPC: Tendermint broadcasts event

    RPC->>WS: Event: action_performed
    WS->>WS: Query updated game state
    WS->>UI: Broadcast to subscribers

    UI->>UI: Update game display
```

### Leave Game Flow

When a player leaves a poker game:

```mermaid
sequenceDiagram
    participant UI as React UI
    participant SDK as Block52 SDK
    participant RPC as Tendermint RPC
    participant KEEPER as Poker Keeper
    participant BANK as Bank Keeper
    participant PVM as Poker VM Engine
    participant WS as WebSocket Server

    UI->>SDK: leaveGame(gameId)
    SDK->>RPC: BroadcastTx(MsgLeaveGame)

    RPC->>KEEPER: LeaveGame(ctx, msg)

    Note over KEEPER: Validate player address
    Note over KEEPER: Check game exists
    Note over KEEPER: Verify player in game

    KEEPER->>KEEPER: Get GameState
    KEEPER->>KEEPER: Find player's chip stack

    KEEPER->>PVM: callGameEngine("leave", seat)
    PVM->>PVM: Remove player from state
    PVM-->>KEEPER: Updated state

    alt playerStack > 0
        KEEPER->>BANK: SendCoinsFromModuleToAccount()
        Note over BANK: Refund chips to player
        BANK-->>KEEPER: Refund complete
    end

    KEEPER->>KEEPER: Remove player from game.Players
    KEEPER->>KEEPER: Store updated game

    Note over KEEPER: EmitEvent("player_left_game")

    KEEPER-->>RPC: MsgLeaveGameResponse
    RPC-->>SDK: TxResult
    SDK-->>UI: Transaction hash

    Note over RPC: Tendermint broadcasts event

    RPC->>WS: Event: player_left_game
    WS->>WS: Query updated game state
    WS->>UI: Broadcast to subscribers

    UI->>UI: Update game display
```

---

## WebSocket Real-Time Updates

### Event Flow Architecture

```mermaid
flowchart TB
    subgraph "Cosmos SDK Layer"
        TX[Transaction Execution]
        EM[Event Manager]
        TM[Tendermint]
    end

    subgraph "Event Types"
        E1[action_performed]
        E2[player_joined_game]
        E3[player_left_game]
        E4[game_created]
    end

    subgraph "WebSocket Server"
        SUB[Tendermint Subscriber]
        HUB[Game Hub]
        CLIENTS[Client Connections]
    end

    subgraph "UI Clients"
        P1[Player 1]
        P2[Player 2]
        P3[Player 3]
    end

    TX --> EM
    EM --> E1 & E2 & E3 & E4
    E1 & E2 & E3 & E4 --> TM

    TM --> SUB
    SUB --> HUB
    HUB --> CLIENTS

    CLIENTS --> P1 & P2 & P3

    style EM fill:#667eea
    style HUB fill:#4fc08d
    style TM fill:#00d4aa
```

### WebSocket Subscription Flow

```mermaid
sequenceDiagram
    participant C as Client (Browser)
    participant WS as WebSocket Server
    participant TM as Tendermint
    participant GRPC as gRPC (Game Queries)

    C->>WS: Connect ws://localhost:8585/ws
    WS-->>C: Connection established

    C->>WS: {"type": "subscribe", "game_id": "0x123..."}

    WS->>GRPC: Query game state
    GRPC-->>WS: Current game state

    WS-->>C: {"event": "state", "data": {...}}

    Note over WS,TM: Background subscription active

    loop On Blockchain Events
        TM->>WS: Event: action_performed
        WS->>GRPC: Query updated state
        GRPC-->>WS: New game state
        WS-->>C: {"event": "action", "data": {...}}
    end

    C->>WS: {"type": "unsubscribe", "game_id": "0x123..."}
    WS-->>C: Unsubscribed
```

### Tendermint Event Subscription

The WebSocket server subscribes to Tendermint events:

```mermaid
flowchart LR
    subgraph "Tendermint WebSocket"
        TMWS["ws://localhost:26657/websocket"]
    end

    subgraph "Event Queries"
        Q1["tm.event='Tx' AND<br/>action_performed.game_id EXISTS"]
        Q2["tm.event='Tx' AND<br/>player_joined_game.game_id EXISTS"]
        Q3["tm.event='Tx' AND<br/>game_created.game_id EXISTS"]
    end

    subgraph "WS Server Processing"
        PARSE[Parse Event]
        EXTRACT[Extract game_id]
        BROADCAST[Broadcast to Subscribers]
    end

    TMWS --> Q1 & Q2 & Q3
    Q1 & Q2 & Q3 --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> BROADCAST

    style TMWS fill:#00d4aa
    style BROADCAST fill:#4fc08d
```

---

## Reverse Proxy Configuration

### Nginx Configuration for node.texashodl.net

```nginx
# WebSocket endpoint with upgrade support
location /ws {
    proxy_pass http://127.0.0.1:8585/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;  # 24 hours for long-lived connections
}

# Tendermint RPC
location /rpc {
    proxy_pass http://127.0.0.1:26657/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
}

# REST API
location /api {
    proxy_pass http://127.0.0.1:1317/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
}

# gRPC (if using grpc-web)
location /grpc {
    grpc_pass grpc://127.0.0.1:9090;
}
```

### Service Port Summary

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| WebSocket Server | 8585 | HTTP/WS | Real-time game updates |
| Tendermint RPC | 26657 | HTTP/WS | Blockchain RPC |
| gRPC | 9090 | gRPC | Direct blockchain queries |
| REST API | 1317 | HTTP | Cosmos REST endpoints |
| P2P | 26656 | TCP | Validator communication |
| Poker VM | 8545 | HTTP | Game engine JSON-RPC |

### Connection Flow Diagram

```mermaid
flowchart TB
    subgraph "Client"
        BROWSER[Browser/App]
    end

    subgraph "External (HTTPS/WSS)"
        EXT443["node.texashodl.net:443"]
    end

    subgraph "Nginx"
        SSL[SSL Termination]
        ROUTE[Route Matching]
    end

    subgraph "Internal Services"
        WS8585["ws-server :8585"]
        RPC26657["tendermint :26657"]
        REST1317["rest-api :1317"]
        GRPC9090["grpc :9090"]
    end

    BROWSER -->|"wss://node.texashodl.net/ws"| EXT443
    BROWSER -->|"https://node.texashodl.net/rpc"| EXT443

    EXT443 --> SSL
    SSL --> ROUTE

    ROUTE -->|"/ws"| WS8585
    ROUTE -->|"/rpc"| RPC26657
    ROUTE -->|"/api"| REST1317
    ROUTE -->|"/grpc"| GRPC9090

    style SSL fill:#009639
    style ROUTE fill:#009639
```

---

## SDK Integration Points

### UI to Blockchain Communication

```mermaid
flowchart LR
    subgraph "React UI Hooks"
        H1[useNewTable]
        H2[usePlayerJoin]
        H3[usePerformAction]
        H4[useLeaveGame]
    end

    subgraph "Block52 SDK"
        SC[SigningCosmosClient]
        methods["createGame()<br/>joinGame()<br/>performAction()<br/>leaveGame()"]
    end

    subgraph "Transport"
        RPC[Tendermint RPC]
        REST[REST API]
    end

    subgraph "Blockchain"
        MSGS["MsgCreateGame<br/>MsgJoinGame<br/>MsgPerformAction<br/>MsgLeaveGame"]
    end

    H1 & H2 & H3 & H4 --> SC
    SC --> methods
    methods --> RPC
    methods --> REST
    RPC --> MSGS

    style SC fill:#f7df1e
    style MSGS fill:#667eea
```

---

## Summary

The Pokerchain architecture consists of:

1. **Frontend**: React UI using Block52 SDK for blockchain interactions
2. **Reverse Proxy**: Nginx handling SSL and routing to internal services
3. **WebSocket Server**: Real-time game updates via Tendermint event subscription
4. **Cosmos Blockchain**: Poker keeper managing game state and token transfers
5. **Poker VM**: External game engine for poker logic validation
6. **Base Chain Bridge**: USDC deposit/withdrawal integration

Events flow from blockchain transactions through Tendermint, to the WebSocket server, and finally to subscribed UI clients for real-time updates.
