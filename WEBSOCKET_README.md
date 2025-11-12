# WebSocket Subscriptions for Game State Updates

This document describes the WebSocket subscription system for real-time game state updates in Pokerchain.

## Overview

The WebSocket system allows clients to subscribe to game state changes for specific poker tables. When any action occurs (player action, round change, etc.), all subscribed clients receive immediate updates without polling.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Client Application                    │
│          (TypeScript SDK with WebSocket helper)         │
└────────────────────┬────────────────────────────────────┘
                     │ ws://localhost:3000/ws/game/{gameId}
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Custom WebSocket Server                     │
│  - Game-specific subscription management                │
│  - Player authentication & filtering                    │
│  - Event transformation & privacy filtering             │
└────────────────────┬────────────────────────────────────┘
                     │ ws://localhost:26657/websocket
                     ▼
┌─────────────────────────────────────────────────────────┐
│           CometBFT WebSocket (Native)                   │
│  - Blockchain event stream                              │
│  - Query: tm.event='Tx' AND message.module='poker'     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Poker Module Keeper                        │
│  - EmitEvent on state changes                           │
│  - game_state_updated, player_joined_game               │
└─────────────────────────────────────────────────────────┘
```

## Features

- ✅ **Table-specific subscriptions**: Subscribe to `/ws/game/{gameId}` for updates
- ✅ **Automatic reconnection**: Client SDK handles connection drops
- ✅ **Event types**:
  - `game_created` - New game created
  - `player_joined_game` - Player joined
  - `game_state_updated` - Game state changed (actions, round changes)
- ✅ **Real-time updates**: Sub-second latency from blockchain to client
- ✅ **Type-safe TypeScript client**: Full TypeScript support with types
- ✅ **React hooks**: Easy integration with React applications

## Go Server Implementation

### Starting the WebSocket Server

The WebSocket server can be started standalone or integrated with the main application.

#### Option 1: Start with the Application (Recommended)

Add to your `app/app.go`:

```go
import (
    "github.com/block52/pokerchain/x/poker/websocket"
)

// In the App struct
type App struct {
    // ... existing fields ...
    WebSocketManager *websocket.Manager
}

// In NewApp or after app initialization
wsConfig := websocket.Config{
    Enabled:        true,
    CometBftRpcUrl: "tcp://localhost:26657",
    ListenPort:     ":3000",
}

wsManager, err := websocket.NewManager(wsConfig)
if err != nil {
    panic(fmt.Sprintf("Failed to create WebSocket manager: %v", err))
}

if err := wsManager.Start(); err != nil {
    panic(fmt.Sprintf("Failed to start WebSocket server: %v", err))
}

app.WebSocketManager = wsManager

// Optionally register with API server
func (app *App) RegisterAPIRoutes(apiSvr *api.Server, apiConfig config.APIConfig) {
    app.App.RegisterAPIRoutes(apiSvr, apiConfig)

    // Register WebSocket routes
    if app.WebSocketManager != nil {
        app.WebSocketManager.RegisterRoutes(apiSvr, apiConfig)
    }
}
```

#### Option 2: Standalone Server

Create a simple command to run the WebSocket server:

```go
package main

import (
    "fmt"
    "os"
    "os/signal"
    "syscall"

    "github.com/block52/pokerchain/x/poker/websocket"
)

func main() {
    config := websocket.Config{
        Enabled:        true,
        CometBftRpcUrl: "tcp://localhost:26657",
        ListenPort:     ":3000",
    }

    manager, err := websocket.NewManager(config)
    if err != nil {
        panic(err)
    }

    if err := manager.Start(); err != nil {
        panic(err)
    }

    fmt.Println("WebSocket server running on :3000")

    // Wait for interrupt signal
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan

    fmt.Println("Shutting down...")
    manager.Stop()
}
```

### Configuration

Configuration can be added to `app.toml`:

```toml
[websocket]
# Enable WebSocket server
enabled = true

# CometBFT RPC URL
cometbft_rpc_url = "tcp://localhost:26657"

