package poker

import (
	"math/rand"

	"github.com/cosmos/cosmos-sdk/types/module"
	simtypes "github.com/cosmos/cosmos-sdk/types/simulation"
	"github.com/cosmos/cosmos-sdk/x/simulation"

	pokersimulation "github.com/block52/pokerchain/x/poker/simulation"
	"github.com/block52/pokerchain/x/poker/types"
)

// GenerateGenesisState creates a randomized GenState of the module.
func (AppModule) GenerateGenesisState(simState *module.SimulationState) {
	accs := make([]string, len(simState.Accounts))
	for i, acc := range simState.Accounts {
		accs[i] = acc.Address.String()
	}
	pokerGenesis := types.GenesisState{
		Params: types.DefaultParams(),
	}
	simState.GenState[types.ModuleName] = simState.Cdc.MustMarshalJSON(&pokerGenesis)
}

// RegisterStoreDecoder registers a decoder.
func (am AppModule) RegisterStoreDecoder(_ simtypes.StoreDecoderRegistry) {}

// WeightedOperations returns the all the gov module operations with their respective weights.
func (am AppModule) WeightedOperations(simState module.SimulationState) []simtypes.WeightedOperation {
	operations := make([]simtypes.WeightedOperation, 0)
	const (
		opWeightMsgCreateGame          = "op_weight_msg_poker"
		defaultWeightMsgCreateGame int = 100
	)

	var weightMsgCreateGame int
	simState.AppParams.GetOrGenerate(opWeightMsgCreateGame, &weightMsgCreateGame, nil,
		func(_ *rand.Rand) {
			weightMsgCreateGame = defaultWeightMsgCreateGame
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgCreateGame,
		pokersimulation.SimulateMsgCreateGame(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgJoinGame          = "op_weight_msg_poker"
		defaultWeightMsgJoinGame int = 100
	)

	var weightMsgJoinGame int
	simState.AppParams.GetOrGenerate(opWeightMsgJoinGame, &weightMsgJoinGame, nil,
		func(_ *rand.Rand) {
			weightMsgJoinGame = defaultWeightMsgJoinGame
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgJoinGame,
		pokersimulation.SimulateMsgJoinGame(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgLeaveGame          = "op_weight_msg_poker"
		defaultWeightMsgLeaveGame int = 100
	)

	var weightMsgLeaveGame int
	simState.AppParams.GetOrGenerate(opWeightMsgLeaveGame, &weightMsgLeaveGame, nil,
		func(_ *rand.Rand) {
			weightMsgLeaveGame = defaultWeightMsgLeaveGame
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgLeaveGame,
		pokersimulation.SimulateMsgLeaveGame(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgDealCards          = "op_weight_msg_poker"
		defaultWeightMsgDealCards int = 100
	)

	var weightMsgDealCards int
	simState.AppParams.GetOrGenerate(opWeightMsgDealCards, &weightMsgDealCards, nil,
		func(_ *rand.Rand) {
			weightMsgDealCards = defaultWeightMsgDealCards
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgDealCards,
		pokersimulation.SimulateMsgDealCards(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgPerformAction          = "op_weight_msg_poker"
		defaultWeightMsgPerformAction int = 100
	)

	var weightMsgPerformAction int
	simState.AppParams.GetOrGenerate(opWeightMsgPerformAction, &weightMsgPerformAction, nil,
		func(_ *rand.Rand) {
			weightMsgPerformAction = defaultWeightMsgPerformAction
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgPerformAction,
		pokersimulation.SimulateMsgPerformAction(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgMint          = "op_weight_msg_poker"
		defaultWeightMsgMint int = 100
	)

	var weightMsgMint int
	simState.AppParams.GetOrGenerate(opWeightMsgMint, &weightMsgMint, nil,
		func(_ *rand.Rand) {
			weightMsgMint = defaultWeightMsgMint
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgMint,
		pokersimulation.SimulateMsgMint(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgBurn          = "op_weight_msg_poker"
		defaultWeightMsgBurn int = 100
	)

	var weightMsgBurn int
	simState.AppParams.GetOrGenerate(opWeightMsgBurn, &weightMsgBurn, nil,
		func(_ *rand.Rand) {
			weightMsgBurn = defaultWeightMsgBurn
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgBurn,
		pokersimulation.SimulateMsgBurn(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))

	return operations
}

// ProposalMsgs returns msgs used for governance proposals for simulations.
func (am AppModule) ProposalMsgs(simState module.SimulationState) []simtypes.WeightedProposalMsg {
	return []simtypes.WeightedProposalMsg{}
}
