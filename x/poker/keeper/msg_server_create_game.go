package keeper

import (
	"context"
	"encoding/hex"
	"fmt"
	"strconv"

	errorsmod "cosmossdk.io/errors"
	"cosmossdk.io/math"
	"github.com/block52/pokerchain/x/poker/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	"golang.org/x/crypto/sha3"
)

func (k msgServer) CreateGame(ctx context.Context, msg *types.MsgCreateGame) (*types.MsgCreateGameResponse, error) {
	// Validate creator address
	creatorAddr, err := k.addressCodec.StringToBytes(msg.Creator)
	if err != nil {
		return nil, errorsmod.Wrap(err, "invalid creator address")
	}

	// Check if creator has enough tokens
	creatorBalance := k.bankKeeper.SpendableCoins(ctx, creatorAddr)
	tokenCoin := sdk.NewCoin(types.TokenDenom, math.NewInt(types.GameCreationCost))

	if !creatorBalance.IsAllGTE(sdk.NewCoins(tokenCoin)) {
		return nil, errorsmod.Wrapf(sdkerrors.ErrInsufficientFunds,
			"creator needs %s to create a game, but only has %s",
			tokenCoin.String(),
			creatorBalance.AmountOf(types.TokenDenom).String())
	}

	// Deduct tokens from creator account and send to module account
	if err := k.bankKeeper.SendCoinsFromAccountToModule(
		ctx,
		creatorAddr,
		types.ModuleName,
		sdk.NewCoins(tokenCoin),
	); err != nil {
		return nil, errorsmod.Wrap(err, "failed to deduct game creation cost")
	}

	// Generate unique game ID using keccak256 hash of timestamp + creator address
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	timestamp := strconv.FormatInt(sdkCtx.BlockTime().Unix(), 10)
	hashData := timestamp + msg.Creator

	// Use keccak256 (Ethereum-style hash)
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(hashData))
	hashBytes := hash.Sum(nil)
	gameId := "0x" + hex.EncodeToString(hashBytes)

	// Check if game with this ID already exists
	_, err = k.Games.Get(ctx, gameId)
	if err == nil {
		return nil, errorsmod.Wrapf(types.ErrInvalidRequest, "game with ID %s already exists", gameId)
	}

	// Create game state
	// Use block time for deterministic timestamps across all validators
	now := sdkCtx.BlockTime()
	game := types.Game{
		GameId:     gameId,
		Creator:    msg.Creator,
		MinBuyIn:   msg.MinBuyIn,
		MaxBuyIn:   msg.MaxBuyIn,
		MinPlayers: msg.MinPlayers,
		MaxPlayers: msg.MaxPlayers,
		SmallBlind: msg.SmallBlind,
		BigBlind:   msg.BigBlind,
		Timeout:    msg.Timeout,
		GameType:   msg.GameType,
		Players:    []string{}, // Empty initially, players join separately
		CreatedAt:  now,
		UpdatedAt:  now,
	}

	// Store game in keeper
	if err := k.Games.Set(ctx, gameId, game); err != nil {
		return nil, errorsmod.Wrap(err, "failed to store game")
	}

	// Create and store default game state for frontend compatibility
	minBuyInStr := fmt.Sprintf("%d", msg.MinBuyIn)
	maxBuyInStr := fmt.Sprintf("%d", msg.MaxBuyIn)
	smallBlindStr := fmt.Sprintf("%d", msg.SmallBlind)
	bigBlindStr := fmt.Sprintf("%d", msg.BigBlind)
	minPlayersInt := int(msg.MinPlayers)
	maxPlayersInt := int(msg.MaxPlayers)

	// Convert string game type to GameType enum
	var gameType types.GameType
	switch msg.GameType {
	case "cash":
		gameType = types.GameTypeCash
	case "sit-and-go":
		gameType = types.GameTypeSitAndGo
	case "tournament":
		gameType = types.GameTypeTournament
	default:
		gameType = types.GameTypeCash // default to cash if unrecognized
	}

	// Initialize and shuffle deck for the new game
	deck, err := k.InitializeAndShuffleDeck(ctx)
	if err != nil {
		return nil, errorsmod.Wrap(err, "failed to initialize deck")
	}

	defaultGameState := types.TexasHoldemStateDTO{
		Type:        types.GameTypeTexasHoldem,
		Address:     gameId,
		HandNumber:  1,
		Round:       types.RoundAnte,
		ActionCount: 0,
		GameOptions: types.GameOptionsDTO{
			MinBuyIn:   &minBuyInStr,
			MaxBuyIn:   &maxBuyInStr,
			SmallBlind: &smallBlindStr,
			BigBlind:   &bigBlindStr,
			MinPlayers: &minPlayersInt,
			MaxPlayers: &maxPlayersInt,
			Type:       &gameType,
		},
		Players:         []types.PlayerDTO{},
		CommunityCards:  []string{},
		Deck:            deck.ToString(), // Shuffled deck serialized to string
		Pots:            []string{},
		NextToAct:       0,
		PreviousActions: []types.ActionDTO{},
		Winners:         []types.WinnerDTO{},
		Results:         []types.ResultDTO{},
		Signature:       "",
	}

	if err := k.GameStates.Set(ctx, gameId, defaultGameState); err != nil {
		return nil, errorsmod.Wrap(err, "failed to store game state")
	}

	// Emit events
	sdkCtx.EventManager().EmitEvents(sdk.Events{
		sdk.NewEvent(
			"game_created",
			sdk.NewAttribute("game_id", gameId),
			sdk.NewAttribute("creator", msg.Creator),
			sdk.NewAttribute("game_type", msg.GameType),
			sdk.NewAttribute("min_players", fmt.Sprintf("%d", msg.MinPlayers)),
			sdk.NewAttribute("max_players", fmt.Sprintf("%d", msg.MaxPlayers)),
			sdk.NewAttribute("min_buy_in", fmt.Sprintf("%d", msg.MinBuyIn)),
			sdk.NewAttribute("max_buy_in", fmt.Sprintf("%d", msg.MaxBuyIn)),
		),
	})

	return &types.MsgCreateGameResponse{}, nil
}
