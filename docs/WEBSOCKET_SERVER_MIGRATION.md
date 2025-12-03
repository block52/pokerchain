# WebSocket Server Migration: Standalone to Embedded

**Related PR:** https://github.com/block52/pokerchain/pull/40
**Date:** 2025-12-03
**Status:** In Progress

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   PRODUCTION SERVER (node.hodle.net)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌──────────────────┐         ┌──────────────────────────┐     │
│   │ pokerchaind      │         │ ws-server                │     │
│   │ (pokerchaind.    │         │ (poker-ws.service)       │     │
│   │  service)        │         │                          │     │
│   ├──────────────────┤         ├──────────────────────────┤     │
│   │ Port 26657 (RPC) │◄───────►│ Subscribes to events     │     │
│   │ Port 9090 (gRPC) │◄───────►│ Queries game state       │     │
│   │ Port 1317 (REST) │         │ Port 8585 (WebSocket)    │     │
│   └──────────────────┘         └──────────────────────────┘     │
│                                          ▲                       │
│                                          │                       │
│                                   NGINX (:443/ws)                │
│                                          ▲                       │
└──────────────────────────────────────────│───────────────────────┘
                                           │
                                    UI Clients
```

### Two Separate Implementations

| Component | Path | Lines | Deployed |
|-----------|------|-------|----------|
| Package (reusable) | `pkg/wsserver/server.go` | ~800 | No |
| Standalone binary | `cmd/ws-server/main.go` | ~900 | **Yes** (on node.hodle.net) |

Both have identical logic - the package is now the canonical implementation.

---

## Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   PRODUCTION SERVER (node.hodle.net)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌────────────────────────────────────────────────────────┐    │
│   │ pokerchaind (pokerchaind.service)                      │    │
│   ├────────────────────────────────────────────────────────┤    │
│   │ ┌─────────────────┐    ┌───────────────────────────┐   │    │
│   │ │ Cosmos Node     │    │ Embedded WebSocket Server │   │    │
│   │ │                 │◄──►│ (pkg/wsserver)            │   │    │
│   │ │ Port 26657      │    │ Port 8585                 │   │    │
│   │ │ Port 9090       │    │                           │   │    │
│   │ │ Port 1317       │    │ • Same process            │   │    │
│   │ └─────────────────┘    │ • Starts with node        │   │    │
│   │                        │ • Shared gRPC connection  │   │    │
│   │                        └───────────────────────────┘   │    │
│   └────────────────────────────────────────────────────────┘    │
│                                          ▲                       │
│                                   NGINX (:443/ws)                │
│                                          ▲                       │
└──────────────────────────────────────────│───────────────────────┘
                                           │
                                    UI Clients
```

### Benefits

1. **Single process** - One service to manage instead of two
2. **Shared resources** - Can share gRPC connection, less overhead
3. **Atomic startup** - WebSocket starts when node is ready
4. **Simpler deployment** - No separate poker-ws.service needed
5. **Single source of truth** - Only `pkg/wsserver` implementation runs

---

## Migration Steps

### Phase 1: Consolidate Implementations ✅

- [x] Ensure `pkg/wsserver/server.go` has all features from `cmd/ws-server/main.go`
- [x] Add `Start(cfg Config)` function to package
- [x] Add `StartAsync(cfg Config)` function for goroutine startup
- [x] Add optimistic updates (action relay) to package
- [x] Add protocol.go constants

### Phase 2: Embed WebSocket Server in Node ⏳

- [ ] Add wsserver startup in `app/app.go` RegisterAPIRoutes
- [ ] Read config from environment variables
- [ ] Only start if `WS_ENABLED=true`
- [ ] Test embedded startup locally

### Phase 3: Production Cutover ⏳

**CRITICAL ORDER OF OPERATIONS:**
1. FIRST: Stop poker-ws.service on node.hodle.net
2. THEN: Deploy new pokerchaind with embedded wsserver
3. VERIFY: WebSocket health check passes

- [ ] Stop poker-ws.service on node.hodle.net
- [ ] Deploy updated pokerchaind binary
- [ ] Set WS_ENABLED=true in pokerchaind.service
- [ ] Restart pokerchaind
- [ ] Verify WebSocket health

### Phase 4: Cleanup ⏳

