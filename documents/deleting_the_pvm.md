# Deleting the PVM: Complete Migration to Cosmos Blockchain

**Status**: Planning
**Goal**: Eliminate the PVM (Poker Virtual Machine) entirely and move all game logic to Cosmos keeper
**Timeline**: 10-12 weeks (2.5-3 months)
**Last Updated**: November 13, 2025

---

## Executive Summary

The PVM is currently a **1.0MB TypeScript codebase** with **140 source files** acting as a centralized game server. Our goal is to migrate all poker game logic into the Cosmos blockchain keeper, making the system fully decentralized and eliminating the need for PVM infrastructure.

### Why Eliminate PVM?

**Current Architecture Problems:**
- ❌ Centralized server (single point of failure)
- ❌ Requires separate infrastructure (Node.js, MongoDB, Redis)
- ❌ RPC layer duplicates blockchain functionality
- ❌ State synchronization complexity (PVM ↔ Cosmos)
- ❌ Non-deterministic by default (requires careful timestamp/shuffle handling)

**Target Architecture Benefits:**
- ✅ Fully decentralized (validators run game logic)
- ✅ No infrastructure dependencies (just Cosmos chain)
- ✅ Single source of truth (blockchain state)
- ✅ Deterministic by design (all inputs from block)
- ✅ Trustless gameplay (verifiable on-chain)

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Migration Strategy](#migration-strategy)
3. [Component Migration Plan](#component-migration-plan)
4. [Critical Business Logic](#critical-business-logic)
5. [WebSocket Strategy](#websocket-strategy)
6. [Testing Strategy](#testing-strategy)
7. [Phased Implementation](#phased-implementation)
8. [Risk Assessment](#risk-assessment)
9. [Progress Tracker](#progress-tracker)

---

## Current State Analysis

### PVM Codebase Statistics

```
Total Files:        140 TypeScript files
Test Files:         74 test files
Lines of Code:      ~10,000+ lines
Key File:           texasHoldem.ts (1,769 lines)
WebSocket Server:   socketserver.ts (1,034 lines)
Action Classes:     16 actions (~3,000 lines)
Managers:           4 managers (~700 lines)
```

### What PVM Currently Does

1. **Game Logic Execution**: Validates and executes all poker actions
2. **State Management**: Maintains game state in memory + syncs to Cosmos
3. **WebSocket Broadcasting**: Real-time updates to all players
4. **Action Validation**: Ensures legal moves (bets, raises, folds, etc.)
5. **Winner Calculation**: Hand evaluation using `pokersolver` library
6. **Dealer Management**: Rotates dealer button, manages blinds
7. **RPC Server**: Exposes JSON-RPC interface for UI

### What Cosmos Keeper Currently Does

1. **State Storage**: Persists game state in collections
2. **Deck Shuffling**: Deterministic shuffle using block hash
3. **Transaction Handling**: Validates and routes actions to PVM
4. **Queries**: Exposes game state via gRPC/REST
5. **Timestamp Injection**: Provides deterministic timestamps

### The Gap: What Needs to Move

```
┌─────────────────────────────────────────────────────────┐
│                     CURRENT (PVM)                       │
├─────────────────────────────────────────────────────────┤
│ ✅ Deck Shuffling         → Already in Cosmos keeper   │
│ ✅ Timestamps             → Already in Cosmos keeper   │
│ ❌ Action Validation      → MUST MOVE                   │
│ ❌ Game Logic Execution   → MUST MOVE                   │
│ ❌ Winner Calculation     → MUST MOVE                   │
│ ❌ Round Management       → MUST MOVE                   │
│ ❌ Dealer Rotation        → MUST MOVE                   │
│ ❌ Bet Management         → MUST MOVE                   │
│ ❌ WebSocket Broadcast    → MUST MIGRATE/REPLACE       │
└─────────────────────────────────────────────────────────┘
```

---

## Migration Strategy

### Core Principle: "Port, Don't Rewrite"

We will systematically port TypeScript logic to Go, preserving the exact behavior while adapting to Cosmos patterns.

### Migration Approach

#### 1. **Incremental Migration** (Recommended ✅)
Migrate components one at a time, running PVM in parallel for validation.

**Phases:**
1. Port data structures (Player, Deck, GameOptions)
2. Port managers (BetManager, DealerManager)
3. Port actions one-by-one (test each)
4. Port game engine core logic
5. Deprecate PVM

**Pros:**
- Lower risk (can rollback anytime)
- Easier to test (compare PVM vs Cosmos)
- Gradual learning curve

**Cons:**
- Longer timeline
- Temporary dual maintenance

#### 2. **Big Bang Migration** (Not Recommended ❌)
Port everything at once, switch over simultaneously.

**Pros:**
- Faster completion
- Clean cutover

**Cons:**
- High risk
- Hard to debug issues
- No fallback

**Decision: Use Incremental Migration** ✅

---

## Component Migration Plan

### Phase 1: Core Data Structures (Week 1-2)

#### Files to Migrate

| TypeScript File | Go Target | Status | Priority |
|----------------|-----------|--------|----------|
| `models/player.ts` | `types/player.go` | ⏳ TODO | CRITICAL |
| `models/deck.ts` | `types/deck.go` | ⏳ TODO | CRITICAL |
| `engine/types.ts` | `types/game.go` | ⏳ TODO | CRITICAL |
| `sdk/src/types/game.ts` | `types/enums.go` | ⏳ TODO | CRITICAL |

#### Implementation Details

**Player Model** (`types/player.go`):
```go
type Player struct {
    Address         string         // Cosmos address
    Seat            int32          // 1-9
    Stack           sdk.Int        // Chip count (bigint equivalent)
    HoleCards       []Card         // 2 cards
    Status          PlayerStatus   // ACTIVE, FOLDED, ALL_IN, etc.
    LastAction      *Action        // Most recent action
    PreviousActions []Action       // Action history
    SumOfBets       sdk.Int        // Total bet in current round
    IsDealer        bool
    IsSmallBlind    bool
    IsBigBlind      bool
}

type PlayerStatus int32

const (
    PlayerStatusActive     PlayerStatus = 0
    PlayerStatusFolded     PlayerStatus = 1
    PlayerStatusAllIn      PlayerStatus = 2
    PlayerStatusShowing    PlayerStatus = 3
    PlayerStatusSittingOut PlayerStatus = 4
    PlayerStatusBusted     PlayerStatus = 5
)
```

**Deck Model** (`types/deck.go`):
```go
type Deck struct {
    Cards []Card  // 52 cards
    Top   int32   // Current position (next card to deal)
}

type Card struct {
    Suit  Suit    // SPADES, HEARTS, DIAMONDS, CLUBS
    Rank  Rank    // TWO through ACE
}

func (d *Deck) Deal(count int) []Card {
    cards := d.Cards[d.Top : d.Top+int32(count)]
    d.Top += int32(count)
    return cards
}

func (d *Deck) ToString() string {
    // Format: "AS-KD-QH-[JC]-TC-9S..."
    // [brackets] indicate current position
}

func NewDeckFromString(s string) (*Deck, error) {
    // Parse deck string, find [position] marker
}
```

**Testing Requirements:**
- ✅ Serialize/deserialize player state
- ✅ Player action history tracking
- ✅ Deck dealing in correct order
- ✅ Deck string serialization matches TypeScript

---

### Phase 2: Managers (Week 3-4)

#### BetManager (`keeper/bet_manager.go`)

**Source**: `poker-vm/pvm/ts/src/engine/managers/betManager.ts` (206 lines)

**Purpose**: Tracks bets for a round, calculates raises, determines betting completion

**Critical Methods**:
```go
type BetManager struct {
    bets  map[string]sdk.Int  // playerId -> total bet
    turns []Action            // All actions in round
}

// Add action to bet tracking
func (bm *BetManager) Add(action Action) {
    bm.bets[action.PlayerId] = bm.bets[action.PlayerId].Add(action.Amount)
    bm.turns = append(bm.turns, action)
}

// Get largest bet in round
func (bm *BetManager) GetLargestBet() sdk.Int {
    max := sdk.ZeroInt()
    for _, bet := range bm.bets {
        if bet.GT(max) {
            max = bet
        }
    }
    return max
}

// Calculate size of last raise (for minimum re-raise)
func (bm *BetManager) GetRaisedAmount() sdk.Int {
    // Complex logic: find last bet/raise, calculate delta
    // See poker-vm/pvm/ts/src/engine/managers/betManager.ts:167-205
}

// Calculate amount needed to call
func (bm *BetManager) GetCallAmount(playerId string) sdk.Int {
    playerBet := bm.bets[playerId]
    largestBet := bm.GetLargestBet()
    return largestBet.Sub(playerBet)
}
```

**Testing Requirements:**
- ✅ Tracks bets across multiple players
- ✅ Correctly calculates call amount
- ✅ Correctly calculates minimum raise
- ✅ Handles 3-bet/4-bet scenarios
- ✅ Differentiates blinds from voluntary bets

**Migration Complexity**: MODERATE (complex raise calculation logic)

---

#### DealerManager (`keeper/dealer_manager.go`)

**Source**: `poker-vm/pvm/ts/src/engine/managers/dealerManager.ts` (231 lines)

**Purpose**: Manages dealer button rotation, blind positioning, handles player join/leave

**Critical Methods**:
```go
type DealerManager struct {
    game GameInterface  // Reference to game state
}

// Get current dealer seat
func (dm *DealerManager) GetDealerPosition() int32

// Get small blind seat (next active after dealer)
func (dm *DealerManager) GetSmallBlindPosition() int32

// Get big blind seat (next active after SB)
func (dm *DealerManager) GetBigBlindPosition() int32

// Rotate dealer for new hand
func (dm *DealerManager) RotateDealer() int32 {
    currentDealer := dm.game.GetDealerSeat()
    nextDealer := dm.FindNextActivePlayer(currentDealer)
    return nextDealer
}

// Find next active player clockwise from seat
func (dm *DealerManager) FindNextActivePlayer(startSeat int32) int32 {
    // Skip SITTING_OUT and BUSTED players
    // Wrap around table (seat 9 -> seat 1)
}

// Handle player joining table
func (dm *DealerManager) HandlePlayerJoin(seat int32) {
    // If first player, they become dealer
    // If second player (heads-up), new player is dealer
}

// Handle player leaving table
func (dm *DealerManager) HandlePlayerLeave(seat int32) {
    // If dealer leaves, rotate to next active
}
```

**Special Cases**:
- **Heads-up**: Dealer is small blind (opposite of 3+ players)
- **Player joins mid-hand**: Don't adjust dealer until next hand
- **Dealer leaves**: Immediately rotate to next active player

**Testing Requirements:**
- ✅ Dealer rotates clockwise to next active player
- ✅ SB/BB positioned correctly
- ✅ Heads-up special case (dealer = SB)
- ✅ Skips SITTING_OUT players
- ✅ Handles dealer leaving mid-hand

**Migration Complexity**: HIGH (complex rotation logic + special cases)

---

#### BlindsManager (`keeper/blinds_manager.go`)

**Source**: `poker-vm/pvm/ts/src/engine/managers/blindsManager.ts`

**Purpose**: Determines blind amounts (static for cash, increasing for tournaments)

**Two Implementations**:

1. **CashGameBlindsManager** (Simple):
```go
type CashGameBlindsManager struct {
    smallBlind sdk.Int
    bigBlind   sdk.Int
}

func (bm *CashGameBlindsManager) GetSmallBlind() sdk.Int {
    return bm.smallBlind
}

func (bm *CashGameBlindsManager) GetBigBlind() sdk.Int {
    return bm.bigBlind
}
```

2. **TournamentBlindsManager** (Time-based):
```go
type TournamentBlindsManager struct {
    startTime     time.Time
    blindSchedule []BlindLevel
}

type BlindLevel struct {
    DurationMinutes int32
    SmallBlind      sdk.Int
    BigBlind        sdk.Int
}

func (bm *TournamentBlindsManager) GetCurrentLevel() BlindLevel {
    elapsed := time.Since(bm.startTime)
    // Find level based on elapsed time
}
```

**Testing Requirements**:
- ✅ Cash game returns fixed blinds
- ✅ Tournament increases blinds on schedule
- ✅ Blind levels calculated from block time (not Date.now())

**Migration Complexity**: LOW (simple logic)

---

#### PayoutManager (`keeper/payout_manager.go`)

**Source**: `poker-vm/pvm/ts/src/engine/managers/payoutManager.ts` (67 lines)

**Purpose**: Calculates tournament prize pool distribution

```go
type PayoutManager struct {
    prizePool  sdk.Int
    payoutPcts []sdk.Dec  // [0.50, 0.30, 0.20] = 1st, 2nd, 3rd
}

func (pm *PayoutManager) CalculatePayout(place int32) sdk.Int {
    if place > len(pm.payoutPcts) {
        return sdk.ZeroInt()
    }
    pct := pm.payoutPcts[place-1]
    return pct.MulInt(pm.prizePool).TruncateInt()
}
```

**Testing Requirements**:
- ✅ Correct percentage calculation
- ✅ Handles rounding
- ✅ Returns zero for out-of-money places

**Migration Complexity**: LOW

---

### Phase 3: Action Classes (Week 5-7)

#### Action Architecture

All actions inherit from `BaseAction` which provides:
- 3-phase validation framework
- Turn validation helpers
- Chip balance validation
- Execution template

**Base Action Pattern**:
```go
type Action interface {
    Verify(player *Player, game *Game) (min, max sdk.Int, err error)
    Execute(player *Player, game *Game, amount sdk.Int) error
}

type BaseAction struct {
    game *Game
}

// Verify checks:
// 1. Is it player's turn?
// 2. Is player ACTIVE (not FOLDED/ALL_IN/etc)?
// 3. Is action valid for current round?
// 4. Does player have enough chips?
func (ba *BaseAction) VerifyPlayerTurn(player *Player) error {
    nextToAct := ba.game.GetNextPlayerToAct()
    if player.Address != nextToAct {
        return fmt.Errorf("not player's turn")
    }
    return nil
}

func (ba *BaseAction) VerifyPlayerActive(player *Player) error {
    if player.Status != PlayerStatusActive {
        return fmt.Errorf("player not active")
    }
    return nil
}
```

#### Migration Priority Order

| Action | Priority | Complexity | Status |
|--------|----------|------------|--------|
| **SmallBlindAction** | 1 | LOW | ⏳ TODO |
| **BigBlindAction** | 1 | LOW | ⏳ TODO |
| **DealAction** | 1 | MEDIUM | ⏳ TODO |
| **FoldAction** | 2 | LOW | ⏳ TODO |
| **CheckAction** | 2 | LOW | ⏳ TODO |
| **CallAction** | 2 | MEDIUM | ⏳ TODO |
| **BetAction** | 3 | MEDIUM | ⏳ TODO |
| **RaiseAction** | 3 | HIGH | ⏳ TODO |
| **AllInAction** | 3 | HIGH | ⏳ TODO |
| **ShowAction** | 4 | LOW | ⏳ TODO |
| **MuckAction** | 4 | LOW | ⏳ TODO |
| **JoinAction** | 5 | MEDIUM | ⏳ TODO |
| **LeaveAction** | 5 | MEDIUM | ⏳ TODO |
| **NewHandAction** | 6 | MEDIUM | ⏳ TODO |
| **SitInAction** | 7 | LOW | ⏳ TODO |
| **SitOutAction** | 7 | LOW | ⏳ TODO |

**Rationale**: Migrate in order of gameplay flow (blinds → deal → betting → showdown → new hand → optional actions)

---

#### Action Implementation Examples

##### CallAction (`keeper/actions/call.go`)

**Source**: `poker-vm/pvm/ts/src/engine/actions/callAction.ts` (129 lines)

```go
type CallAction struct {
    BaseAction
}

func (a *CallAction) Verify(player *Player, game *Game) (sdk.Int, sdk.Int, error) {
    // Standard validations
    if err := a.VerifyPlayerTurn(player); err != nil {
        return sdk.ZeroInt(), sdk.ZeroInt(), err
    }
    if err := a.VerifyPlayerActive(player); err != nil {
        return sdk.ZeroInt(), sdk.ZeroInt(), err
    }

    // Get current round's bet manager
    betMgr := game.GetBetManager(game.CurrentRound)

    // Calculate call amount
    callAmount := betMgr.GetCallAmount(player.Address)

    if callAmount.IsZero() {
        return sdk.ZeroInt(), sdk.ZeroInt(), fmt.Errorf("no bet to call, use CHECK")
    }

    // If player doesn't have enough, they can only go all-in
    if player.Stack.LT(callAmount) {
        return player.Stack, player.Stack, nil  // All-in
    }

    return callAmount, callAmount, nil
}

func (a *CallAction) Execute(player *Player, game *Game, amount sdk.Int) error {
    // Deduct chips
    player.Stack = player.Stack.Sub(amount)

    // If player called all-in, update status
    if player.Stack.IsZero() {
        player.Status = PlayerStatusAllIn
    }

    // Add action to history
    game.AddAction(Action{
        PlayerId:  player.Address,
        Type:      ActionTypeCall,
        Amount:    amount,
        Round:     game.CurrentRound,
        Timestamp: game.GetBlockTime(),
    })

    return nil
}
```

**Testing Requirements**:
- ✅ Calculates correct call amount
- ✅ Handles all-in when insufficient chips
- ✅ Rejects call when no bet exists
- ✅ Updates player status to ALL_IN when calling all chips

---

##### RaiseAction (`keeper/actions/raise.go`)

**Source**: `poker-vm/pvm/ts/src/engine/actions/raiseAction.ts` (168 lines)

**Most Complex Action** - Handles minimum raise sizing

```go
type RaiseAction struct {
    BaseAction
}

func (a *RaiseAction) Verify(player *Player, game *Game) (sdk.Int, sdk.Int, error) {
    // Standard validations
    if err := a.VerifyPlayerTurn(player); err != nil {
        return sdk.ZeroInt(), sdk.ZeroInt(), err
    }
    if err := a.VerifyPlayerActive(player); err != nil {
        return sdk.ZeroInt(), sdk.ZeroInt(), err
    }

    betMgr := game.GetBetManager(game.CurrentRound)

    // Must have existing bet to raise
    largestBet := betMgr.GetLargestBet()
    if largestBet.IsZero() {
        return sdk.ZeroInt(), sdk.ZeroInt(), fmt.Errorf("no bet to raise, use BET")
    }

    // Calculate minimum raise
    // Minimum = current bet + size of last raise
    raisedAmount := betMgr.GetRaisedAmount()
    minRaise := largestBet.Add(raisedAmount)

    // Example: BB=100, raise to 300 (raise by 200)
    // Next raise must be at least 300 + 200 = 500

    maxRaise := player.Stack

    if player.Stack.LT(minRaise) {
        return sdk.ZeroInt(), sdk.ZeroInt(), fmt.Errorf("insufficient chips for minimum raise, use CALL or ALL_IN")
    }

    return minRaise, maxRaise, nil
}

func (a *RaiseAction) Execute(player *Player, game *Game, amount sdk.Int) error {
    // Deduct chips
    player.Stack = player.Stack.Sub(amount)

    // Check if raise was all-in
    if player.Stack.IsZero() {
        player.Status = PlayerStatusAllIn
    }

    // Add action to history
    game.AddAction(Action{
        PlayerId:  player.Address,
        Type:      ActionTypeRaise,
        Amount:    amount,
        Round:     game.CurrentRound,
        Timestamp: game.GetBlockTime(),
    })

    return nil
}
```

**Testing Requirements**:
- ✅ Minimum raise = current bet + last raise size
- ✅ Handles 3-bet/4-bet scenarios
- ✅ Differentiates blinds from voluntary raises
- ✅ Rejects insufficient raise amounts
- ✅ Allows all-in below minimum raise

---

##### DealAction (`keeper/actions/deal.go`)

**Source**: `poker-vm/pvm/ts/src/engine/actions/dealAction.ts` (167 lines)

**Critical** - Deals hole cards and pre-deals community cards

```go
type DealAction struct {
    BaseAction
}

func (a *DealAction) Verify(player *Player, game *Game) (sdk.Int, sdk.Int, error) {
    // Must be in ANTE round
    if game.CurrentRound != RoundAnte {
        return sdk.ZeroInt(), sdk.ZeroInt(), fmt.Errorf("can only deal in ANTE round")
    }

    // Both blinds must be posted
    actions := game.GetActionsForRound(RoundAnte)
    hasSmallBlind := false
    hasBigBlind := false
    for _, action := range actions {
        if action.Type == ActionTypeSmallBlind {
            hasSmallBlind = true
        }
        if action.Type == ActionTypeBigBlind {
            hasBigBlind = true
        }
    }

    if !hasSmallBlind || !hasBigBlind {
        return sdk.ZeroInt(), sdk.ZeroInt(), fmt.Errorf("both blinds must be posted before deal")
    }

    return sdk.ZeroInt(), sdk.ZeroInt(), nil
}

func (a *DealAction) Execute(player *Player, game *Game, amount sdk.Int) error {
    // Deal 2 hole cards to each active player
    activePlayers := game.GetActivePlayers()
    for _, p := range activePlayers {
        p.HoleCards = game.Deck.Deal(2)
    }

    // Pre-deal 5 community cards for determinism
    // Store in game._communityCards2
    // Will be revealed during flop/turn/river
    game.CommunityCards2 = game.Deck.Deal(5)

    // Advance round to PREFLOP
    game.CurrentRound = RoundPreflop

    // Reset action tracking for new round
    game.ResetRoundActions()

    // Add action to history
    game.AddAction(Action{
        PlayerId:  player.Address,
        Type:      ActionTypeDeal,
        Round:     RoundAnte,
        Timestamp: game.GetBlockTime(),
    })

    return nil
}
```

**Testing Requirements**:
- ✅ Validates both blinds posted
- ✅ Deals 2 cards to each player
- ✅ Pre-deals 5 community cards
- ✅ Advances to PREFLOP
- ✅ Cards are dealt in deterministic order

---

### Phase 4: Game Engine Core (Week 8-9)

#### TexasHoldemGame (`keeper/game_logic.go`)

**Source**: `poker-vm/pvm/ts/src/engine/texasHoldem.ts` (1,769 lines)

**Most Critical File** - Core game orchestration

**Key State**:
```go
type Game struct {
    Address          string                  // Game ID
    GameOptions      GameOptions             // Table config
    Players          map[int32]*Player       // Seat -> Player
    Deck             *Deck                   // Shuffled deck
    CommunityCards   []Card                  // Visible cards (0, 3, 4, or 5)
    CommunityCards2  []Card                  // Pre-dealt cards (for determinism)
    CurrentRound     Round                   // ANTE, PREFLOP, FLOP, TURN, RIVER, SHOWDOWN, END
    HandNumber       int32                   // Hand counter
    ActionCount      int32                   // Action counter
    PreviousActions  []Action                // Action history
    Pots             []sdk.Int               // Main pot + side pots
    Winners          []Winner                // Showdown winners
    DealerSeat       int32                   // Dealer button position
}
```

**Critical Methods**:

1. **PerformAction** - Main entry point
```go
func (g *Game) PerformAction(playerId string, actionType ActionType, amount sdk.Int) error {
    player := g.GetPlayer(playerId)

    // Get action implementation
    var action Action
    switch actionType {
    case ActionTypeBet:
        action = &BetAction{BaseAction{game: g}}
    case ActionTypeCall:
        action = &CallAction{BaseAction{game: g}}
    // ... all 16 actions
    }

    // Verify action is legal
    min, max, err := action.Verify(player, g)
    if err != nil {
        return err
    }

    // Validate amount is in range
    if amount.LT(min) || amount.GT(max) {
        return fmt.Errorf("amount out of range [%s, %s]", min, max)
    }

    // Execute action
    if err := action.Execute(player, g, amount); err != nil {
        return err
    }

    // Check if round ended
    if g.HasRoundEnded() {
        if err := g.AdvanceRound(); err != nil {
            return err
        }
    }

    return nil
}
```

2. **HasRoundEnded** - Complex round completion detection
```go
func (g *Game) HasRoundEnded() bool {
    // Get live players (not folded/busted/sitting out)
    livePlayers := g.GetLivePlayers()

    // If only 1 live player, they win by default
    if len(livePlayers) == 1 {
        return true  // Go to showdown
    }

    // Get active players (can still act)
    activePlayers := g.GetActivePlayers()

    // If no active players, everyone all-in
    if len(activePlayers) == 0 {
        return true  // Go to showdown
    }

    // ANTE round: Check blinds posted AND cards dealt
    if g.CurrentRound == RoundAnte {
        hasSB := g.HasAction(ActionTypeSmallBlind)
        hasBB := g.HasAction(ActionTypeBigBlind)
        hasDealt := g.HasAction(ActionTypeDeal)
        return hasSB && hasBB && hasDealt
    }

    // SHOWDOWN: Check all live players showed/mucked
    if g.CurrentRound == RoundShowdown {
        for _, p := range livePlayers {
            if p.Status != PlayerStatusShowing {
                return false
            }
        }
        return true
    }

    // All-in scenario: Skip betting rounds
    if g.AllActivePlayersAllIn() {
        return true
    }

    // Check all active players have acted
    for _, p := range activePlayers {
        if p.LastAction == nil {
            return false  // Player hasn't acted yet
        }
    }

    // Check all bets are equal
    betMgr := g.GetBetManager(g.CurrentRound)
    largestBet := betMgr.GetLargestBet()
    for _, p := range activePlayers {
        playerBet := betMgr.GetTotalBetsForPlayer(p.Address)
        if !playerBet.Equal(largestBet) {
            return false  // Bets not equal
        }
    }

    // PREFLOP special case: If no raises, just calls
    if g.CurrentRound == RoundPreflop {
        hasRaise := false
        for _, action := range g.GetActionsForRound(RoundPreflop) {
            if action.Type == ActionTypeRaise || action.Type == ActionTypeBet {
                hasRaise = true
                break
            }
        }
        if !hasRaise {
            return true  // Everyone checked/called, round ends
        }
    }

    return true
}
```

**Testing Requirements**: (CRITICAL - 159 lines of complex logic)
- ✅ Single player remaining wins immediately
- ✅ All-in scenario skips betting
- ✅ ANTE requires both blinds + deal
- ✅ SHOWDOWN requires all players show/muck
- ✅ Active players must all act
- ✅ All bets must be equal
- ✅ PREFLOP special case (no raises = checks)
- ✅ Last aggressor tracking
- ✅ Multi-way all-in handling

3. **AdvanceRound** - Move to next round
```go
func (g *Game) AdvanceRound() error {
    switch g.CurrentRound {
    case RoundAnte:
        g.CurrentRound = RoundPreflop

    case RoundPreflop:
        // Deal flop (3 cards from pre-dealt)
        g.CommunityCards = g.CommunityCards2[0:3]
        g.CurrentRound = RoundFlop

    case RoundFlop:
        // Deal turn (1 card)
        g.CommunityCards = append(g.CommunityCards, g.CommunityCards2[3])
        g.CurrentRound = RoundTurn

    case RoundTurn:
        // Deal river (1 card)
        g.CommunityCards = append(g.CommunityCards, g.CommunityCards2[4])
        g.CurrentRound = RoundRiver

    case RoundRiver:
        g.CurrentRound = RoundShowdown

    case RoundShowdown:
        // Calculate winner
        if err := g.CalculateWinner(); err != nil {
            return err
        }
        g.CurrentRound = RoundEnd
    }

    // Reset action tracking for new round
    g.ResetRoundActions()

    return nil
}
```

4. **CalculateWinner** - Hand evaluation
```go
func (g *Game) CalculateWinner() error {
    // Get players who are showing cards
    showingPlayers := g.GetShowingPlayers()

    if len(showingPlayers) == 0 {
        return fmt.Errorf("no players showing")
    }

    // Build 7-card hands (2 hole + 5 community)
    hands := make([][]Card, len(showingPlayers))
    for i, p := range showingPlayers {
        hands[i] = append(p.HoleCards, g.CommunityCards...)
    }

    // Evaluate hands using poker library
    results, err := EvaluateShowdown(hands)
    if err != nil {
        return err
    }

    // Distribute pot(s) to winner(s)
    if err := g.DistributePots(results.Winners, showingPlayers); err != nil {
        return err
    }

    // Update player stacks
    for _, winner := range results.Winners {
        player := showingPlayers[winner.Index]
        player.Stack = player.Stack.Add(winner.Amount)
    }

    g.Winners = results.Winners

    return nil
}
```

**Hand Evaluation Challenge**:
- Need Go poker library equivalent to `pokersolver`
- Must handle all hand types (high card to royal flush)
- Must handle kickers correctly
- Must handle split pots

**Options**:
1. Use existing Go library (e.g., `github.com/chehsunliu/poker`)
2. Port `pokersolver` to Go
3. FFI bridge to call JavaScript library (not recommended)

**Recommendation**: Research Go poker libraries, test against `pokersolver` for consistency

---

## Critical Business Logic

### 1. Hand Evaluation (CRITICAL PATH)

**Current Implementation**: Uses `pokersolver` npm package (JavaScript)

**Migration Requirements**:
- Find or build Go poker hand evaluator
- Must support 7-card evaluation (2 hole + 5 community)
- Must return winning hands + rankings
- Must handle kickers correctly

**Go Library Options**:

| Library | Stars | Last Updated | Notes |
|---------|-------|--------------|-------|
| `github.com/chehsunliu/poker` | 150+ | 2023 | Mature, 7-card evaluator |
| `github.com/montanaflynn/holdem` | 50+ | 2021 | Texas Hold'em specific |
| `github.com/loganjspears/joker` | 100+ | 2022 | Fast, lightweight |

**Testing Strategy**:
1. Generate 10,000 random hands
2. Evaluate with `pokersolver` (JavaScript)
3. Evaluate with Go library
4. Compare results (must match 100%)

**Fallback Plan**: Port `pokersolver` algorithm to Go (high effort, ~1 week)

---

### 2. Round End Detection (CRITICAL PATH)

**Source**: `hasRoundEnded()` - 159 lines of complex logic

**Edge Cases to Handle**:
- Single player remaining (wins by default)
- All-in scenarios (skip betting rounds)
- Multi-way all-in (multiple pots)
- Last aggressor tracking (for betting completion)
- PREFLOP special case (blinds count as raises)
- Heads-up vs multi-player differences

**Testing Priority**: HIGHEST
- Must port all existing test cases
- Add new edge case tests
- Regression test against PVM

---

### 3. Dealer Rotation (HIGH PRIORITY)

**Source**: `DealerPositionManager` - 231 lines

**Special Cases**:
- Heads-up: Dealer is small blind (reversed from 3+ players)
- Player joins: Don't adjust dealer until next hand
- Player leaves: Rotate dealer if they were dealer
- Skip inactive players: SITTING_OUT, BUSTED

**Testing Priority**: HIGH
- Test rotation logic
- Test heads-up special case
- Test player join/leave scenarios

---

### 4. Bet Validation (HIGH PRIORITY)

**Source**: `BetManager.getRaisedAmount()` - Complex raise sizing

**Critical Logic**:
- Minimum raise = current bet + size of last raise
- Differentiate blinds from voluntary bets
- Handle 3-bet/4-bet scenarios
- All-in can be below minimum raise

**Testing Priority**: HIGH
- Test minimum raise calculations
- Test 3-bet/4-bet scenarios
- Test all-in below minimum

---

## WebSocket Strategy

### Current Architecture

```
PVM WebSocket Server (socketserver.ts)
├── Maintains connections: Map<tableAddress, Map<playerId, WebSocket>>
├── On action: Fetch game state from Cosmos → Broadcast to all subscribers
├── Personalized state: Filters hole cards based on playerId
└── Logging: Detailed logs per player
```

### Option A: Thin PVM Relay (RECOMMENDED ✅)

**Architecture**:
```
Cosmos Chain
  ↓ (Events via Tendermint WebSocket)
PVM WebSocket Relay
  ├── Subscribes to: EventGameStateUpdated
  ├── On event: Fetch game state from Cosmos REST
  ├── Personalize: Filter hole cards per player
  └── Broadcast: Send to all table subscribers
  ↓
UI (React)
```

**Pros**:
- Minimal UI changes
- Can personalize game state (hide others' hole cards)
- Can be run by anyone (decentralized)
- Simple to implement

**Cons**:
- Still requires PVM infrastructure (but much simpler)

**Implementation**:
```go
// Thin relay service
type WebSocketRelay struct {
    cosmosWSClient *tmclient.Client  // Tendermint WS
    cosmosRESTURL  string
    subscribers    map[string]map[string]*websocket.Conn  // table -> player -> conn
}

func (r *WebSocketRelay) Start() {
    // Subscribe to Cosmos events
    query := "tm.event='Tx' AND message.module='poker'"
    r.cosmosWSClient.Subscribe(query, func(event tmtypes.ResultEvent) {
        // Extract gameId from event
        gameId := event.Attributes["gameId"]

        // Fetch updated game state from REST
        gameState := r.fetchGameState(gameId)

        // Broadcast to all subscribers at this table
        for playerId, conn := range r.subscribers[gameId] {
            // Personalize: Hide other players' hole cards
            personalizedState := r.personalizeState(gameState, playerId)

            conn.WriteJSON(personalizedState)
        }
    })
}
```

**Deployment**:
- Run as separate service (can be on validators or separate servers)
- Docker container
- Systemd service

---

### Option B: Direct Cosmos WebSocket (FUTURE)

**Architecture**:
```
Cosmos Chain (Tendermint WebSocket)
  ↓ (Direct subscription)
UI (React)
  ├── Subscribes to: tm.event='Tx' AND poker.table='{address}'
  ├── On event: Fetch game state from Cosmos REST
  └── Apply locally: Filter hole cards client-side
```

**Pros**:
- Fully decentralized (no PVM infrastructure)
- Direct connection to blockchain

**Cons**:
- Exposes all hole cards (must filter client-side)
- More complex UI code
- Tendermint WS can be unreliable (reconnection logic)

**Recommendation**: Start with Option A (relay), migrate to Option B later

---

### Option C: Cosmos Events + gRPC Streaming

**Architecture**:
```
Cosmos Chain
  ↓ (Emit EventGameStateUpdated)
Custom gRPC Streaming Service
  ├── Listens to events via gRPC stream
  ├── Fetches game state
  └── Streams to UI via gRPC
  ↓
UI (gRPC client)
```

**Pros**:
- Built-in to Cosmos ecosystem
- Type-safe (Protobuf)

**Cons**:
- Requires gRPC support in UI (added complexity)
- Less common pattern for browser apps

---

### Recommendation: Phased Approach

**Phase 1** (Immediate): Keep current PVM WebSocket
- Continue using existing socketserver.ts
- No UI changes needed
- Focus on migrating game logic first

**Phase 2** (Mid-term): Thin relay service
- Build Go-based relay service
- Subscribe to Cosmos events
- Broadcast to WebSocket clients
- Shut down PVM game logic, keep WS relay

**Phase 3** (Long-term): Direct Cosmos connection
- Update UI to connect to Tendermint WS
- Client-side game state fetching
- Fully decentralized

---

## Testing Strategy

### Current Test Coverage

**74 test files** covering:
- Action validation (38 files)
- Game scenarios (36 files)
  - Headsup
  - Multiplayer
  - All-in scenarios
  - Side pots
  - Round progression
  - Winner calculation

### Migration Testing Approach

#### 1. Unit Tests (Go)

Port all 74 test files to Go:

```go
// Example: keeper/actions/call_test.go
func TestCallAction_Verify(t *testing.T) {
    game := setupTestGame()
    player := game.Players[1]

    // Post big blind first
    game.PerformAction(player.Address, ActionTypeBigBlind, sdk.NewInt(20000))

    // Next player should be able to call
    action := &CallAction{BaseAction{game}}
    min, max, err := action.Verify(game.Players[2], game)

    require.NoError(t, err)
    require.Equal(t, sdk.NewInt(20000), min)
    require.Equal(t, sdk.NewInt(20000), max)
}
```

**Coverage Goals**:
- ✅ Every action has 5+ test cases
- ✅ All edge cases covered
- ✅ Error conditions tested

#### 2. Integration Tests (Cosmos)

Test via Cosmos SDK testing utilities:

```go
func TestKeeper_PerformActionIntegration(t *testing.T) {
    k, ctx := setupKeeper(t)

    // Create game
    gameId := createTestGame(k, ctx)

    // Join players
    joinGame(k, ctx, gameId, "alice", 1, 1000000)
    joinGame(k, ctx, gameId, "bob", 2, 1000000)

    // Post blinds
    msgSB := types.NewMsgPerformAction("bob", gameId, "post-small-blind", 10000)
    _, err := k.PerformAction(ctx, msgSB)
    require.NoError(t, err)

    msgBB := types.NewMsgPerformAction("alice", gameId, "post-big-blind", 20000)
    _, err = k.PerformAction(ctx, msgBB)
    require.NoError(t, err)

    // Verify game state
    state, err := k.GameStates.Get(ctx, gameId)
    require.NoError(t, err)
    require.Equal(t, "ante", state.Round)
    require.Len(t, state.PreviousActions, 2)
}
```

#### 3. Parallel Testing (PVM vs Cosmos)

Run same game scenario through both systems, compare results:

```go
func TestParallelExecution(t *testing.T) {
    // Setup
    pvmClient := setupPVMClient()
    cosmosKeeper := setupKeeper(t)

    // Create identical games
    pvmGameId := pvmClient.CreateGame(gameOptions)
    cosmosGameId := createGame(cosmosKeeper, gameOptions)

    // Execute same action sequence
    actions := []Action{
        {Type: "post-small-blind", Player: "alice", Amount: 10000},
        {Type: "post-big-blind", Player: "bob", Amount: 20000},
        {Type: "deal", Player: "alice"},
        // ... 50 more actions
    }

    for _, action := range actions {
        // Execute on PVM
        pvmState := pvmClient.PerformAction(pvmGameId, action)

        // Execute on Cosmos
        cosmosState := cosmosKeeper.PerformAction(ctx, action)

        // Compare states
        require.Equal(t, pvmState.Round, cosmosState.Round)
        require.Equal(t, pvmState.Pots, cosmosState.Pots)
        require.Equal(t, pvmState.NextToAct, cosmosState.NextToAct)
        // ... compare all fields
    }
}
```

#### 4. Regression Tests

**Recorded Gameplay Sessions**:
- Record 100+ real poker hands from current PVM
- Replay on Cosmos keeper
- Verify identical outcomes

```go
func TestRegressionHand001(t *testing.T) {
    // Load recorded hand from JSON
    hand := loadRecordedHand("testdata/hands/hand_001.json")

    // Replay on Cosmos
    cosmosState := replayHand(keeper, ctx, hand)

    // Verify winner matches
    require.Equal(t, hand.ExpectedWinner, cosmosState.Winners[0].Address)
    require.Equal(t, hand.ExpectedPayout, cosmosState.Winners[0].Amount)
}
```

---

## Phased Implementation

### Phase 1: Foundation (Week 1-2)

**Goal**: Port data structures and establish Go codebase structure

**Tasks**:
- [ ] Create Go package structure (`keeper/actions/`, `keeper/managers/`, `types/`)
- [ ] Port `Player` model to Go
- [ ] Port `Deck` model to Go
- [ ] Port `GameOptions` to Go
- [ ] Port enums (PlayerStatus, ActionType, Round)
- [ ] Write basic unit tests

**Deliverable**: Compiled Go package with data structures

**Success Criteria**:
- ✅ All data structures compile
- ✅ Serialization/deserialization works
- ✅ Basic unit tests pass

---

### Phase 2: Managers (Week 3-4)

**Goal**: Port helper classes that don't depend on full game logic

**Tasks**:
- [ ] Port `BetManager` to Go
- [ ] Port `DealerManager` to Go
- [ ] Port `BlindsManager` to Go (both Cash and Tournament)
- [ ] Port `PayoutManager` to Go
- [ ] Write comprehensive manager tests

**Deliverable**: Working manager implementations

**Success Criteria**:
- ✅ BetManager calculates raises correctly
- ✅ DealerManager rotates dealer properly
- ✅ All manager unit tests pass

---

### Phase 3: Actions (Week 5-7)

**Goal**: Port all 16 action implementations

**Week 5**: Basic Actions
- [ ] Port `BaseAction` framework
- [ ] Port `SmallBlindAction`
- [ ] Port `BigBlindAction`
- [ ] Port `FoldAction`
- [ ] Port `CheckAction`
- [ ] Write action unit tests

**Week 6**: Betting Actions
- [ ] Port `CallAction`
- [ ] Port `BetAction`
- [ ] Port `RaiseAction`
- [ ] Port `AllInAction`
- [ ] Write betting action tests

**Week 7**: Other Actions
- [ ] Port `DealAction`
- [ ] Port `ShowAction`
- [ ] Port `MuckAction`
- [ ] Port `JoinAction`
- [ ] Port `LeaveAction`
- [ ] Port `NewHandAction`
- [ ] Port `SitInAction` / `SitOutAction`
- [ ] Write comprehensive action tests

**Deliverable**: All 16 actions working in Go

**Success Criteria**:
- ✅ All actions compile
- ✅ All action unit tests pass
- ✅ Action validation works correctly

---

### Phase 4: Game Engine (Week 8-9)

**Goal**: Port core game orchestration logic

**Week 8**: Core Methods
- [ ] Port `TexasHoldemGame` struct
- [ ] Port `PerformAction()` method
- [ ] Port `GetNextPlayerToAct()` method
- [ ] Port player management methods
- [ ] Port deck dealing methods

**Week 9**: Round Logic
- [ ] Port `HasRoundEnded()` method (159 lines - CRITICAL)
- [ ] Port `AdvanceRound()` method
- [ ] Port community card dealing
- [ ] Port pot calculation
- [ ] Write game flow tests

**Deliverable**: Complete game engine in Go

**Success Criteria**:
- ✅ Full hand can be played start to finish
- ✅ Round transitions work correctly
- ✅ HasRoundEnded handles all edge cases

---

### Phase 5: Hand Evaluation (Week 10)

**Goal**: Integrate poker hand evaluator

**Tasks**:
- [ ] Research Go poker libraries
- [ ] Test candidates against `pokersolver`
- [ ] Integrate chosen library
- [ ] Port `CalculateWinner()` method
- [ ] Port side pot distribution logic
- [ ] Write showdown tests

**Deliverable**: Working winner calculation

**Success Criteria**:
- ✅ Winner correctly identified
- ✅ Pots distributed correctly
- ✅ Kickers handled properly
- ✅ Split pots work

---

### Phase 6: Cosmos Integration (Week 11)

**Goal**: Wire everything into Cosmos keeper

**Tasks**:
- [ ] Update `msg_server_perform_action.go` to use Go game engine
- [ ] Remove PVM RPC calls from keeper
- [ ] Update game state storage (collections)
- [ ] Implement all action handlers
- [ ] Write keeper integration tests

**Deliverable**: Cosmos chain with native game logic

**Success Criteria**:
- ✅ Can play full hand on Cosmos testnet
- ✅ No PVM calls in keeper
- ✅ State persists correctly
- ✅ Events emitted properly

---

### Phase 7: WebSocket Migration (Week 12)

**Goal**: Build WebSocket relay service

**Tasks**:
- [ ] Build Go WebSocket relay service
- [ ] Subscribe to Cosmos events
- [ ] Implement game state personalization
- [ ] Update UI to connect to relay
- [ ] Test real-time updates

**Deliverable**: Working WebSocket relay

**Success Criteria**:
- ✅ UI receives real-time updates
- ✅ Hole cards filtered properly
- ✅ Latency < 100ms

---

### Phase 8: Testing & Migration (Week 13-14)

**Goal**: Validate migration, test thoroughly

**Tasks**:
- [ ] Run parallel PVM + Cosmos testing
- [ ] Regression test 100+ hands
- [ ] Performance testing (100+ concurrent games)
- [ ] Security audit (keeper, actions)
- [ ] Load testing (WebSocket relay)

**Deliverable**: Production-ready system

**Success Criteria**:
- ✅ All tests pass
- ✅ Performance acceptable
- ✅ No security issues

---

### Phase 9: Deprecate PVM (Week 15)

**Goal**: Remove PVM infrastructure

**Tasks**:
- [ ] Remove PVM RPC server code
- [ ] Remove PVM game logic code
- [ ] Remove MongoDB/Redis dependencies
- [ ] Update documentation
- [ ] Archive PVM codebase

**Deliverable**: PVM fully eliminated

**Success Criteria**:
- ✅ System runs on Cosmos only
- ✅ No PVM infrastructure needed
- ✅ Documentation updated

---

## Risk Assessment

### High Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Go poker library doesn't match `pokersolver` results** | MEDIUM | HIGH | Build extensive test suite, compare 10,000+ hands. Fallback: Port pokersolver to Go. |
| **HasRoundEnded logic breaks edge cases** | MEDIUM | HIGH | Port all 74 test files. Run parallel testing PVM vs Cosmos for weeks. |
| **State size exceeds Cosmos limits** | LOW | MEDIUM | Benchmark early, optimize storage. Consider pruning old actions. |
| **WebSocket latency too high** | LOW | MEDIUM | Use Cosmos events for instant notifications. Benchmark against current PVM. |
| **Migration breaks existing games** | MEDIUM | HIGH | Run parallel systems. Snapshot PVM games before migration. Phased rollout. |
| **Dealer rotation breaks heads-up** | LOW | HIGH | Extensive testing of heads-up scenarios. |
| **Bet validation edge cases** | MEDIUM | HIGH | Port all bet-related tests. Test 3-bet/4-bet scenarios. |

### Medium Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Timeline slips beyond 15 weeks** | MEDIUM | MEDIUM | Build buffer time. Prioritize critical path. Can launch without tournament support. |
| **Performance issues with 100+ games** | LOW | MEDIUM | Benchmark early. Optimize state access. Consider caching. |
| **UI changes break existing users** | LOW | MEDIUM | Phased rollout. Maintain backward compatibility during migration. |

### Low Risk Items

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Go BigInt arithmetic issues** | LOW | LOW | Use Cosmos SDK math types. Test extensively. |
| **Enum mismatches TypeScript vs Go** | LOW | LOW | Define in Protobuf. Generate both TS and Go from same source. |

---

## Progress Tracker

### Phase 1: Foundation ⏳
- [ ] Create Go package structure
- [ ] Port Player model
- [ ] Port Deck model
- [ ] Port GameOptions
- [ ] Port enums
- [ ] Write basic unit tests

**Status**: NOT STARTED
**Target Completion**: Week 2

---

### Phase 2: Managers ⏳
- [ ] Port BetManager
- [ ] Port DealerManager
- [ ] Port BlindsManager
- [ ] Port PayoutManager
- [ ] Write manager tests

**Status**: NOT STARTED
**Target Completion**: Week 4

---

### Phase 3: Actions ⏳
- [ ] Port BaseAction
- [ ] Port SmallBlindAction
- [ ] Port BigBlindAction
- [ ] Port FoldAction
- [ ] Port CheckAction
- [ ] Port CallAction
- [ ] Port BetAction
- [ ] Port RaiseAction
- [ ] Port AllInAction
- [ ] Port DealAction
- [ ] Port ShowAction
- [ ] Port MuckAction
- [ ] Port JoinAction
- [ ] Port LeaveAction
- [ ] Port NewHandAction
- [ ] Port SitInAction
- [ ] Port SitOutAction

**Status**: NOT STARTED
**Target Completion**: Week 7

---

### Phase 4: Game Engine ⏳
- [ ] Port TexasHoldemGame struct
- [ ] Port PerformAction
- [ ] Port GetNextPlayerToAct
- [ ] Port HasRoundEnded
- [ ] Port AdvanceRound
- [ ] Port player management
- [ ] Write game flow tests

**Status**: NOT STARTED
**Target Completion**: Week 9

---

### Phase 5: Hand Evaluation ⏳
- [ ] Research Go poker libraries
- [ ] Test libraries vs pokersolver
- [ ] Integrate library
- [ ] Port CalculateWinner
- [ ] Port side pot logic
- [ ] Write showdown tests

**Status**: NOT STARTED
**Target Completion**: Week 10

---

### Phase 6: Cosmos Integration ⏳
- [ ] Update msg_server_perform_action
- [ ] Remove PVM RPC calls
- [ ] Update state storage
- [ ] Implement action handlers
- [ ] Write keeper tests

**Status**: NOT STARTED
**Target Completion**: Week 11

---

### Phase 7: WebSocket Migration ⏳
- [ ] Build WebSocket relay
- [ ] Subscribe to Cosmos events
- [ ] Personalize game state
- [ ] Update UI
- [ ] Test real-time updates

**Status**: NOT STARTED
**Target Completion**: Week 12

---

### Phase 8: Testing ⏳
- [ ] Parallel PVM + Cosmos testing
- [ ] Regression test 100+ hands
- [ ] Performance testing
- [ ] Security audit
- [ ] Load testing

**Status**: NOT STARTED
**Target Completion**: Week 14

---

### Phase 9: Deprecate PVM ⏳
- [ ] Remove PVM RPC server
- [ ] Remove PVM game logic
- [ ] Remove DB dependencies
- [ ] Update documentation
- [ ] Archive PVM codebase

**Status**: NOT STARTED
**Target Completion**: Week 15

---

## Next Steps

### Immediate Actions (This Week)

1. **Decision**: Approve migration strategy
2. **Research**: Evaluate Go poker hand evaluation libraries
3. **Setup**: Create keeper package structure
4. **Start**: Port Player and Deck models to Go

### Week 1 Checklist

- [ ] Create `/pokerchain/x/poker/keeper/actions/` directory
- [ ] Create `/pokerchain/x/poker/keeper/managers/` directory
- [ ] Port `types/player.go`
- [ ] Port `types/deck.go`
- [ ] Port `types/card.go`
- [ ] Write basic unit tests
- [ ] Verify serialization works

### Success Metrics

**Weekly**:
- All planned components ported
- Tests passing
- No regressions

**Monthly**:
- Phase completed on schedule
- Integration tests passing
- Documentation updated

**Final**:
- ✅ PVM completely removed
- ✅ All game logic in Cosmos keeper
- ✅ WebSocket relay operational
- ✅ 100% test coverage maintained
- ✅ Performance meets requirements
- ✅ Production deployment successful

---

## Appendix: File Mapping

### Complete TypeScript → Go Migration Map

| TypeScript Source | Go Target | Priority | Complexity | Status |
|-------------------|-----------|----------|------------|--------|
| **Models** |
| `models/player.ts` | `types/player.go` | CRITICAL | LOW | ⏳ |
| `models/deck.ts` | `types/deck.go` | CRITICAL | LOW | ⏳ |
| `engine/types.ts` | `types/game.go` | CRITICAL | LOW | ⏳ |
| **Managers** |
| `managers/betManager.ts` | `keeper/managers/bet_manager.go` | CRITICAL | MEDIUM | ⏳ |
| `managers/dealerManager.ts` | `keeper/managers/dealer_manager.go` | CRITICAL | HIGH | ⏳ |
| `managers/blindsManager.ts` | `keeper/managers/blinds_manager.go` | HIGH | LOW | ⏳ |
| `managers/payoutManager.ts` | `keeper/managers/payout_manager.go` | MEDIUM | LOW | ⏳ |
| **Actions** |
| `actions/baseAction.ts` | `keeper/actions/base.go` | CRITICAL | MEDIUM | ⏳ |
| `actions/smallBlindAction.ts` | `keeper/actions/small_blind.go` | CRITICAL | LOW | ⏳ |
| `actions/bigBlindAction.ts` | `keeper/actions/big_blind.go` | CRITICAL | LOW | ⏳ |
| `actions/dealAction.ts` | `keeper/actions/deal.go` | CRITICAL | MEDIUM | ⏳ |
| `actions/foldAction.ts` | `keeper/actions/fold.go` | CRITICAL | LOW | ⏳ |
| `actions/checkAction.ts` | `keeper/actions/check.go` | CRITICAL | LOW | ⏳ |
| `actions/callAction.ts` | `keeper/actions/call.go` | CRITICAL | MEDIUM | ⏳ |
| `actions/betAction.ts` | `keeper/actions/bet.go` | CRITICAL | MEDIUM | ⏳ |
| `actions/raiseAction.ts` | `keeper/actions/raise.go` | CRITICAL | HIGH | ⏳ |
| `actions/allInAction.ts` | `keeper/actions/all_in.go` | HIGH | HIGH | ⏳ |
| `actions/showAction.ts` | `keeper/actions/show.go` | HIGH | LOW | ⏳ |
| `actions/muckAction.ts` | `keeper/actions/muck.go` | HIGH | LOW | ⏳ |
| `actions/joinAction.ts` | `keeper/actions/join.go` | HIGH | MEDIUM | ⏳ |
| `actions/leaveAction.ts` | `keeper/actions/leave.go` | HIGH | MEDIUM | ⏳ |
| `actions/newHandAction.ts` | `keeper/actions/new_hand.go` | HIGH | MEDIUM | ⏳ |
| `actions/sitInAction.ts` | `keeper/actions/sit_in.go` | MEDIUM | LOW | ⏳ |
| `actions/sitOutAction.ts` | `keeper/actions/sit_out.go` | MEDIUM | LOW | ⏳ |
| **Game Engine** |
| `engine/texasHoldem.ts` | `keeper/game_logic.go` | CRITICAL | VERY HIGH | ⏳ |
| **Commands** (Deprecated) |
| `commands/cosmos/performActionCommand.ts` | N/A - Logic moves to keeper | N/A | N/A | ⏳ |
| `rpc.ts` | N/A - Use Cosmos gRPC | N/A | N/A | ⏳ |
| **WebSocket** |
| `core/socketserver.ts` | External relay service | HIGH | MEDIUM | ⏳ |

---

**End of Document**

---

## Document Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-13 | 1.0 | Initial document creation based on comprehensive PVM analysis |

---

**Maintained by**: Cosmos Poker Development Team
**Repository**: https://github.com/block52/pokerchain
**Questions**: Open an issue or discussion on GitHub
