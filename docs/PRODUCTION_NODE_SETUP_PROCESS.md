# Production Node Setup Process

> **Purpose**: This document explains the complete process for setting up production validator nodes for Pokerchain, from initial configuration generation through remote deployment.

## Overview

Production deployment is a **two-phase process**:

1. **Phase A: Local Configuration Generation** (`setup-production-nodes.sh`)
   - Runs on your development machine
   - Generates all node configs, keys, and genesis in `./production/` directory
   - Creates deployment scripts for each node

2. **Phase B: Remote Deployment** (`deploy-production-node.sh`)
   - Deploys generated configs to remote servers via SSH
   - Installs binary, sets up systemd, configures firewall

```mermaid
flowchart TB
    subgraph PhaseA["Phase A: Local Generation"]
        direction TB
        A1[Developer Machine]
        A2[setup-production-nodes.sh]
        A3[./production/node0/]
        A4[./production/node1/]
        A5[./production/nodeN/]

        A1 --> A2
        A2 --> A3
        A2 --> A4
        A2 --> A5
    end

    subgraph PhaseB["Phase B: Remote Deployment"]
        direction TB
        B1[deploy-production-node.sh]
        B2[Remote Server 1]
        B3[Remote Server 2]
        B4[Remote Server N]
    end

    A3 -->|SSH + SCP| B2
    A4 -->|SSH + SCP| B3
    A5 -->|SSH + SCP| B4

    B1 --> B2
    B1 --> B3
    B1 --> B4

    style PhaseA fill:#e1f5fe,stroke:#01579b
    style PhaseB fill:#e8f5e9,stroke:#1b5e20
```

---

## Phase A: Configuration Generation

### Script: `setup-production-nodes.sh`

This script generates all production configurations locally before any remote deployment.

### High-Level Flow

```mermaid
flowchart TD
    Start([Start]) --> Config[Step 1: Configure Nodes]
    Config --> Arch[Select Target Architecture]
    Arch --> Keys[Step 2: Generate Keys]
    Keys --> Genesis[Step 3: Create Genesis]
    Genesis --> GenTx[Step 4: Create GenTx]
    GenTx --> Collect[Step 5: Collect GenTx]
    Collect --> Distribute[Step 6: Distribute Genesis]
    Distribute --> Network[Step 7: Configure Network]
    Network --> Package[Step 8: Create Deployment Package]
    Package --> Save[Step 9: Save Configuration]
    Save --> Deploy{Deploy Now?}
    Deploy -->|Yes| SSHDeploy[SSH Deployment]
    Deploy -->|No| End([End])
    SSHDeploy --> End

    style Start fill:#4caf50,color:#fff
    style End fill:#f44336,color:#fff
```

### Step-by-Step Breakdown

#### Step 1: Configure Node Information

```mermaid
flowchart LR
    subgraph Input["User Input"]
        I1[Number of Nodes]
        I2[Chain Binary Name]
        I3[Chain ID]
    end

    subgraph PerNode["For Each Node"]
        N1[Hostname<br/>e.g., node0.block52.xyz]
        N2[IP Address<br/>auto-resolved or manual]
        N3[Moniker<br/>e.g., validator0]
        N4[Mnemonic<br/>optional, for key recovery]
    end

    Input --> PerNode

    style Input fill:#fff3e0,stroke:#e65100
    style PerNode fill:#e3f2fd,stroke:#1565c0
```

**What happens:**
- Prompts for number of validator nodes (default: 4)
- For each node:
  - Hostname (used for peer connections)
  - IP address (auto-resolved from hostname, or manual entry)
  - Moniker (human-readable name)
  - Mnemonic (optional, for recoverable keys)

#### Step 2: Initialize Nodes & Generate Keys

