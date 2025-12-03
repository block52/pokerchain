# Hole Cards Not Showing Investigation

**Date**: 2025-11-26
**Status**: ✅ IMPLEMENTED
**Priority**: High

## Problem Statement

Player's own hole cards display as "X" (masked) instead of showing the actual card values (e.g., "Ah", "Kd"). Opposite players correctly show card backs, but the current player should see their own cards.

## Root Cause Analysis

### 1. WebSocket Server Uses Public Query (Masks All Cards)

**Location**: `pkg/wsserver/server.go:218-220`

```go
res, err := h.queryClient.Game(ctx, &pokertypes.QueryGameRequest{
    GameId: gameID,
})
```

This calls `query_game.go` which masks **ALL** hole cards.

### 2. Authenticated Query Exists But Requires Signature

**Location**: `x/poker/keeper/query_game_state.go`

The `GameState()` query properly shows your cards while masking others, but requires:
- `PlayerAddress` - Your Cosmos address
- `Timestamp` - Current Unix timestamp
- `Signature` - Ethereum personal_sign signature

### 3. Signature Format (from poker-cli)

**Location**: `cmd/poker-cli/main.go:910-940`

```go
// Message format: "pokerchain-query:<timestamp>"
message := fmt.Sprintf("pokerchain-query:%d", timestamp)

// Ethereum personal_sign prefix
prefixedMessage := fmt.Sprintf("\x19Ethereum Signed Message:\n%d%s", len(message), message)

// Keccak256 hash then secp256k1 sign
hash := crypto.Keccak256Hash([]byte(prefixedMessage))
signature, err := crypto.Sign(hash.Bytes(), ecdsaPrivKey)

// Adjust v value (add 27 for Ethereum compatibility)
signature[64] += 27

return "0x" + hex.EncodeToString(signature)
```

## Complete Solution Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         PROPOSED ARCHITECTURE                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐                                                         │
│  │   UI (React)    │                                                         │
│  │                 │                                                         │
│  │  1. User has    │                                                         │
│  │     mnemonic    │                                                         │
│  │     stored      │                                                         │
│  └────────┬────────┘                                                         │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐         ┌─────────────────┐                            │
│  │   SDK/Signer    │         │   WebSocket     │                            │
│  │                 │         │   Server        │                            │
│  │  2. Sign        │ ───────►│                 │                            │
│  │     timestamp   │         │  3. Validate    │                            │
│  │     with        │         │     signature   │                            │
│  │     mnemonic    │         │                 │                            │
│  │                 │         │  4. Store       │                            │
│  │  Message:       │         │     playerId    │                            │
│  │  "pokerchain-   │         │     per client  │                            │
│  │   query:<ts>"   │         │                 │                            │
│  └─────────────────┘         └────────┬────────┘                            │
│                                       │                                      │
│                                       ▼                                      │
│                              ┌─────────────────┐                            │
│                              │   gRPC Query    │                            │
│                              │                 │                            │
│                              │  5. Query raw   │                            │
│                              │     game state  │                            │
│                              │     (internal)  │                            │
│                              └────────┬────────┘                            │
│                                       │                                      │
│                                       ▼                                      │
│                              ┌─────────────────┐                            │
│                              │  Per-Client     │                            │
│                              │  Masking        │                            │
│                              │                 │                            │
│                              │  6. For each    │                            │
│                              │     client,     │                            │
│                              │     mask OTHER  │                            │
│                              │     players'    │                            │
│                              │     cards       │                            │
│                              └────────┬────────┘                            │
│                                       │                                      │
│                                       ▼                                      │
│                              ┌─────────────────┐                            │
│                              │   UI Client     │                            │
│                              │                 │                            │
│                              │  7. Player sees │                            │
│                              │     own cards:  │                            │
│                              │     ["Ah","Kd"] │                            │
│                              │                 │                            │
│                              │     Others see  │                            │
│                              │     ["X","X"]   │                            │
│                              └─────────────────┘                            │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Implementation Checklist

### Phase 1: Frontend SDK Signing (TypeScript)

**File**: `poker-vm/ui/src/utils/cosmos/signing.ts` (NEW)

- [x] Create signing utility function
- [x] Use ethers.js to sign with secp256k1
- [x] Match the poker-cli message format exactly

```typescript
// Example implementation
export async function signQueryMessage(mnemonic: string, timestamp: number): Promise<string> {
    // Create message: "pokerchain-query:<timestamp>"
    const message = `pokerchain-query:${timestamp}`;

    // Add Ethereum personal_sign prefix
    const prefixedMessage = `\x19Ethereum Signed Message:\n${message.length}${message}`;

    // Hash with Keccak256
    const hash = ethers.keccak256(ethers.toUtf8Bytes(prefixedMessage));

    // Derive private key from mnemonic (same path as Cosmos)
    const wallet = ethers.Wallet.fromPhrase(mnemonic);

    // Sign and return
    const signature = await wallet.signMessage(message);
    return signature;
}
```

