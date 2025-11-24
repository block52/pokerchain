# WebSocket Server for Poker Game Updates

A real-time WebSocket server that allows players to subscribe to poker game updates. When game state changes (actions, joins, leaves), all subscribed clients receive instant notifications.

## Features

- 🎮 **Game-based subscriptions** - Subscribe to specific game IDs
- 📡 **Real-time broadcasts** - Instant updates when game state changes
- 🔄 **Auto-reconnect support** - Ping/pong keep-alive mechanism
- 📊 **Health monitoring** - HTTP endpoint for service health checks
- 🧪 **Manual triggers** - Test endpoint for debugging

## How It Works

1. **Client connects** to `ws://localhost:8585/ws`
2. **Client subscribes** to game ID(s) they want to monitor
3. **Server queries** blockchain for current game state and sends it
4. **On mutations** (perform action, join/leave game), server broadcasts updates
5. **All subscribers** receive the new game state in real-time

## Installation

From the pokerchain root directory:

```bash
go build -o ws-server ./cmd/ws-server
```

## Usage

### Start the Server

```bash
./ws-server
```

Output:
```
Connecting to blockchain via gRPC...
WebSocket server starting on :8585
WebSocket endpoint: ws://localhost:8585/ws
Health check: http://localhost:8585/health
```

### Client Protocol

Clients communicate with JSON messages:

#### Subscribe to a Game

```json
{
  "type": "subscribe",
  "game_id": "0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1"
}
```

#### Unsubscribe from a Game

```json
{
  "type": "unsubscribe",
  "game_id": "0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1"
}
```

#### Ping (Keep-Alive)

```json
{
  "type": "ping"
}
```

Response:
```json
{
  "type": "pong"
}
```

### Server Messages

When game state changes, server sends:

```json
{
  "game_id": "0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1",
  "timestamp": "2024-11-24T18:56:00Z",
  "event": "action",
  "data": {
    "game_id": "0x89a7c...",
    "status": "active",
    "players": [...],
    "pot": 5000000,
    ...
  }
}
```

**Event types:**
- `state` - Initial state when subscribing
- `action` - Player performed an action
- `join` - Player joined the game
- `leave` - Player left the game
- `state_change` - General state change

## HTTP Endpoints

### Health Check

```bash
curl http://localhost:8585/health
```

Response:
```json
{
  "status": "ok",
  "clients": 3,
  "active_games": 2
}
```

### Manual Trigger (Testing)

Manually trigger a broadcast for testing:

```bash
curl "http://localhost:8585/trigger?game_id=0x89a7c...771df1&event=action"
```

## Integration with Poker Scripts

When you perform actions, the server will automatically broadcast updates:

```bash
# Join a game
./join-game 0x89a7c...771df1 1 500000000
# Server broadcasts "join" event to all subscribers

# Perform an action
./perform-action 0x89a7c...771df1 raise 5000000
# Server broadcasts "action" event to all subscribers

# Leave a game
./leave-game 0x89a7c...771df1
# Server broadcasts "leave" event to all subscribers
```

## JavaScript Client Example

```javascript
const ws = new WebSocket('ws://localhost:8585/ws');

ws.onopen = () => {
  console.log('Connected to WebSocket server');

  // Subscribe to a game
  ws.send(JSON.stringify({
    type: 'subscribe',
    game_id: '0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1'
  }));
};

ws.onmessage = (event) => {
  const update = JSON.parse(event.data);
  console.log('Game update:', update);

  if (update.event === 'action') {
    console.log('Player performed action!');
    updateGameUI(update.data);
  }
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('Disconnected from server');
};
```

## Go Client Example

```go
package main

import (
    "encoding/json"
    "log"
    "github.com/gorilla/websocket"
)

func main() {
    conn, _, err := websocket.DefaultDialer.Dial("ws://localhost:8585/ws", nil)
    if err != nil {
        log.Fatal(err)
    }
    defer conn.Close()

    // Subscribe
    sub := map[string]string{
        "type":    "subscribe",
        "game_id": "0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1",
    }
    conn.WriteJSON(sub)

    // Read updates
    for {
        var update map[string]interface{}
        err := conn.ReadJSON(&update)
        if err != nil {
            log.Println("read:", err)
            return
        }
        log.Printf("Received: %+v", update)
    }
}
```