```mermaid
flowchart TD
    subgraph KeyGeneration["Key Generation Options"]
        Opt1[Option 1: From Mnemonic<br/>Recoverable keys]
        Opt2[Option 2: Random<br/>Default init behavior]
    end

    KeyGeneration --> MnemonicPath{Use Mnemonic?}

    MnemonicPath -->|Yes| GenKey[genvalidatorkey tool]
    MnemonicPath -->|No| Init[pokerchaind init]

    GenKey --> CreatePrivKey[Create priv_validator_key.json]
    Init --> CreatePrivKey

    CreatePrivKey --> CreateAcctKey[Create Account Key<br/>pokerchaind keys add]
    CreateAcctKey --> StoreInfo[Store Node ID & Address]

    subgraph Output["Generated Files"]
        O1[priv_validator_key.json<br/>Consensus signing key]
        O2[priv_validator_state.json<br/>Double-sign prevention]
        O3[Account keyring<br/>Transaction signing]
        O4[node_key.json<br/>P2P identity]
    end

    StoreInfo --> Output
```

**Key files generated per node:**

| File | Purpose | Security Level |
|------|---------|----------------|
| `priv_validator_key.json` | Signs consensus votes | CRITICAL - backup required |
| `priv_validator_state.json` | Prevents double-signing | Important |
| `node_key.json` | P2P network identity | Moderate |
| Keyring files | Signs transactions | Important |

#### Step 3: Add Genesis Accounts

```mermaid
flowchart TD
    Node0[Node 0 Genesis] --> AddAcct1[Add Node 0 Account<br/>1,000,000 STAKE]
    AddAcct1 --> AddAcct2[Add Node 1 Account<br/>1,000,000 STAKE]
    AddAcct2 --> AddAcct3[Add Node 2 Account<br/>1,000,000 STAKE]
    AddAcct3 --> AddAcctN[Add Node N Account<br/>1,000,000 STAKE]

    subgraph GenesisState["Genesis Bank State"]
        G1["balances: [
          {addr: node0, coins: 1000000000000stake},
          {addr: node1, coins: 1000000000000stake},
          ...
        ]"]
    end

    AddAcctN --> GenesisState

    style GenesisState fill:#fff9c4,stroke:#f57f17
```

**Command executed:**
```bash
pokerchaind genesis add-genesis-account $VALIDATOR_ADDR 1000000000000stake \
    --home $OUTPUT_DIR/node0
```

**Note:** Only STAKE is given at genesis (no USDC - that comes from bridge deposits).

#### Step 4: Create Genesis Transactions (GenTx)

```mermaid
flowchart TD
    subgraph GenTxProcess["GenTx Creation"]
        GT1[Node 0 creates gentx<br/>Stakes 100,000 STAKE]
        GT2[Node 1 creates gentx<br/>Stakes 100,000 STAKE]
        GTN[Node N creates gentx<br/>Stakes 100,000 STAKE]
    end

    GT1 --> Copy1[Copy genesis to Node 1]
    Copy1 --> GT2
    GT2 --> Copy2[Copy genesis to Node N]
    Copy2 --> GTN

    subgraph GentxFiles["GenTx Files"]
        F1[gentx-node0-xxx.json]
        F2[gentx-node1-xxx.json]
        FN[gentx-nodeN-xxx.json]
    end

    GTN --> CollectAll[Copy all gentx to Node 0]
    CollectAll --> GentxFiles
```

**What a GenTx contains:**
- `MsgCreateValidator` - registers the validator
- Stake amount (100,000 STAKE = 100000000000ustake)
- Commission rates
- Validator public key
- Node ID and IP (for peer discovery)

#### Step 5: Collect Genesis Transactions

```mermaid
flowchart LR
    subgraph Node0["Node 0 gentx/"]
        G1[gentx-node0.json]
        G2[gentx-node1.json]
        G3[gentx-node2.json]
    end

    Node0 --> Collect[pokerchaind genesis<br/>collect-gentxs]

    Collect --> FinalGenesis[Final genesis.json<br/>with all validators]

    style FinalGenesis fill:#c8e6c9,stroke:#2e7d32
```

**Command:**
```bash
pokerchaind genesis collect-gentxs --home $OUTPUT_DIR/node0
```

#### Step 6: Distribute Final Genesis