### Phase 2: WebSocket Subscription Message

**File**: `poker-vm/ui/src/context/GameStateContext.tsx`

- [x] Generate timestamp on subscription
- [x] Sign the timestamp with mnemonic
- [x] Send auth info in subscription message

```typescript
// Enhanced subscription message
const subscriptionMessage = {
    type: "subscribe",
    game_id: tableId,
    player_address: playerAddress,
    timestamp: Math.floor(Date.now() / 1000),
    signature: await signQueryMessage(mnemonic, timestamp)
};
```

### Phase 3: WebSocket Server Auth Handling

**File**: `pokerchain/pkg/wsserver/server.go`

- [x] Add playerId field to Client struct
- [x] Parse auth info from subscription message
- [x] Validate signature (delegated to gRPC GameState query)
- [x] Store playerId per client connection

```go
// Enhanced Client struct
type Client struct {
    hub      *Hub
    conn     *websocket.Conn
    send     chan []byte
    gameIDs  map[string]bool
    playerId string  // NEW: authenticated player address
    mu       sync.RWMutex
}

// Enhanced subscription handling
case "subscribe":
    if msg.GameID != "" {
        // Store player ID from authenticated subscription
        if msg.PlayerAddress != "" {
            c.playerId = msg.PlayerAddress
        }
        c.hub.subscribe <- &Subscription{
            client: c,
            gameID: msg.GameID,
        }
    }
```

### Phase 4: Raw Game State Query

**File**: `pokerchain/x/poker/keeper/query_game.go` (or new file)

- [x] ~~Add internal query that returns unmasked state~~ (NOT NEEDED - using existing GameState query with signature)
- [x] ~~Only accessible from WebSocket server~~ (Using existing authenticated GameState query instead)

```go
// New query for WebSocket server internal use
func (q queryServer) GameInternal(ctx context.Context, gameID string) (*types.TexasHoldemStateDTO, error) {
    gameState, err := q.k.GameStates.Get(ctx, gameID)
    if err != nil {
        return nil, err
    }
    // Return raw state - NO masking
    return &gameState, nil
}
```

### Phase 5: Per-Client Masking in WebSocket Server

**File**: `pokerchain/pkg/wsserver/server.go`

- [x] ~~Get raw game state once per broadcast~~ (Using per-client GameState queries instead)
- [x] Apply per-client masking using client's playerId (via GameState query)
- [x] Send personalized state to each client

```go
func (h *Hub) BroadcastGameUpdate(gameID string, event string) {
    // Get raw (unmasked) game state once
    rawState, err := h.getRawGameState(ctx, gameID)
    if err != nil {
        return
    }

    h.mu.RLock()
    if clients, exists := h.games[gameID]; exists {
        for client := range clients {
            // Create personalized masked state for this client
            maskedState := maskOtherPlayersCards(rawState, client.playerId)

            update := &GameUpdate{
                GameID:    gameID,
                Timestamp: time.Now(),
                Event:     event,
                Data:      json.RawMessage(marshalState(maskedState)),
            }

            message, _ := json.Marshal(update)
            client.send <- message
        }
    }
    h.mu.RUnlock()
}
```

## Files to Modify

### Frontend (poker-vm/ui)

| File | Changes |
|------|---------|
| `src/utils/cosmos/signing.ts` | NEW: Add query message signing utility |
| `src/utils/cosmos/storage.ts` | May need to expose mnemonic for signing |
| `src/context/GameStateContext.tsx` | Add auth info to subscription message |

### Backend (pokerchain)

| File | Changes |
|------|---------|
| `pkg/wsserver/server.go` | Add playerId to Client, per-client masking |
| `x/poker/keeper/query_game.go` | Add internal unmasked query (optional) |
| `x/poker/types/types.go` | May need to update subscription message type |

## Security Considerations

1. **Signature Validation**: The WebSocket server SHOULD validate signatures to prevent impersonation
2. **Timestamp Window**: Signatures should expire (current: 1 hour window)
3. **No Deck Exposure**: Deck should NEVER be visible to any player
4. **Community Cards**: Should be visible to all players

## Testing Checklist

- [ ] Player 1 joins table, sees their own cards after deal
- [ ] Player 2 joins table, sees their own cards after deal
- [ ] Player 1 sees Player 2's cards as backs ("X")
- [ ] Player 2 sees Player 1's cards as backs ("X")
- [ ] Community cards visible to all players
- [ ] Cards properly hidden during ante/preflop before deal
- [ ] Showdown reveals cards to all players
- [ ] Signature validation works correctly
- [ ] Invalid signature is rejected