# WebSocket server listen port
listen_port = ":3000"
```

### Events Emitted

The following events are emitted by the poker keeper:

**1. game_created** (`x/poker/keeper/msg_server_create_game.go:126-137`)
```go
sdk.NewEvent(
    "game_created",
    sdk.NewAttribute("game_id", gameId),
    sdk.NewAttribute("creator", msg.Creator),
    sdk.NewAttribute("game_type", msg.GameType),
    // ...
)
```

**2. player_joined_game** (`x/poker/keeper/msg_server_join_game.go:143-151`)
```go
sdk.NewEvent(
    "player_joined_game",
    sdk.NewAttribute("game_id", msg.GameId),
    sdk.NewAttribute("player", msg.Player),
    sdk.NewAttribute("seat", fmt.Sprintf("%d", msg.Seat)),
    sdk.NewAttribute("buy_in_amount", fmt.Sprintf("%d", msg.BuyInAmount)),
)
```

**3. game_state_updated** (`x/poker/keeper/msg_server_perform_action.go:246-259`) - **NEW**
```go
sdk.NewEvent(
    "game_state_updated",
    sdk.NewAttribute("game_id", gameId),
    sdk.NewAttribute("player", playerId),
    sdk.NewAttribute("action", action),
    sdk.NewAttribute("amount", strconv.FormatUint(amount, 10)),
    sdk.NewAttribute("round", string(updatedGameState.Round)),
    sdk.NewAttribute("next_to_act", strconv.Itoa(updatedGameState.NextToAct)),
    sdk.NewAttribute("action_count", strconv.Itoa(updatedGameState.ActionCount)),
    sdk.NewAttribute("hand_number", strconv.Itoa(updatedGameState.HandNumber)),
)
```

## TypeScript Client Usage

### Installation

The WebSocket client is included in the generated TypeScript SDK:

```bash
# From pokerchain repo root
ignite generate ts-client