```mermaid
flowchart TD
    Master[Node 0<br/>genesis.json<br/>MASTER] --> Copy1[Copy to Node 1]
    Master --> Copy2[Copy to Node 2]
    Master --> CopyN[Copy to Node N]

    subgraph AllNodes["All Nodes Have Identical Genesis"]
        N0[Node 0<br/>genesis.json]
        N1[Node 1<br/>genesis.json]
        N2[Node 2<br/>genesis.json]
        NN[Node N<br/>genesis.json]
    end

    Copy1 --> N1
    Copy2 --> N2
    CopyN --> NN
    Master --> N0

    style Master fill:#ffeb3b,stroke:#f57f17
```

**Critical:** All nodes MUST have identical `genesis.json` or they will fail to reach consensus.

#### Step 7: Configure Network Settings

```mermaid
flowchart TD
    subgraph ConfigToml["config.toml Changes"]
        C1[persistent_peers<br/>Other validator IPs]
        C2[laddr<br/>0.0.0.0:26657]
        C3[external_address<br/>Node's public IP]
        C4[pex = true<br/>Peer exchange enabled]
        C5[max_num_inbound_peers<br/>100]
        C6[max_num_outbound_peers<br/>50]
    end

    subgraph AppToml["app.toml Changes"]
        A1[API address<br/>0.0.0.0:1317]
        A2[gRPC address<br/>0.0.0.0:9090]
        A3[minimum-gas-prices<br/>0.001stake]
        A4[enable = true<br/>API enabled]
    end

    ConfigToml --> Node[Configured Node]
    AppToml --> Node
```

**Persistent Peers Format:**
```
node_id1@ip1:26656,node_id2@ip2:26656,node_id3@ip3:26656
```

#### Step 8: Create Deployment Package

```mermaid
flowchart TD
    subgraph OutputDir["./production/"]
        Node0[node0/<br/>config/ data/]
        Node1[node1/<br/>config/ data/]
        NodeN[nodeN/<br/>config/ data/]

        Deploy0[deploy-node0.sh]
        Deploy1[deploy-node1.sh]
        DeployN[deploy-nodeN.sh]
        DeployAll[deploy-all.sh]

        Info[NODE_INFO.md]
        Mnemonics[MNEMONICS_BACKUP.txt<br/>CRITICAL - SECURE THIS]
    end

    style Mnemonics fill:#ffcdd2,stroke:#c62828
```

**Files generated per node:**
```
./production/
├── node0/
│   ├── config/
│   │   ├── app.toml
│   │   ├── config.toml
│   │   ├── genesis.json
│   │   ├── node_key.json
│   │   └── priv_validator_key.json
│   └── data/
│       └── priv_validator_state.json
├── node1/
│   └── ...
├── deploy-node0.sh
├── deploy-node1.sh
├── deploy-all.sh
├── NODE_INFO.md
└── MNEMONICS_BACKUP.txt  (if using mnemonic keys)
```

---

## Phase B: Remote Deployment

### Script: `deploy-production-node.sh`

This script deploys a single node to a remote server.

### High-Level Flow

```mermaid
flowchart TD
    Start([Start]) --> Args[Parse Arguments<br/>node-num, host, user]
    Args --> Check[Check Node Dir Exists]
    Check --> SSH[Test SSH Connection]
    SSH --> Cleanup[Step 1: Cleanup Old Installation]
    Cleanup --> Binary[Step 2: Get Binary]
    Binary --> DeployBin[Step 3: Deploy Binary]
    DeployBin --> DeployConfig[Step 4: Deploy Config]
    DeployConfig --> Bridge[Step 5: Configure Bridge]
    Bridge --> Hash[Step 6: Verify File Hashes]
    Hash --> Firewall[Step 7: Setup Firewall]
    Firewall --> Systemd[Step 8: Setup Systemd]
    Systemd --> Nginx[Step 9: Setup NGINX Optional]
    Nginx --> StartNode[Step 10: Start Node]
    StartNode --> Verify[Step 11: Verify Deployment]
    Verify --> End([Complete])

    style Start fill:#4caf50,color:#fff
    style End fill:#4caf50,color:#fff
```

