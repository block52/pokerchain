# WebSocket Server Migration: Standalone to Embedded

**Related PR:** https://github.com/block52/pokerchain/pull/40
**Date:** 2025-12-03
**Status:** Planning

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRODUCTION SERVER                         │
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
| Standalone binary | `cmd/ws-server/main.go` | ~900 | **Yes** |

Both have identical logic duplicated - this is the problem we're solving.

---

## Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRODUCTION SERVER                         │
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
5. **Single source of truth** - Only `pkg/wsserver` implementation

---

## Migration Steps

### Phase 1: Consolidate Implementations

- [x] Ensure `pkg/wsserver/server.go` has all features from `cmd/ws-server/main.go`
- [x] Add `Start(cfg Config)` function to package
- [x] Add `StartAsync(cfg Config)` function for goroutine startup
- [x] Add optimistic updates (action relay) to package
- [ ] Verify protocol.go constants are complete

### Phase 2: Embed WebSocket Server in Node

- [ ] Add wsserver config to `app/app.go` or `cmd/pokerchaind/cmd/root.go`
- [ ] Start WebSocket server when node starts (use `StartAsync`)
- [ ] Read config from environment variables or config file
- [ ] Test embedded startup locally

**Option A: Start in RegisterAPIRoutes (Recommended)**
```go
// app/app.go
func (app *App) RegisterAPIRoutes(apiSvr *api.Server, apiConfig config.APIConfig) {
    app.App.RegisterAPIRoutes(apiSvr, apiConfig)

    // Start embedded WebSocket server
    wsConfig := wsserver.Config{
        Port:            os.Getenv("WS_SERVER_PORT"),
        TendermintWSURL: "ws://localhost:26657/websocket",
        GRPCAddress:     "localhost:9090",
    }
    wsserver.StartAsync(wsConfig)
}
```

**Option B: Add custom start command hook**
```go
// cmd/pokerchaind/cmd/start.go (new file)
// Add PreRun hook to start WebSocket server
```

### Phase 3: Update Deployment

- [ ] Remove `poker-ws.service` from systemd
- [ ] Update `setup-network.sh` option 12 (remove or repurpose)
- [ ] Update NGINX config if needed (should still proxy to 8585)
- [ ] Update documentation

### Phase 4: Deprecate Standalone Binary

- [ ] Delete `cmd/ws-server/main.go` or mark as deprecated
- [ ] Remove build step for ws-server from deployment scripts
- [ ] Update CI/CD if applicable

---

## Files to Modify

| File | Action |
|------|--------|
| `app/app.go` | Add wsserver startup in RegisterAPIRoutes |
| `setup-network.sh` | Remove/update option 12 |
| `cmd/ws-server/main.go` | DELETE (after migration) |
| `cmd/ws-server/README.md` | DELETE |
| `WEBSOCKET_QUICKSTART.md` | Update documentation |

---

## Production Cutover Checklist

### Before Migration

- [ ] Notify team of planned migration window
- [ ] Backup current configuration
- [ ] Document current poker-ws.service settings

### Migration Steps

```bash
# 1. SSH to production server
ssh root@node1.block52.xyz

# 2. Stop the standalone WebSocket service
sudo systemctl stop poker-ws
sudo systemctl disable poker-ws

# 3. Verify it's stopped
sudo systemctl status poker-ws  # Should show "inactive"

# 4. Update pokerchaind binary (with embedded wsserver)
# (Use setup-network.sh option 9 to update binary)

# 5. Set environment variables in pokerchaind.service
sudo systemctl edit pokerchaind
# Add under [Service]:
# Environment="WS_SERVER_PORT=:8585"
# Environment="WS_ENABLED=true"

# 6. Restart pokerchaind
sudo systemctl restart pokerchaind

# 7. Verify WebSocket is running
curl http://localhost:8585/health
# Should return: {"status":"ok",...}

# 8. Test from external
curl https://node1.block52.xyz/ws-health

# 9. If successful, remove old service file
sudo rm /etc/systemd/system/poker-ws.service
sudo systemctl daemon-reload
```

### Rollback Plan

If embedded approach fails:

```bash
# Re-enable standalone service
sudo systemctl enable poker-ws
sudo systemctl start poker-ws

# Remove WS_ENABLED from pokerchaind.service
sudo systemctl edit pokerchaind
# Remove the WS_* environment variables

sudo systemctl restart pokerchaind
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
| Node crash affects WebSocket | Monitor both endpoints, rollback if issues |
| Port conflict | Use same port (8585), no change needed |
| Config mismatch | Copy env vars from poker-ws.service |
| Memory increase | Minimal - wsserver is lightweight |

---

## Timeline

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1 | Consolidate implementations | ✅ Done |
| Phase 2 | Embed in node | ⏳ To Do |
| Phase 3 | Update deployment | ⏳ To Do |
| Phase 4 | Deprecate standalone | ⏳ To Do |
| Cutover | Production migration | ⏳ To Do |

---

## Notes

- The standalone `cmd/ws-server/main.go` was the production server
- `pkg/wsserver/server.go` was created but never deployed
- Both now have optimistic updates feature
- This migration unifies them and simplifies architecture
