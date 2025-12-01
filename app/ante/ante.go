package ante

import (
	"bytes"
	"fmt"

	sdkmath "cosmossdk.io/math"
	storetypes "cosmossdk.io/store/types"
	circuitante "cosmossdk.io/x/circuit/ante"
	circuitkeeper "cosmossdk.io/x/circuit/keeper"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/cosmos/cosmos-sdk/x/auth/ante"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"

	pokertypes "github.com/block52/pokerchain/x/poker/types"
)

// HandlerOptions are the options required for constructing a SDK AnteHandler with poker gasless support.
type HandlerOptions struct {
	ante.HandlerOptions
	CircuitKeeper *circuitkeeper.Keeper
}

// NewAnteHandler returns an AnteHandler that checks and increments sequence
// numbers, checks signatures & account numbers, and deducts fees from the first
// signer. Poker game messages (PerformAction, JoinGame, LeaveGame, DealCards)
// are processed with infinite gas meter, making them effectively gasless.
func NewAnteHandler(options HandlerOptions) (sdk.AnteHandler, error) {
	if options.AccountKeeper == nil {
		return nil, fmt.Errorf("account keeper is required")
	}
	if options.BankKeeper == nil {
		return nil, fmt.Errorf("bank keeper is required")
	}
	if options.SignModeHandler == nil {
		return nil, fmt.Errorf("sign mode handler is required")
	}

	anteDecorators := []sdk.AnteDecorator{
		ante.NewSetUpContextDecorator(), // outermost AnteDecorator. SetUpContext must be called first
		circuitante.NewCircuitBreakerDecorator(options.CircuitKeeper),
		ante.NewExtensionOptionsDecorator(options.ExtensionOptionChecker),
		ante.NewValidateBasicDecorator(),
		ante.NewTxTimeoutHeightDecorator(),
		ante.NewValidateMemoDecorator(options.AccountKeeper),
		ante.NewConsumeGasForTxSizeDecorator(options.AccountKeeper),
		// Custom decorator that makes poker transactions gasless
		NewPokerGaslessDecorator(options.AccountKeeper, options.BankKeeper, options.FeegrantKeeper, options.TxFeeChecker),
		ante.NewSetPubKeyDecorator(options.AccountKeeper), // SetPubKeyDecorator must be called before all signature verification decorators
		ante.NewValidateSigCountDecorator(options.AccountKeeper),
		ante.NewSigGasConsumeDecorator(options.AccountKeeper, options.SigGasConsumer),
		ante.NewSigVerificationDecorator(options.AccountKeeper, options.SignModeHandler),
		ante.NewIncrementSequenceDecorator(options.AccountKeeper),
	}

	return sdk.ChainAnteDecorators(anteDecorators...), nil
}

// isPokerGaslessMessage returns true if the message should be processed gaslessly
func isPokerGaslessMessage(msg sdk.Msg) bool {
	switch msg.(type) {
	case *pokertypes.MsgPerformAction,
		*pokertypes.MsgJoinGame,
		*pokertypes.MsgLeaveGame,
		*pokertypes.MsgDealCards,
		*pokertypes.MsgCreateGame:
		return true
	default:
		return false
	}
}

// containsOnlyPokerGaslessMessages returns true if all messages in the tx are gasless poker messages
func containsOnlyPokerGaslessMessages(msgs []sdk.Msg) bool {
	if len(msgs) == 0 {
		return false
	}
	for _, msg := range msgs {
		if !isPokerGaslessMessage(msg) {
			return false
		}
	}
	return true
}

// PokerGaslessDecorator handles fee deduction but skips it entirely for poker game transactions,
// and sets an infinite gas meter for them.
type PokerGaslessDecorator struct {
	accountKeeper  ante.AccountKeeper
	bankKeeper     authtypes.BankKeeper
	feegrantKeeper ante.FeegrantKeeper
	txFeeChecker   ante.TxFeeChecker
}

// NewPokerGaslessDecorator creates a new PokerGaslessDecorator
func NewPokerGaslessDecorator(ak ante.AccountKeeper, bk authtypes.BankKeeper, fk ante.FeegrantKeeper, tfc ante.TxFeeChecker) PokerGaslessDecorator {
	if tfc == nil {
		tfc = checkTxFeeWithValidatorMinGasPrices
	}
	return PokerGaslessDecorator{
		accountKeeper:  ak,
		bankKeeper:     bk,
		feegrantKeeper: fk,
		txFeeChecker:   tfc,
	}
}