### Step-by-Step Breakdown

#### Step 1: Cleanup Old Installation

```mermaid
sequenceDiagram
    participant Local as Local Machine
    participant Remote as Remote Server

    Local->>Remote: SSH: systemctl stop pokerchaind
    Remote-->>Remote: Stop service
    Local->>Remote: SSH: pkill pokerchaind
    Remote-->>Remote: Kill processes
    Local->>Remote: SSH: backup ~/.pokerchain
    Remote-->>Remote: Create backup-TIMESTAMP/
    Local->>Remote: SSH: rm -rf ~/.pokerchain
    Remote-->>Remote: Remove old data
```

#### Step 2: Get Binary

```mermaid
flowchart TD
    Choice{Binary Source?}

    Choice -->|Option 1| GitHub[Fetch from GitHub Releases]
    Choice -->|Option 2| Build[Build Locally]

    GitHub --> Download[Download pokerchaind-linux-amd64.tar.gz]
    Download --> Checksum[Verify SHA256 Checksum]
    Checksum --> Extract[Extract Binary]

    Build --> GOOS[GOOS=linux GOARCH=amd64]
    GOOS --> Make[make build]

    Extract --> Binary[./build/pokerchaind]
    Make --> Binary

    style GitHub fill:#e3f2fd,stroke:#1565c0
    style Build fill:#fff3e0,stroke:#e65100
```

#### Step 3: Deploy Binary

```mermaid
sequenceDiagram
    participant Local as Local Machine
    participant Remote as Remote Server

    Local->>Remote: SCP: build/pokerchaind → /tmp/
    Local->>Remote: SSH: mv /tmp/pokerchaind /usr/local/bin/
    Local->>Remote: SSH: chmod +x /usr/local/bin/pokerchaind
    Local->>Remote: SSH: pokerchaind version
    Remote-->>Local: Version: vX.X.X
```

#### Step 4: Deploy Configuration

```mermaid
sequenceDiagram
    participant Local as ./production/nodeX/
    participant Remote as ~/.pokerchain/

    Note over Local,Remote: Create directories
    Local->>Remote: SSH: mkdir -p config/ data/

    Note over Local,Remote: Copy configuration
    Local->>Remote: SCP: config/* → config/
    Local->>Remote: SCP: data/* → data/

    Note over Local,Remote: Set permissions
    Local->>Remote: SSH: chmod 700 ~/.pokerchain
    Local->>Remote: SSH: chmod 600 priv_validator_key.json
```

**Files deployed:**
```
~/.pokerchain/
├── config/
│   ├── app.toml
│   ├── config.toml
│   ├── genesis.json
│   ├── node_key.json
│   └── priv_validator_key.json
└── data/
    └── priv_validator_state.json
```

#### Step 5: Configure Bridge

```mermaid
flowchart TD
    EnvCheck{.env file exists?}

    EnvCheck -->|Yes| ReadEnv[Read ALCHEMY_URL from .env]
    EnvCheck -->|No| Prompt[Prompt for RPC URL]

    ReadEnv --> HasURL{URL found?}
    HasURL -->|Yes| Configure[Add bridge config to app.toml]
    HasURL -->|No| Prompt

    Prompt --> HasInput{User provided URL?}
    HasInput -->|Yes| Configure
    HasInput -->|No| Skip[Skip bridge config]

    Configure --> AppToml["[bridge]
enabled = true
ethereum_rpc_url = 'https://...'
deposit_contract_address = '0x...'
usdc_contract_address = '0x...'
polling_interval_seconds = 60"]
```

#### Step 6: Verify File Hashes

