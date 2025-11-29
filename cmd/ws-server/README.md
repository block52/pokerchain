# Poker WebSocket Server

Real-time WebSocket server that bridges the Pokerchain blockchain with web clients, enabling live game state updates.

## Architecture Overview

```mermaid
flowchart TB
    subgraph "Blockchain Layer"
        PC[("Pokerchain Node<br/>pokerchaind")]
        TM["Tendermint RPC<br/>:26657/websocket"]
        GRPC["gRPC Server<br/>:9090"]
    end

    subgraph "WebSocket Server<br/>:8585"
        WS["HTTP Server<br/>/ws /health /trigger"]
        HUB["Hub<br/>Connection Manager"]
        TMS["Tendermint<br/>Event Subscriber"]
        QC["Query Client<br/>poker.QueryClient"]
    end

    subgraph "Poker UI Clients"
        UI1["Player 1<br/>Browser"]
        UI2["Player 2<br/>Browser"]
        UI3["Player 3<br/>Browser"]
    end

    PC --> TM
    PC --> GRPC
    TM -->|"Tx Events<br/>(action_performed, player_joined)"| TMS
    GRPC -->|"Game State Queries"| QC
    TMS -->|"Notify"| HUB
    QC -->|"State Data"| HUB
    HUB <-->|"Manage"| WS
    WS <-->|"ws://"| UI1
    WS <-->|"ws://"| UI2
    WS <-->|"ws://"| UI3

    style PC fill:#e8f5e9
    style HUB fill:#fff3e0
    style WS fill:#e3f2fd
```

## How It Works

### Complete Event Flow: Player Action to UI Update

```mermaid
sequenceDiagram
    autonumber
    participant P1 as Player 1 (Actor)
    participant UI as Poker UI
    participant Chain as Pokerchain
    participant TM as Tendermint WS
    participant WSS as WS Server
    participant Hub as Hub
    participant P2 as Player 2 (Viewer)

    Note over P1,P2: Player 1 performs a RAISE action

    P1->>UI: Click "Raise $100"
    UI->>Chain: MsgPerformAction<br/>{game_id, RAISE, 100}
    Chain->>Chain: Execute poker logic
    Chain->>Chain: Emit event:<br/>action_performed
    Chain-->>UI: Tx Success

    Note over TM,Hub: Real-time broadcast begins

    Chain->>TM: Broadcast block with events
    TM->>WSS: Event notification<br/>{action_performed.game_id: "game123"}
    WSS->>Hub: processBlockEvent()
    Hub->>Chain: Query game state via gRPC
    Chain-->>Hub: Full game JSON
    Hub->>Hub: Create GameUpdate message
    Hub->>P2: Broadcast to all subscribers<br/>of game123
    P2->>P2: UI updates automatically

    Note over P1,P2: All players see the raise instantly
```

### Client Connection & Subscription Flow

```mermaid
sequenceDiagram
    participant Client as Poker UI
    participant WS as /ws endpoint
    participant Hub as Hub
    participant GRPC as Pokerchain gRPC

    Note over Client,GRPC: Connection Phase
    Client->>WS: Connect ws://localhost:8585/ws
    WS->>WS: Upgrade HTTP to WebSocket
    WS->>Hub: register <- client
    Hub->>Hub: Add to clients map
    Hub-->>Client: Connection established

    Note over Client,GRPC: Subscription Phase
    Client->>WS: {"type": "subscribe", "game_id": "game123"}
    WS->>Hub: subscribe <- {client, "game123"}
    Hub->>Hub: Add client to games["game123"]
    Hub->>GRPC: QueryGame("game123")
    GRPC-->>Hub: Game state JSON
    Hub->>Client: {"event": "state", "data": {...}}

    Note over Client,GRPC: Active Subscription
    loop On blockchain events
        Hub->>Client: {"event": "action_performed", "data": {...}}
    end

    Note over Client,GRPC: Cleanup Phase
    Client->>WS: {"type": "unsubscribe", "game_id": "game123"}
    WS->>Hub: unsubscribe <- {client, "game123"}
    Hub->>Hub: Remove from games["game123"]

    Client->>WS: Connection closes
    WS->>Hub: unregister <- client
    Hub->>Hub: Remove from all subscriptions
    Hub->>Hub: Close send channel
```

## Component Architecture

### Hub: The Central Nervous System

```mermaid
classDiagram
    class Hub {
        -clients: map[*Client]bool
        -games: map[string]map[*Client]bool
        -broadcast: chan *GameUpdate
        -register: chan *Client
        -unregister: chan *Client
        -subscribe: chan *Subscription
        -unsubscribe: chan *Subscription
        -grpcConn: *grpc.ClientConn
        -queryClient: pokertypes.QueryClient
        -mu: sync.RWMutex
        +run()
        +sendGameState(client, gameID)
        +BroadcastGameUpdate(gameID, event)
    }

    class Client {
        -hub: *Hub
        -conn: *websocket.Conn
        -send: chan []byte
        -gameIDs: map[string]bool
        -mu: sync.RWMutex
        +readPump()
        +writePump()
    }

    class Subscription {
        +client: *Client
        +gameID: string
    }

    class GameUpdate {
        +GameID: string
        +Timestamp: time.Time
        +Event: string
        +Data: json.RawMessage
    }

    class ClientMessage {
        +Type: string
        +GameID: string
    }

    Hub "1" *-- "*" Client : manages
    Hub "1" ..> "*" Subscription : processes
    Hub "1" ..> "*" GameUpdate : broadcasts
    Client "*" --> "1" Hub : references
    Client ..> ClientMessage : receives
```