func (pgd PokerGaslessDecorator) AnteHandle(ctx sdk.Context, tx sdk.Tx, simulate bool, next sdk.AnteHandler) (sdk.Context, error) {
	feeTx, ok := tx.(sdk.FeeTx)
	if !ok {
		return ctx, fmt.Errorf("tx must implement FeeTx interface")
	}

	// Check if this transaction contains only poker game messages
	if containsOnlyPokerGaslessMessages(tx.GetMsgs()) {
		// For poker transactions: skip fee deduction and use infinite gas meter
		feePayer := feeTx.FeePayer()
		feePayerAcc := pgd.accountKeeper.GetAccount(ctx, feePayer)
		if feePayerAcc == nil {
			return ctx, fmt.Errorf("fee payer address %s does not exist", sdk.AccAddress(feePayer))
		}

		// Set infinite gas meter - no gas limit for poker transactions
		newCtx := ctx.WithGasMeter(storetypes.NewInfiniteGasMeter())

		return next(newCtx, tx, simulate)
	}

	// For non-poker transactions: use standard fee deduction logic
	if !simulate && ctx.BlockHeight() > 0 && feeTx.GetGas() == 0 {
		return ctx, fmt.Errorf("must provide positive gas")
	}

	var (
		priority int64
		err      error
	)

	fee := feeTx.GetFee()
	if !simulate {
		fee, priority, err = pgd.txFeeChecker(ctx, tx)
		if err != nil {
			return ctx, err
		}
	}

	if err := pgd.checkDeductFee(ctx, tx, fee); err != nil {
		return ctx, err
	}

	newCtx := ctx.WithPriority(priority)
	return next(newCtx, tx, simulate)
}

func (pgd PokerGaslessDecorator) checkDeductFee(ctx sdk.Context, sdkTx sdk.Tx, fee sdk.Coins) error {
	feeTx, ok := sdkTx.(sdk.FeeTx)
	if !ok {
		return fmt.Errorf("tx must implement FeeTx interface")
	}

	if addr := pgd.accountKeeper.GetModuleAddress(authtypes.FeeCollectorName); addr == nil {
		return fmt.Errorf("fee collector module account (%s) has not been set", authtypes.FeeCollectorName)
	}

	feePayer := feeTx.FeePayer()
	feeGranter := feeTx.FeeGranter()
	deductFeesFrom := feePayer

	// if feegranter set deduct fee from feegranter account
	if feeGranter != nil {
		if pgd.feegrantKeeper == nil {
			return fmt.Errorf("fee grants are not enabled")
		}

		if !bytes.Equal(feeGranter, feePayer) {
			err := pgd.feegrantKeeper.UseGrantedFees(ctx, feeGranter, feePayer, fee, sdkTx.GetMsgs())
			if err != nil {
				return fmt.Errorf("%s does not allow to pay fees for %s: %w", sdk.AccAddress(feeGranter), sdk.AccAddress(feePayer), err)
			}
		}
		deductFeesFrom = feeGranter
	}

	deductFeesFromAcc := pgd.accountKeeper.GetAccount(ctx, deductFeesFrom)
	if deductFeesFromAcc == nil {
		return fmt.Errorf("fee payer address %s does not exist", sdk.AccAddress(deductFeesFrom))
	}

	// deduct the fees
	if !fee.IsZero() {
		err := ante.DeductFees(pgd.bankKeeper, ctx, deductFeesFromAcc, fee)
		if err != nil {
			return err
		}
	}

	events := sdk.Events{
		sdk.NewEvent(
			sdk.EventTypeTx,
			sdk.NewAttribute(sdk.AttributeKeyFee, fee.String()),
			sdk.NewAttribute(sdk.AttributeKeyFeePayer, sdk.AccAddress(deductFeesFrom).String()),
		),
	}
	ctx.EventManager().EmitEvents(events)

	return nil
}

// checkTxFeeWithValidatorMinGasPrices implements the default fee logic
func checkTxFeeWithValidatorMinGasPrices(ctx sdk.Context, tx sdk.Tx) (sdk.Coins, int64, error) {
	feeTx, ok := tx.(sdk.FeeTx)
	if !ok {
		return nil, 0, fmt.Errorf("tx must implement FeeTx interface")
	}

	feeCoins := feeTx.GetFee()
	gas := feeTx.GetGas()

	// Ensure that the provided fees meet a minimum threshold for the validator
	if ctx.IsCheckTx() {
		minGasPrices := ctx.MinGasPrices()
		if !minGasPrices.IsZero() {
			requiredFees := make(sdk.Coins, len(minGasPrices))
			glDec := sdkmath.LegacyNewDec(int64(gas))
			for i, gp := range minGasPrices {
				fee := gp.Amount.Mul(glDec)
				requiredFees[i] = sdk.NewCoin(gp.Denom, fee.Ceil().RoundInt())
			}
			if !feeCoins.IsAnyGTE(requiredFees) {
				return nil, 0, fmt.Errorf("insufficient fees; got: %s required: %s", feeCoins, requiredFees)
			}
		}
	}

	priority := getTxPriority(feeCoins, int64(gas))
	return feeCoins, priority, nil
}

// getTxPriority returns a naive tx priority based on the amount of gas price
func getTxPriority(fee sdk.Coins, gas int64) int64 {
	var priority int64
	for _, c := range fee {
		p := int64(c.Amount.Uint64()) / gas
		if p > priority {
			priority = p
		}
	}
	return priority
}
