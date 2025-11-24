# WebSocket Quick Start Guide

Real-time game updates for blockchain poker using WebSocket subscriptions.

## 🚀 Quick Start

### 1. Start the WebSocket Server

```bash
./ws-server
```

You should see:
```
WebSocket server starting on :8585
WebSocket endpoint: ws://localhost:8585/ws
Health check: http://localhost:8585/health
```

### 2. Open the Test Client

Open in your browser:
```bash
open cmd/ws-server/test-client.html
```

Or navigate to: `file:///path/to/pokerchain/cmd/ws-server/test-client.html`

### 3. Connect and Subscribe

In the test client:
1. Click **Connect**
2. Enter a game ID: `0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1`
3. Click **Subscribe**

You'll receive the current game state immediately!

### 4. Trigger Updates

In another terminal, perform game actions:

```bash
# Join a game
./join-game 0x89a7c...771df1 1 500000000
./trigger-broadcast 0x89a7c...771df1 join

# Perform an action
./perform-action 0x89a7c...771df1 raise 5000000
./trigger-broadcast 0x89a7c...771df1 action

# Leave a game
./leave-game 0x89a7c...771df1
./trigger-broadcast 0x89a7c...771df1 leave
```

All subscribed clients receive updates instantly! 🎉

## 📡 How It Works

```
┌─────────────┐
│  Player 1   │ Subscribe to Game A
└──────┬──────┘
       │
       ▼
┌──────────────┐      ┌─────────────┐      ┌──────────────┐
│  WebSocket   │◄─────│  Blockchain │◄─────│  Player 2    │
│    Server    │      │   (gRPC)    │      │  (Performs   │
│              │      │             │      │   Action)    │
└──────┬───────┘      └─────────────┘      └──────────────┘
       │
       │ Broadcast new state
       ▼
┌─────────────┐
│  Player 1   │ Receives update!
└─────────────┘
```

## 🎮 Complete Flow Example

**Terminal 1: Start WebSocket Server**
```bash
./ws-server
```

**Terminal 2: Subscribe (using test client or CLI)**
```bash
# Open test-client.html in browser and subscribe to a game
```

**Terminal 3: Perform Actions**
```bash
# Create a table
./create-table
# Game ID: 0x89a7c...

# Join the game
./join-game 0x89a7c... 1 500000000

# Broadcast the join event
./trigger-broadcast 0x89a7c... join

# Check legal actions
./get-legal-actions 0x89a7c...

# Perform an action
./perform-action 0x89a7c... call

# Broadcast the action
./trigger-broadcast 0x89a7c... action
```

**Terminal 2: Watch the updates arrive in real-time!** 🎊

## 🔌 Client Protocol

### Subscribe to a Game

Send:
```json
{
  "type": "subscribe",
  "game_id": "0x89a7c217580fb3fcd84d541e30538374c2974bc57e59c7c4cdb6b38714771df1"
}
```

Receive (immediate):
```json
{
  "game_id": "0x89a7c...",
  "timestamp": "2024-11-24T18:56:00Z",
  "event": "state",
  "data": {
    "game_id": "0x89a7c...",
    "status": "active",
    "players": [...],
    "pot": 5000000,
    ...
  }
}
```

### Receive Updates

When another player acts:
```json
{
  "game_id": "0x89a7c...",
  "timestamp": "2024-11-24T18:57:30Z",
  "event": "action",
  "data": {
    ...updated game state...
  }
}
```

## 🧪 Testing

Run the integration test:
```bash
./test-websocket-integration.sh
```

This will:
1. ✅ Check server is running
2. 🎲 Create a table
3. 📡 Broadcast creation
4. 🪑 Join the game
5. 📡 Broadcast join
6. 🎯 Get legal actions
7. ♠️ Perform an action
8. 📡 Broadcast action
9. 📊 Query final state

## 🌐 Production Deployment

Your nginx is already configured to proxy WebSocket at `/ws`:

```nginx
location /ws {
    proxy_pass http://127.0.0.1:8585/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
}
```

Connect via:
```
wss://node.texashodl.net/ws
```

## 📚 Available Commands

| Command | Description |
|---------|-------------|
| `./ws-server` | Start WebSocket server |
| `./trigger-broadcast <game_id> <event>` | Manually trigger broadcast |
| `./get-legal-actions <game_id>` | Query available actions |
| `./perform-action <game_id> <action> [amount]` | Perform poker action |
| `./join-game <game_id> <seat> <amount>` | Join a game |
| `./leave-game <game_id>` | Leave a game |

## 🔗 Related Documentation

- **WebSocket Server**: `cmd/ws-server/README.md`
- **Poker CLI**: `cmd/poker-cli/README.md`
- **Test Client**: `cmd/ws-server/test-client.html`

## 🐛 Troubleshooting

### Server not starting
```bash
# Check if port 8585 is in use
lsof -i :8585

# Kill existing process
kill $(lsof -t -i:8585)

# Start server
./ws-server
```

### No updates received
```bash
# Verify subscription
curl http://localhost:8585/health

# Manually trigger update
./trigger-broadcast 0x89a7c...771df1 test

# Check server logs
```

### WebSocket connection refused
```bash
# Check server is running
curl http://localhost:8585/health

# Test WebSocket endpoint
wscat -c ws://localhost:8585/ws

# If wscat not installed:
npm install -g wscat
```

## 🎯 Next Steps

1. **Automatic Broadcasts**: Integrate with blockchain event listeners to auto-broadcast without manual triggers
2. **Authentication**: Add player authentication to subscriptions
3. **Private Data**: Filter game state based on player (hide other players' cards)
4. **Reconnection**: Implement automatic reconnection with exponential backoff
5. **Replay**: Store and replay recent events for new subscribers
6. **Scaling**: Add Redis pub/sub for multi-instance deployment

## 💡 Tips

- Use the test client (`test-client.html`) for debugging
- Subscribe to multiple games simultaneously
- The server automatically sends current state when you subscribe
- Ping/pong keep-alive is automatic (every 54 seconds)
- Connection health check at `http://localhost:8585/health`

---

Happy Gaming! 🎰♠️♥️♣️♦️
