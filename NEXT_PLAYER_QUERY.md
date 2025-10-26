# Next Player To Act Query

## Overview
Added a new query endpoint `NextPlayerToAct` to the poker module that retrieves the next player to act for a given game.

## Implementation Details

### Proto Definition
**File:** `proto/pokerchain/poker/v1/query.proto`

Added new RPC method:
```protobuf
rpc NextPlayerToAct(QueryNextPlayerToActRequest) returns (QueryNextPlayerToActResponse) {
  option (google.api.http).get = "/block52/pokerchain/poker/v1/next_player_to_act/{game_id}";
}
```

Request/Response messages:
```protobuf
message QueryNextPlayerToActRequest {
  string game_id = 1;
}

message QueryNextPlayerToActResponse {
  string next_player = 1;  // JSON string with next player details
}
```

### Keeper Implementation
**File:** `x/poker/keeper/query_next_player_to_act.go`

The query handler:
1. Validates the game ID
2. Retrieves the game state from `GameStates` collection
3. Uses the `NextToAct` index from `TexasHoldemStateDTO`
4. Returns detailed player information as JSON

### Response Format
The query returns a JSON object with the following fields:

```json
{
  "game_id": "game-123",
  "next_to_act": 2,
  "address": "cosmos1...",
  "seat": 2,
  "stack": "10000",
  "sum_of_bets": "50",
  "status": "ACTIVE",
  "is_dealer": false,
  "is_small_blind": false,
  "is_big_blind": true
}
```

## Usage

### CLI Query
```bash
pokerchaind query poker next-player-to-act <game_id>
```

Example:
```bash
pokerchaind query poker next-player-to-act game-123 --output json | jq .
```

### REST API
```
GET /block52/pokerchain/poker/v1/next_player_to_act/{game_id}
```

Example:
```bash
curl http://localhost:1317/block52/pokerchain/poker/v1/next_player_to_act/game-123 | jq .
```

### gRPC
```go
import "github.com/block52/pokerchain/x/poker/types"

// Create query client
queryClient := types.NewQueryClient(grpcConn)

// Make request
resp, err := queryClient.NextPlayerToAct(context.Background(), &types.QueryNextPlayerToActRequest{
    GameId: "game-123",
})
```

## Test Script
A test script is provided at `test/query-next-player-test.sh`:

```bash
./test/query-next-player-test.sh game-123
```

## Files Modified/Created

1. **proto/pokerchain/poker/v1/query.proto** - Added RPC definition
2. **x/poker/keeper/query_next_player_to_act.go** - Query handler implementation
3. **x/poker/types/query.pb.go** - Generated (via `make proto-gen`)
4. **x/poker/types/query.pb.gw.go** - Generated (via `make proto-gen`)
5. **test/query-next-player-test.sh** - Test script

## Building and Testing

1. Regenerate proto files:
   ```bash
   make proto-gen
   ```

2. Install the updated binary:
   ```bash
   make install
   ```

3. Restart your node if running

4. Test the query:
   ```bash
   ./test/query-next-player-test.sh <game_id>
   ```

## Notes

- The query uses the existing `GameStates` collection which stores `TexasHoldemStateDTO` objects
- The `NextToAct` field is an index into the `Players` array
- Error handling includes validation for empty game ID, non-existent games, and invalid player indices
- The response is returned as a JSON string for flexibility in client-side parsing