```mermaid
flowchart TD
    subgraph Verification["Hash Verification"]
        V1[Calculate local binary hash]
        V2[Calculate remote binary hash]
        V3[Compare hashes]

        V4[Calculate local genesis hash]
        V5[Calculate remote genesis hash]
        V6[Compare hashes]
    end

    V1 --> V3
    V2 --> V3
    V4 --> V6
    V5 --> V6

    V3 --> Match1{Match?}
    V6 --> Match2{Match?}

    Match1 -->|Yes| OK1[Binary OK]
    Match1 -->|No| Fail1[HASH MISMATCH!]

    Match2 -->|Yes| OK2[Genesis OK]
    Match2 -->|No| Fail2[HASH MISMATCH!]

    style Fail1 fill:#ffcdd2,stroke:#c62828
    style Fail2 fill:#ffcdd2,stroke:#c62828
```

#### Step 7-8: Setup Firewall & Systemd

```mermaid
flowchart LR
    subgraph Firewall["Firewall Rules (UFW)"]
        F1[22/tcp - SSH]
        F2[26656/tcp - P2P]
        F3[26657/tcp - RPC]
        F4[1317/tcp - REST API]
        F5[9090/tcp - gRPC]
    end

    subgraph Systemd["systemd Service"]
        S1[pokerchaind.service]
        S2[ExecStart=/usr/local/bin/pokerchaind start]
        S3[Restart=always]
        S4[User=root]
    end
```

#### Step 9: Start & Verify

```mermaid
sequenceDiagram
    participant Local as Local Machine
    participant Remote as Remote Server
    participant RPC as localhost:26657

    Local->>Remote: SSH: systemctl start pokerchaind

    loop Every 2 seconds (max 30 attempts)
        Local->>Remote: SSH: curl localhost:26657/status
        Remote->>RPC: HTTP GET /status
        RPC-->>Remote: Response
        Remote-->>Local: Status JSON
    end

    Note over Local: Display node status
    Local->>Local: Show moniker, height, sync status
```

---

## Complete Deployment Timeline

```mermaid
gantt
    title Production Deployment Timeline
    dateFormat HH:mm
    axisFormat %H:%M

    section Phase A (Local)
    Configure nodes           :a1, 00:00, 5m
    Generate keys             :a2, after a1, 3m
    Create genesis            :a3, after a2, 2m
    Create gentx              :a4, after a3, 2m
    Collect & distribute      :a5, after a4, 1m
    Configure network         :a6, after a5, 2m
    Create deployment scripts :a7, after a6, 1m

    section Phase B (Per Node)
    Cleanup old installation  :b1, after a7, 2m
    Build/fetch binary        :b2, after b1, 5m
    Deploy binary & config    :b3, after b2, 3m
    Configure bridge          :b4, after b3, 2m
    Setup firewall & systemd  :b5, after b4, 3m
    Start & verify            :b6, after b5, 2m
```

---

## Network Architecture

```mermaid
flowchart TB
    subgraph Validators["Validator Network"]
        V0[Node 0<br/>node0.block52.xyz<br/>:26656]
        V1[Node 1<br/>node1.block52.xyz<br/>:26656]
        V2[Node 2<br/>node2.block52.xyz<br/>:26656]
        V3[Node 3<br/>node3.block52.xyz<br/>:26656]

        V0 <-->|P2P| V1
        V0 <-->|P2P| V2
        V0 <-->|P2P| V3
        V1 <-->|P2P| V2
        V1 <-->|P2P| V3
        V2 <-->|P2P| V3
    end

    subgraph External["External Access"]
        RPC[RPC :26657]
        API[REST API :1317]
        GRPC[gRPC :9090]
    end

    subgraph Users["Users & Services"]
        UI[Poker UI]
        Explorer[Block Explorer]
        Bridge[Bridge Service]
    end

    V0 --> RPC
    V0 --> API
    V0 --> GRPC

    UI --> RPC
    Explorer --> API
    Bridge --> RPC

    style Validators fill:#e8f5e9,stroke:#1b5e20
```

---

## Security Checklist