## Questions to Confirm

1. **Should we validate signatures in WebSocket server?**
   - Pro: More secure, prevents impersonation
   - Con: More complex, need crypto libraries in Go

2. **Should mnemonic be stored in memory or re-requested for signing?**
   - Currently mnemonic is stored in localStorage
   - Could derive signing key once and store it

3. **Broadcast vs Per-Client queries?**
   - Current: One query, broadcast to all (but masks all cards)
   - Proposed: One query, per-client masking (more efficient)
   - Alternative: Per-client authenticated queries (more queries but simpler)

## Related Files Reference

- **Signing example**: `pokerchain/cmd/poker-cli/main.go:910-940`
- **Signature verification**: `pokerchain/x/poker/keeper/query_game_state.go:83-146`
- **Card masking logic**: `pokerchain/x/poker/keeper/query_game_state.go:161-187`
- **WebSocket message handling**: `pokerchain/pkg/wsserver/server.go:277-325`
- **UI game state context**: `poker-vm/ui/src/context/GameStateContext.tsx`

---

## Implementation Summary (2025-11-26)

### Approach Taken

Instead of adding a new raw internal query and implementing masking logic in the WebSocket server,
we leveraged the **existing `GameState` gRPC query** which already has:
1. Signature verification (`verifyCosmosSignature`)
2. Per-player card masking (`maskOtherPlayersCards`)

### Files Modified

#### Frontend (`poker-vm/ui/`)

| File | Changes |
|------|---------|
| `src/utils/cosmos/signing.ts` | **NEW**: Query message signing using ethers.js |
| `src/utils/cosmos/index.ts` | Added exports for `signQueryMessage` and `createAuthPayload` |
| `src/context/GameStateContext.tsx` | Added auth payload to subscription message |

#### Backend (`pokerchain/`)

| File | Changes |
|------|---------|
| `pkg/wsserver/server.go` | Added `playerId`, `timestamp`, `signature` to Client struct; Updated `ClientMessage` with auth fields; Modified `sendGameState` to use `GameState` query when authenticated; Modified `BroadcastGameUpdate` to send per-client personalized state via `sendPersonalizedUpdate` |

### How It Works

1. **Frontend signs subscription**: When connecting to WebSocket, the UI creates an auth payload with timestamp and signature using ethers.js
2. **WebSocket stores credentials**: Server stores playerId, timestamp, and signature for each client
3. **Per-client queries**: When sending game state (initial or broadcast), the server calls `GameState` with each client's credentials
4. **Signature validation**: The existing `GameState` query validates signatures and returns cards masked for that specific player
5. **Fallback**: If no credentials or signature fails, falls back to public `Game` query (all cards masked)

### Next Steps (Testing)

1. Restart the pokerchain node to pick up WebSocket server changes
2. Test with two players:
   - Player 1 should see their own hole cards
   - Player 1 should see Player 2's cards as "X"
   - Player 2 should see their own hole cards
   - Player 2 should see Player 1's cards as "X"

---

## Debug Session 2 (2025-11-26 14:30)

### Issue Found: Signature Verification Failure

Server logs showed:
```
[WS-Server] Error querying authenticated game state: rpc error: code = Unauthenticated desc = signature verification failed: signature does not match the provided address
```

### Root Cause: HD Path Mismatch

The frontend was using **Ethereum HD path** while the backend expected **Cosmos HD path**:

| Component | HD Path Used | Result |
|-----------|--------------|--------|
| Frontend `signing.ts` | `m/44'/60'/0'/0/0` (Ethereum) | Wrong key! |
| poker-cli | `m/44'/118'/0'/0/0` (Cosmos) | Correct key |
| Cosmos SDK | `m/44'/118'/0'/0/0` (Cosmos) | Correct key |

The same mnemonic derives **different private keys** with different HD paths!

### Fix Applied

Updated `poker-vm/ui/src/utils/cosmos/signing.ts`:

```typescript
// BEFORE (wrong):
const wallet = ethers.Wallet.fromPhrase(mnemonic);  // Uses m/44'/60'/0'/0/0

// AFTER (correct):
const COSMOS_HD_PATH = "m/44'/118'/0'/0/0";
const hdWallet = ethers.HDNodeWallet.fromPhrase(mnemonic, undefined, COSMOS_HD_PATH);
```

### Testing Status

- [ ] Rebuild UI with fixed signing.ts
- [ ] Verify signature matches in server logs
- [ ] Confirm hole cards display correctly for authenticated player