# Copy to your app's SDK directory
cp -r ts-client/* ../poker-vm/sdk/src/
```

### Basic Usage

```typescript
import { PokerWebSocketClient } from '@block52/pokerchain-sdk';

// Create client
const wsClient = new PokerWebSocketClient('ws://localhost:3000');

// Subscribe to a game
wsClient.subscribeToGame('0x123...', (event) => {
  console.log('Event type:', event.type);
  console.log('Game ID:', event.game_id);
  console.log('Player:', event.player);
  console.log('Action:', event.action);
  console.log('Round:', event.round);
  console.log('Next to act:', event.next_to_act);
});

// Later, unsubscribe
wsClient.unsubscribeFromGame('0x123...');
```

### Advanced Options

```typescript
const wsClient = new PokerWebSocketClient('ws://localhost:3000', {
  autoReconnect: true,           // Automatically reconnect on disconnect
  reconnectDelay: 3000,          // Wait 3s before reconnecting
  maxReconnectAttempts: 10,      // Try max 10 times (0 = infinite)
  pingInterval: 30000,           // Send ping every 30s to keep alive
});

// Global error handler
wsClient.onError((error) => {
  console.error('WebSocket error:', error);
});

// Connection handlers
wsClient.onConnect(() => {
  console.log('Connected!');
});

wsClient.onDisconnect(() => {
  console.log('Disconnected!');
});

// Check connection status
if (wsClient.isConnected('0x123...')) {
  console.log('Connected to game 0x123...');
}
```

### React Hook Usage

For React applications, use the provided hook:

```typescript
import { usePokerWebSocket } from '@block52/pokerchain-sdk';

function GameComponent({ gameId }: { gameId: string }) {
  const { gameState, events, isConnected, error, reconnect, clearEvents } =
    usePokerWebSocket(gameId);

  if (error) {
    return (
      <div>
        Error: {error.message}
        <button onClick={reconnect}>Reconnect</button>
      </div>
    );
  }

  if (!isConnected) {
    return <div>Connecting to game...</div>;
  }

  return (
    <div>
      <h2>Game {gameState?.game_id}</h2>
      <p>Round: {gameState?.round}</p>
      <p>Action Count: {gameState?.action_count}</p>
      <p>Next to Act: Player {gameState?.next_to_act}</p>

      <h3>Recent Events ({events.length})</h3>
      <button onClick={clearEvents}>Clear Events</button>
      <ul>
        {events.map((event, idx) => (
          <key={idx}>
            {event.type} - {event.action} by {event.player}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Multiple Games

Subscribe to multiple games at once:

```typescript
import { useMultipleGames } from '@block52/pokerchain-sdk';

function MultiTableView() {
  const gameIds = ['0x123...', '0x456...', '0x789...'];
  const games = useMultipleGames(gameIds);

  return (
    <div>
      {gameIds.map(gameId => {
        const { gameState, isConnected } = games[gameId] || {};

        return (
          <div key={gameId}>
            <h3>{gameId}</h3>
            <p>Status: {isConnected ? 'Connected' : 'Disconnected'}</p>
            <p>Round: {gameState?.round}</p>
          </div>
        );
      })}
    </div>
  );
}
```

## Event Types

### GameStateEvent Interface

```typescript
interface GameStateEvent {
  type: string;              // Event type: game_created, player_joined_game, game_state_updated
  game_id: string;           // Game identifier
  player?: string;           // Player address (if applicable)
  action?: string;           // Action performed (fold, check, bet, call, raise, all-in)
  amount?: string;           // Amount in action (for bet/raise)
  round?: string;            // Current round (ante, preflop, flop, turn, river, showdown)
  next_to_act?: string;      // Seat number of next player to act
  action_count?: string;     // Total actions in this hand
  hand_number?: string;      // Current hand number
  timestamp: string;         // Event timestamp (ISO 8601)
  block_height: number;      // Blockchain block height
  tx_hash: string;           // Transaction hash
  raw_data?: Record<string, any>; // Additional event attributes
}
```

### Event Flow Example

```
1. Player joins game
   → Event: player_joined_game

2. Game starts, small blind posted
   → Event: game_state_updated (action=post-small-blind, round=ante)

3. Big blind posted
   → Event: game_state_updated (action=post-big-blind, round=ante)

4. Player 1 raises
   → Event: game_state_updated (action=raise, amount=100, round=preflop)

5. Player 2 calls
   → Event: game_state_updated (action=call, amount=100, round=preflop)

6. Flop dealt
   → Event: game_state_updated (round=flop)

... and so on
```

## Testing

### Manual Testing with wscat

Install `wscat`:
```bash
npm install -g wscat
```

Connect to a game:
```bash
wscat -c ws://localhost:3000/ws/game/0x123...
```

You'll receive a welcome message:
```json
{
  "type": "connection_established",
  "game_id": "0x123...",
  "timestamp": "2025-11-12T12:00:00Z"
}
```

Perform actions in the game (via CLI or API), and you'll see events:
```json
{
  "type": "game_state_updated",
  "game_id": "0x123...",
  "player": "b521abc...",
  "action": "raise",
  "amount": "100",
  "round": "preflop",
  "next_to_act": "1",
  "action_count": "3",
  "hand_number": "1",
  "timestamp": "2025-11-12T12:00:05Z",
  "block_height": 1234,
  "tx_hash": "ABC123..."
}
```

### Testing with CometBFT WebSocket

You can also subscribe directly to CometBFT's WebSocket:

```bash
wscat -c ws://localhost:26657/websocket
```

Subscribe to poker events:
```json
{
  "jsonrpc": "2.0",
  "method": "subscribe",
  "params": ["tm.event='Tx' AND message.module='poker'"],
  "id": 1
}
```

Subscribe to specific game:
```json
{
  "jsonrpc": "2.0",
  "method": "subscribe",
  "params": ["tm.event='Tx' AND game_id='0x123...'"],
  "id": 1
}
```

## Production Considerations

### Security

1. **Origin Checking**: Update `CheckOrigin` in `server.go` for production:
```go
upgrader: websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {
        origin := r.Header.Get("Origin")
        // Only allow your domains
        return origin == "https://yourapp.com"
    },
}
```

2. **Rate Limiting**: Add rate limiting for WebSocket connections
3. **Authentication**: Implement JWT or session-based auth for WebSocket connections

### Scaling

- **Multiple WebSocket Servers**: Run multiple WebSocket servers behind a load balancer
- **Redis PubSub**: Use Redis for event distribution across multiple server instances
- **Connection Limits**: Set max connections per server

### Monitoring

- Track active connections per game
- Monitor event delivery latency
- Log reconnection attempts
- Alert on high error rates

## Troubleshooting

### Client can't connect

```
Error: WebSocket connection failed
```

**Solution**: Ensure WebSocket server is running on the correct port:
```bash
curl http://localhost:3000/health
# Should return: {"status":"ok","service":"poker-websocket"}
```

### No events received

**Solution**: Verify CometBFT is accessible:
```bash
curl http://localhost:26657/status
```

Check that events are being emitted:
```bash
pokerchaind query txs --events 'message.module=poker' --limit 10
```

### Connection drops frequently

**Solution**: Adjust ping interval in client options:
```typescript
const wsClient = new PokerWebSocketClient('ws://localhost:3000', {
  pingInterval: 15000,  // Ping more frequently
});
```

## File Reference

### Go Implementation
- `x/poker/websocket/server.go` - WebSocket server core
- `x/poker/websocket/handler.go` - HTTP handlers
- `x/poker/websocket/integration.go` - Integration helpers
- `x/poker/keeper/msg_server_perform_action.go:246-259` - Event emission

### TypeScript Client
- `ts-client/websocket-client.ts` - WebSocket client
- `ts-client/usePokerWebSocket.ts` - React hooks
- `ts-client/index.ts` - Exports

## Next Steps

1. ✅ Events added to `PerformAction` handler
2. ✅ WebSocket server implemented
3. ✅ TypeScript client and React hooks created
4. ⏳ Integrate WebSocket server with app startup
5. ⏳ Add authentication for private data (hole cards)
6. ⏳ Add event history replay on reconnect
7. ⏳ Performance testing with concurrent connections

## Support

For issues or questions:
- GitHub: https://github.com/block52/pokerchain/issues
- Documentation: See `CLAUDE.md` for general project info
