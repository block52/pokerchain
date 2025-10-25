package simulation

import (
	"math/rand"

	"github.com/cosmos/cosmos-sdk/baseapp"
	"github.com/cosmos/cosmos-sdk/client"
	sdk "github.com/cosmos/cosmos-sdk/types"
	simtypes "github.com/cosmos/cosmos-sdk/types/simulation"

	"github.com/block52/pokerchain/x/poker/keeper"
	"github.com/block52/pokerchain/x/poker/types"
)

func SimulateMsgJoinGame(
	ak types.AuthKeeper,
	bk types.BankKeeper,
	k *keeper.Keeper,
	txGen client.TxConfig,
) simtypes.Operation {
	return func(r *rand.Rand, app *baseapp.BaseApp, ctx sdk.Context, accs []simtypes.Account, chainID string,
	) (simtypes.OperationMsg, []simtypes.FutureOperation, error) {
		simAccount, _ := simtypes.RandomAcc(r, accs)
		msg := &types.MsgJoinGame{
			Player: simAccount.Address.String(),
		}

		// TODO: Handle the JoinGame simulation

		return simtypes.NoOpMsg(types.ModuleName, sdk.MsgTypeURL(msg), "JoinGame simulation not implemented"), nil, nil
	}
}