### Hub Event Loop (run method)

```mermaid
flowchart TB
    subgraph "Hub.run() - Infinite Select Loop"
        START((Start))
        SELECT{select}

        subgraph "Channel: register"
            REG[Add client to clients map<br/>Log: "Client registered"]
        end

        subgraph "Channel: unregister"
            UNREG[Remove from clients<br/>Unsubscribe from all games<br/>Close send channel<br/>Log: "Client unregistered"]
        end

        subgraph "Channel: subscribe"
            SUB[Add client to games[gameID]<br/>Add gameID to client.gameIDs<br/>Log: "Client subscribed"<br/>Go: sendGameState]
        end

        subgraph "Channel: unsubscribe"
            UNSUB[Remove client from games[gameID]<br/>Remove gameID from client.gameIDs<br/>Log: "Client unsubscribed"]
        end

        subgraph "Channel: broadcast"
            BCAST[Get subscribers for gameID<br/>Marshal GameUpdate to JSON<br/>Send to each client.send<br/>Log: "Broadcasted event"]
        end
    end

    START --> SELECT
    SELECT -->|"<-register"| REG
    SELECT -->|"<-unregister"| UNREG
    SELECT -->|"<-subscribe"| SUB
    SELECT -->|"<-unsubscribe"| UNSUB
    SELECT -->|"<-broadcast"| BCAST
    REG --> SELECT
    UNREG --> SELECT
    SUB --> SELECT
    UNSUB --> SELECT
    BCAST --> SELECT
```

### Goroutine Architecture

```mermaid
flowchart LR
    subgraph "Main Goroutine"
        MAIN[main]
    end

    subgraph "Shared Goroutines"
        HUB_RUN["hub.run()<br/>Event loop"]
        TM_SUB["subscribeTendermintEvents()<br/>Blockchain listener"]
    end

    subgraph "Per-Client Goroutines"
        subgraph "Client 1"
            RP1["readPump()<br/>Reads from WebSocket"]
            WP1["writePump()<br/>Writes to WebSocket"]
        end
        subgraph "Client 2"
            RP2["readPump()"]
            WP2["writePump()"]
        end
    end

    MAIN -->|"go"| HUB_RUN
    MAIN -->|"go"| TM_SUB
    MAIN -->|"per connection"| RP1 & WP1
    MAIN -->|"per connection"| RP2 & WP2

    style HUB_RUN fill:#fff3e0
    style TM_SUB fill:#e8f5e9
    style RP1 fill:#e3f2fd
    style WP1 fill:#e3f2fd
    style RP2 fill:#e3f2fd
    style WP2 fill:#e3f2fd
```

## Tendermint Event Subscription

### Event Flow from Blockchain

```mermaid
flowchart TB
    subgraph "Pokerchain Node"
        TX["Transaction Executed"]
        EMIT["Emit Cosmos SDK Events"]
        EVT1["action_performed<br/>game_id, player, action, amount"]
        EVT2["player_joined_game<br/>game_id, player, position"]
        EVT3["game_created<br/>game_id, creator"]
    end

    subgraph "Tendermint"
        TM_WS["WebSocket :26657/websocket"]
        TM_SUB["Subscription Queries"]
    end

    subgraph "WS Server"
        CONN["WebSocket Connection<br/>(auto-reconnect)"]
        PARSE["Parse TendermintEventResponse"]
        EXTRACT["Extract game_id from events"]
        BCAST["BroadcastGameUpdate()"]
    end

    TX --> EMIT
    EMIT --> EVT1 & EVT2 & EVT3
    EVT1 & EVT2 & EVT3 --> TM_WS
    TM_WS --> TM_SUB
    TM_SUB -->|"tm.event='Tx' AND<br/>action_performed.game_id EXISTS"| CONN
    CONN --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> BCAST
```

### Subscription Query Format

```mermaid
flowchart LR
    subgraph "Event Types Subscribed"
        E1["action_performed"]
        E2["player_joined_game"]
        E3["game_created"]
    end

    subgraph "Query Builder"
        QB["subscribeToEvent()"]
    end

    subgraph "Tendermint Query"
        Q["tm.event='Tx' AND<br/>{event_type}.game_id EXISTS"]
    end

    E1 --> QB
    E2 --> QB
    E3 --> QB
    QB --> Q
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GRPC_URL` | `node.texashodl.net:9443` | Pokerchain gRPC endpoint |
| `TENDERMINT_WS_URL` | `ws://localhost:26657/websocket` | Tendermint WebSocket for events |
| `WS_SERVER_PORT` | `:8585` | Port for WebSocket server |
| `ADDRESS_PREFIX` | `b52` | Bech32 address prefix |