```mermaid
flowchart TD
    subgraph Critical["CRITICAL"]
        C1[Backup priv_validator_key.json]
        C2[Secure MNEMONICS_BACKUP.txt]
        C3[Never expose validator key]
    end

    subgraph Important["Important"]
        I1[Configure firewall]
        I2[Use SSH keys, not passwords]
        I3[Enable systemd auto-restart]
        I4[Set minimum-gas-prices]
    end

    subgraph Recommended["Recommended"]
        R1[Setup monitoring/alerting]
        R2[Configure TLS for API]
        R3[Regular backups]
        R4[Log rotation]
    end

    style Critical fill:#ffcdd2,stroke:#c62828
    style Important fill:#fff9c4,stroke:#f57f17
    style Recommended fill:#c8e6c9,stroke:#2e7d32
```

### Mnemonic Security

```mermaid
flowchart LR
    Generate[Generate Mnemonics] --> Backup[Backup to Secure Storage]
    Backup --> Encrypt[Encrypt with GPG]
    Encrypt --> MultiLoc[Store in Multiple Locations]
    MultiLoc --> Delete[Securely Delete Plaintext<br/>shred -u MNEMONICS_BACKUP.txt]

    style Delete fill:#c8e6c9,stroke:#2e7d32
```

---

## Troubleshooting

### Common Issues

```mermaid
flowchart TD
    Issue1[Node won't start] --> Check1{Check logs}
    Check1 --> Log1[journalctl -u pokerchaind -f]

    Issue2[Peers not connecting] --> Check2{Check config}
    Check2 --> Peer1[Verify persistent_peers in config.toml]
    Check2 --> Peer2[Check firewall allows :26656]
    Check2 --> Peer3[Verify external_address is set]

    Issue3[Genesis mismatch] --> Check3{Compare hashes}
    Check3 --> Hash1[sha256sum genesis.json on all nodes]
    Hash1 --> Fix1[Copy master genesis to all nodes]

    Issue4[Double signing] --> Check4{Check state}
    Check4 --> State1[Never run same validator on 2 machines!]
    Check4 --> State2[Check priv_validator_state.json]
```

### Useful Commands

| Task | Command |
|------|---------|
| Check logs | `journalctl -u pokerchaind -f` |
| Check sync status | `curl localhost:26657/status \| jq .result.sync_info` |
| Check peers | `curl localhost:26657/net_info \| jq .result.n_peers` |
| Restart node | `systemctl restart pokerchaind` |
| Check validators | `pokerchaind query staking validators` |

---

## Quick Reference

### Files to Backup

| File | Location | Purpose |
|------|----------|---------|
| `priv_validator_key.json` | `~/.pokerchain/config/` | Consensus signing |
| `node_key.json` | `~/.pokerchain/config/` | P2P identity |
| `MNEMONICS_BACKUP.txt` | `./production/` | Key recovery |

### Default Ports

| Port | Service | Protocol |
|------|---------|----------|
| 26656 | P2P | TCP |
| 26657 | RPC | HTTP |
| 1317 | REST API | HTTP |
| 9090 | gRPC | HTTP/2 |

### Initial Token Distribution

| Account | STAKE | USDC |
|---------|-------|------|
| Each Validator | 1,000,000 | 0 |
| Staked per Validator | 100,000 | - |

---

## Script Reference: Important Lines

### `setup-production-nodes.sh`

| Line(s) | Purpose | Code |
|---------|---------|------|
| **24-25** | Initial token amounts | `STAKE_AMOUNT="100000000000stake"`<br/>`INITIAL_BALANCE="1000000000000stake"` |
| **134-188** | Build binary for target architecture | `build_for_target()` function |
| **356-445** | Generate validator key from mnemonic | `generate_validator_key_from_mnemonic()` function |
| **478-559** | Collect node info (hostname, IP, moniker, mnemonic) | Interactive prompts per node |
| **628-721** | Initialize nodes and generate keys | Main node initialization loop |
| **676** | `pokerchaind init` command | `$CHAIN_BINARY init $NODE_MONIKER --chain-id $CHAIN_ID --home $NODE_HOME` |
| **707-710** | Create account key | `$CHAIN_BINARY keys add $NODE_MONIKER` |
| **743-749** | Add genesis accounts | `$CHAIN_BINARY genesis add-genesis-account` |
| **745** | Genesis account balance (STAKE only) | `$INITIAL_BALANCE` = 1,000,000 STAKE |
| **770-775** | Create gentx | `$CHAIN_BINARY genesis gentx $NODE_MONIKER $STAKE_AMOUNT` |
| **791** | Collect all gentx | `$CHAIN_BINARY genesis collect-gentxs` |
| **800-803** | Distribute final genesis | Copy genesis.json to all nodes |
| **827-835** | Build persistent_peers list | Excludes self, includes all other validators |
| **838** | Set persistent_peers in config.toml | `sed` replacement |
| **842-852** | Production P2P settings | External address, pex, max peers |
| **869-877** | Set minimum gas prices | `minimum-gas-prices = "0.001stake"` |
| **894-980** | Create deployment scripts | Per-node and master deploy scripts |
| **1036-1228** | Generate NODE_INFO.md | Documentation and instructions |