## Architecture

```
┌─────────────┐
│  Client 1   │ ─┐
└─────────────┘  │
                 │  Subscribe to Game A
┌─────────────┐  │
│  Client 2   │ ─┼──────> ┌──────────────┐
└─────────────┘  │        │              │      ┌─────────────┐
                 │        │  WS Server   │◄─────│ Blockchain  │
┌─────────────┐  │        │              │      │   (gRPC)    │
│  Client 3   │ ─┘        │  Game Hub    │      └─────────────┘
└─────────────┘           └──────┬───────┘
                                 │
                    Broadcast ◄──┘
                    updates to
                    all subscribers
```

## Configuration

Edit `main.go` to change:

- **gRPC URL**: `node.texashodl.net:9443`
- **Address Prefix**: `b52`
- **WebSocket Port**: `:8585`
- **Poll Interval**: `2 seconds` (blockchain event polling)

## Running in Production

### Using systemd

Create `/etc/systemd/system/poker-ws.service`:

```ini
[Unit]
Description=Poker WebSocket Server
After=network.target

[Service]
Type=simple
User=poker
WorkingDirectory=/opt/poker
ExecStart=/opt/poker/ws-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable poker-ws
sudo systemctl start poker-ws
sudo systemctl status poker-ws
```

### With Nginx Proxy

Your existing nginx configuration already proxies `/ws`:

```nginx
location /ws {
    proxy_pass http://127.0.0.1:8585/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
}
```

Clients connect via:
```
wss://node.texashodl.net/ws
```

## Event Polling

Currently, the server polls the blockchain every 2 seconds for new events. To improve this:

### Option 1: Tendermint WebSocket Events

Subscribe to Tendermint events directly:

```go
import "github.com/tendermint/tendermint/rpc/client/http"

client, _ := http.New("wss://node.texashodl.net/rpc/websocket", "/websocket")
client.Start()

query := "tm.event='Tx' AND poker.action_performed.game_id EXISTS"
client.Subscribe(context.Background(), "poker-events", query)
```

### Option 2: Block Scanning

Scan new blocks for poker module events:

```go
// Query latest block
// Scan for events: action_performed, player_joined, player_left
// Extract game_id from event attributes
// Broadcast to subscribers
```

## Monitoring

Check server metrics:

```bash
# Health check
curl http://localhost:8585/health

# Check active connections
watch -n 1 'curl -s http://localhost:8585/health | jq'

# View logs
tail -f /var/log/poker-ws.log
```

## Testing

See `test-client.html` for a browser-based test client.

Open in browser and connect to test the WebSocket server:
```bash
open cmd/ws-server/test-client.html
```

## Troubleshooting

### "Connection refused"

- Check if server is running: `lsof -i :8585`
- Check firewall rules
- Verify gRPC connection to blockchain

### "No updates received"

- Verify game ID exists: `curl https://node.texashodl.net/pokerchain/poker/v1/game/<game_id>`
- Check if subscribed: Send subscribe message again
- Trigger manual update: `curl "http://localhost:8585/trigger?game_id=<id>&event=test"`

### High memory usage

- Check number of connected clients
- Verify old connections are being closed
- Consider connection limits in production

## Future Enhancements

- [ ] Authentication/authorization for subscriptions
- [ ] Rate limiting per client
- [ ] Message compression
- [ ] Player-specific subscriptions (only show player's cards)
- [ ] Replay last N events for new subscribers
- [ ] Redis pub/sub for horizontal scaling
- [ ] Prometheus metrics export

## Related

- `cmd/poker-cli/` - Interactive poker client
- `cmd/perform-action/` - Perform poker actions
- `cmd/join-game/` - Join games
- `setup-nginx.sh` - Nginx WebSocket configuration