### TLS Auto-Detection

```mermaid
flowchart LR
    URL[GRPC_URL]
    CHECK{Starts with<br/>localhost<br/>127.0.0.1<br/>0.0.0.0?}
    INSECURE["Use insecure.NewCredentials()<br/>No TLS"]
    TLS["Use credentials.NewTLS(nil)<br/>TLS enabled"]

    URL --> CHECK
    CHECK -->|Yes| INSECURE
    CHECK -->|No| TLS
```

## API Endpoints

### WebSocket: `/ws`

Connect and subscribe to game updates.

**Client Messages:**
```json
// Subscribe to a game
{"type": "subscribe", "game_id": "game_abc123"}

// Unsubscribe from a game
{"type": "unsubscribe", "game_id": "game_abc123"}

// Keep-alive ping
{"type": "ping"}
```

**Server Messages:**
```json
// Initial state on subscribe
{
  "game_id": "game_abc123",
  "timestamp": "2025-01-15T10:30:00Z",
  "event": "state",
  "data": { /* full game state */ }
}

// Game update on blockchain event
{
  "game_id": "game_abc123",
  "timestamp": "2025-01-15T10:30:05Z",
  "event": "action_performed",
  "data": { /* updated game state */ }
}

// Pong response
{"type": "pong"}
```

### HTTP: `/health`

```bash
curl http://localhost:8585/health
```

```json
{
  "status": "ok",
  "clients": 5,
  "active_games": 2,
  "grpc_url": "localhost:9090",
  "tendermint_ws": "ws://localhost:26657/websocket"
}
```

### HTTP: `/trigger`

Manual event trigger for testing:

```bash
curl "http://localhost:8585/trigger?game_id=game123&event=test"
```

## Connection Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Connecting: Client opens WebSocket
    Connecting --> Connected: Upgrade successful
    Connected --> Registered: Hub adds to clients

    Registered --> Subscribed: subscribe message
    Subscribed --> Subscribed: Receives updates
    Subscribed --> Registered: unsubscribe message

    Registered --> Disconnecting: Connection lost
    Subscribed --> Disconnecting: Connection lost

    Disconnecting --> Cleanup: unregister from Hub
    Cleanup --> [*]: Resources freed

    note right of Subscribed
        Client receives:
        1. Initial game state
        2. All subsequent updates
        3. Ping/pong keep-alive
    end note

    note right of Cleanup
        Hub removes from:
        - clients map
        - all games maps
        - closes send channel
    end note
```

## Running

### Local Development

```bash
# Option 1: Via setup-network.sh (recommended)
./setup-network.sh
# Choose 12 (Deploy WebSocket Server)
# Choose 1 (Local Development)

# Option 2: Direct with environment variables
GRPC_URL=localhost:9090 ./build/ws-server

# Option 3: Build and run
go build -o ./build/ws-server ./cmd/ws-server
./build/ws-server
```

### Production

```bash
# Deploy to remote server via setup-network.sh
./setup-network.sh
# Choose 12 (Deploy WebSocket Server)
# Choose 2 (Remote Production Server)
# Enter hostname: node1.block52.xyz
```

Creates systemd service with proper environment variables.

## JavaScript Client Example

```javascript
const ws = new WebSocket('ws://localhost:8585/ws');

ws.onopen = () => {
  console.log('Connected');

  // Subscribe to a game
  ws.send(JSON.stringify({
    type: 'subscribe',
    game_id: 'game_abc123'
  }));
};

ws.onmessage = (event) => {
  const update = JSON.parse(event.data);
  console.log(`Event: ${update.event}`, update.data);

  // Update UI based on event type
  switch(update.event) {
    case 'state':
      initializeGame(update.data);
      break;
    case 'action_performed':
      animateAction(update.data);
      break;
    case 'player_joined_game':
      addPlayer(update.data);
      break;
  }
};

ws.onclose = () => {
  console.log('Disconnected - implement reconnect logic');
};
```

## Troubleshooting

### Port Already in Use

The setup script now automatically kills existing processes:

```bash
# Manual check
lsof -i :8585

# Manual kill
kill $(lsof -t -i :8585)
```

### No Updates Received

1. Verify game exists: Query `/pokerchain/poker/v1/game/{game_id}`
2. Check subscription: Send subscribe message again
3. Test manually: `curl "http://localhost:8585/trigger?game_id=<id>&event=test"`
4. Check Tendermint connection in logs

### Connection Refused

1. Check server running: `lsof -i :8585`
2. Check gRPC connection: `grpcurl -plaintext localhost:9090 list`
3. Check Tendermint: `curl http://localhost:26657/status`

## Related Files

- `test-client.html` - Browser-based test client
- `setup-network.sh` option 12 - Deployment script
- `x/poker/keeper/` - Event emission in blockchain