- [ ] Disable poker-ws.service permanently
- [ ] Update `setup-network.sh` option 12 documentation
- [ ] Keep `cmd/ws-server/main.go` for local development/testing

---

## Files to Modify

| File | Action |
|------|--------|
| `app/app.go` | Add wsserver startup in RegisterAPIRoutes |
| `setup-network.sh` | Update option 12 docs (not remove) |
| `cmd/ws-server/main.go` | **KEEP** (useful for local dev) |
| `cmd/ws-server/README.md` | Update to note embedded is preferred |
| `WEBSOCKET_QUICKSTART.md` | Update documentation |

---

## Production Cutover Checklist (node.hodle.net)

### CRITICAL: Order of Operations

⚠️ **You MUST stop the standalone poker-ws.service BEFORE starting the embedded version!**

Both cannot run on port 8585 simultaneously.

### Step-by-Step

```bash
# 1. SSH to production server
ssh root@node.hodle.net

# 2. FIRST: Stop the standalone WebSocket service
sudo systemctl stop poker-ws
sudo systemctl disable poker-ws

# 3. Verify it's stopped (IMPORTANT!)
sudo systemctl status poker-ws  # Should show "inactive"
lsof -i :8585                   # Should show nothing

# 4. Upload new pokerchaind binary (with embedded wsserver)
# Use setup-network.sh option 9 or manual upload

# 5. Set environment variables in pokerchaind.service
sudo systemctl edit pokerchaind
# Add under [Service]:
# Environment="WS_ENABLED=true"
# Environment="WS_SERVER_PORT=:8585"

# 6. Restart pokerchaind
sudo systemctl restart pokerchaind

# 7. Wait a few seconds for startup
sleep 5

# 8. Verify WebSocket is running
curl http://localhost:8585/health
# Should return: {"status":"ok",...}

# 9. Test from external
curl https://node.hodle.net/ws-health

# 10. Check logs for any issues
sudo journalctl -u pokerchaind -f --since "5 minutes ago"
```

### Rollback Plan

If embedded approach fails:

```bash
# 1. Stop pokerchaind
sudo systemctl stop pokerchaind

# 2. Remove WS_ENABLED from pokerchaind.service
sudo systemctl edit pokerchaind
# Remove the WS_* environment variables

# 3. Re-enable standalone service
sudo systemctl enable poker-ws
sudo systemctl start poker-ws

# 4. Restart pokerchaind (without embedded ws)
sudo systemctl start pokerchaind

# 5. Verify standalone WS is working
curl http://localhost:8585/health
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WS_ENABLED` | `false` | Enable embedded WebSocket server |
| `WS_SERVER_PORT` | `:8585` | WebSocket server port |
| `WS_GRPC_ADDRESS` | `localhost:9090` | gRPC address (can be internal) |
| `WS_TENDERMINT_URL` | `ws://localhost:26657/websocket` | Tendermint WS URL |

### Updated pokerchaind.service

```ini
[Unit]
Description=Pokerchain Node
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/pokerchaind start
# WebSocket server config (embedded)
Environment="WS_ENABLED=true"
Environment="WS_SERVER_PORT=:8585"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Port 8585 conflict | Stop poker-ws.service FIRST before deploying |
| Node crash affects WebSocket | Monitor both endpoints, rollback if issues |
| Config mismatch | Copy env vars from poker-ws.service |
| Memory increase | Minimal - wsserver is lightweight |

---

## Timeline

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1 | Consolidate implementations | ✅ Done |
| Phase 2 | Embed in node | ⏳ In Progress |
| Phase 3 | Production cutover | ⏳ To Do |
| Phase 4 | Cleanup & docs | ⏳ To Do |

---

## Manual Todo

- [ ] **BEFORE DEPLOY**: SSH to node.hodle.net and run `sudo systemctl stop poker-ws`
- [ ] Verify port 8585 is free: `lsof -i :8585` should return nothing
- [ ] Deploy new binary
- [ ] Test health endpoint

---

## Notes

- `cmd/ws-server/main.go` is kept for local development and testing
- Production will use the embedded `pkg/wsserver` going forward
- NGINX config remains unchanged (still proxies to :8585)
- The key is stopping the old service BEFORE starting the new embedded one
