package poker

import (
	autocliv1 "cosmossdk.io/api/cosmos/autocli/v1"

	"github.com/block52/pokerchain/x/poker/types"
)

// AutoCLIOptions implements the autocli.HasAutoCLIConfig interface.
func (am AppModule) AutoCLIOptions() *autocliv1.ModuleOptions {
	return &autocliv1.ModuleOptions{
		Query: &autocliv1.ServiceCommandDescriptor{
			Service: types.Query_serviceDesc.ServiceName,
			RpcCommandOptions: []*autocliv1.RpcCommandOptions{
				{
					RpcMethod: "Params",
					Use:       "params",
					Short:     "Shows the parameters of the module",
				},
				{
					RpcMethod:      "Game",
					Use:            "game [game-id]",
					Short:          "Query game",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}},
				},

				{
					RpcMethod:      "ListGames",
					Use:            "list-games ",
					Short:          "Query list-games",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{},
				},

				{
					RpcMethod:      "PlayerGames",
					Use:            "player-games [player-address]",
					Short:          "Query player-games",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "player_address"}},
				},

				{
					RpcMethod:      "LegalActions",
					Use:            "legal-actions [game-id] [player-address]",
					Short:          "Query legal-actions",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}, {ProtoField: "player_address"}},
				},

				// this line is used by ignite scaffolding # autocli/query
			},
		},
		Tx: &autocliv1.ServiceCommandDescriptor{
			Service:              types.Msg_serviceDesc.ServiceName,
			EnhanceCustomCommand: true, // only required if you want to use the custom command
			RpcCommandOptions: []*autocliv1.RpcCommandOptions{
				{
					RpcMethod: "UpdateParams",
					Skip:      true, // skipped because authority gated
				},
				{
					RpcMethod:      "CreateGame",
					Use:            "create-game [min-buy-in] [max-buy-in] [min-players] [max-players] [small-blind] [big-blind] [timeout] [game-type]",
					Short:          "Send a create-game tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "min_buy_in"}, {ProtoField: "max_buy_in"}, {ProtoField: "min_players"}, {ProtoField: "max_players"}, {ProtoField: "small_blind"}, {ProtoField: "big_blind"}, {ProtoField: "timeout"}, {ProtoField: "game_type"}},
				},
				{
					RpcMethod:      "JoinGame",
					Use:            "join-game [game-id] [seat] [buy-in-amount]",
					Short:          "Send a join-game tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}, {ProtoField: "seat"}, {ProtoField: "buy_in_amount"}},
				},
				{
					RpcMethod:      "LeaveGame",
					Use:            "leave-game [game-id]",
					Short:          "Send a leave-game tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}},
				},
				{
					RpcMethod:      "DealCards",
					Use:            "deal-cards [game-id]",
					Short:          "Send a deal-cards tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}},
				},
				{
					RpcMethod:      "PerformAction",
					Use:            "perform-action [game-id] [action] [amount]",
					Short:          "Send a perform-action tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "game_id"}, {ProtoField: "action"}, {ProtoField: "amount"}},
				},
				{
					RpcMethod:      "Mint",
					Use:            "mint [recipient] [amount] [eth-tx-hash] [nonce]",
					Short:          "Send a mint tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "recipient"}, {ProtoField: "amount"}, {ProtoField: "eth_tx_hash"}, {ProtoField: "nonce"}},
				},
				{
					RpcMethod:      "Burn",
					Use:            "burn [amount] [eth-recipient]",
					Short:          "Send a burn tx",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "amount"}, {ProtoField: "eth_recipient"}},
				},
				{
					RpcMethod:      "ProcessDeposit",
					Use:            "process-deposit [deposit-index] [eth-block-height]",
					Short:          "Process an Ethereum bridge deposit by index",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "deposit_index"}, {ProtoField: "eth_block_height"}},
				},
				// this line is used by ignite scaffolding # autocli/tx
			},
		},
	}
}