### `deploy-production-node.sh`

| Line(s) | Purpose | Code |
|---------|---------|------|
| **97-151** | Cleanup old installation | `cleanup_old_installation()` |
| **108-127** | Stop existing processes | `systemctl stop`, `pkill` |
| **131-141** | Backup existing data | Creates timestamped backup |
| **154-242** | Fetch binary from GitHub | `fetch_binary_from_github()` |
| **163** | Get latest release | GitHub API call |
| **190-215** | Download and verify checksum | SHA256 verification |
| **245-266** | Build binary locally | `build_binary()` with `GOOS=linux GOARCH=amd64` |
| **269-291** | Deploy binary to remote | `deploy_binary()` via SCP |
| **280** | SCP binary | `scp build/pokerchaind "$remote_user@$remote_host:/tmp/"` |
| **283** | Install to /usr/local/bin | `sudo mv /tmp/pokerchaind /usr/local/bin/` |
| **294-332** | Deploy configuration | `deploy_config()` |
| **310** | Copy config files | `scp -r "$node_dir/config/"* ...` |
| **320-326** | Set file permissions | `chmod 700`, `chmod 600` |
| **335-416** | Configure bridge | `configure_bridge()` |
| **388-412** | Bridge config template | Appended to app.toml |
| **527-598** | Verify file hashes | `verify_file_hashes()` |
| **543-554** | Binary hash comparison | `sha256sum` local vs remote |
| **561-573** | Genesis hash comparison | Ensures identical genesis |
| **502-524** | Start node | `start_node()` |
| **513** | Start systemd service | `sudo systemctl start pokerchaind` |
| **601-635** | Verify deployment | `verify_deployment()` |
| **616** | Check RPC responding | `curl localhost:26657/status` |

### `run-local-testnet.sh` (for comparison)

| Line(s) | Purpose | Code |
|---------|---------|------|
| **215** | Get validator address | `pokerchaind keys show validator -a` |
| **220** | Add genesis account | `pokerchaind genesis add-genesis-account "$validator_addr" 1000000000000stake` |
| **224-227** | Create gentx | `pokerchaind genesis gentx validator 5000000000stake` |

### Key Differences: Local vs Production

| Aspect | `run-local-testnet.sh` | `setup-production-nodes.sh` |
|--------|------------------------|----------------------------|
| Stake amount | 5,000 STAKE (line 224) | 100,000 STAKE (line 24) |
| Key generation | Random | Mnemonic-based (recoverable) |
| Output | `~/.pokerchain-testnet/` | `./production/nodeX/` |
| Deployment | Local only | SSH to remote servers |
| Genesis accounts | Single validator | Multiple validators |

---

## Summary

1. **Run `setup-production-nodes.sh`** on your development machine
   - Generates all configs in `./production/`
   - Creates deployment scripts

2. **Run `deploy-production-node.sh`** for each node
   - Or use `./production/deploy-all.sh` to deploy all at once
   - Installs binary, config, systemd service

3. **Secure your keys**
   - Backup `priv_validator_key.json`
   - Encrypt and store `MNEMONICS_BACKUP.txt`

4. **Verify the network**
   - All nodes should connect as peers
   - All validators should be in the active set
