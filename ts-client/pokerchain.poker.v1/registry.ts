import { GeneratedType } from "@cosmjs/proto-signing";
import { MsgUpdateParams } from "./types/pokerchain/poker/v1/tx";
import { MsgCreateGame } from "./types/pokerchain/poker/v1/tx";
import { MsgJoinGame } from "./types/pokerchain/poker/v1/tx";
import { MsgLeaveGame } from "./types/pokerchain/poker/v1/tx";
import { MsgDealCards } from "./types/pokerchain/poker/v1/tx";
import { MsgPerformAction } from "./types/pokerchain/poker/v1/tx";
import { MsgMint } from "./types/pokerchain/poker/v1/tx";
import { MsgBurn } from "./types/pokerchain/poker/v1/tx";
import { MsgProcessDeposit } from "./types/pokerchain/poker/v1/tx";
import { MsgInitiateWithdrawal } from "./types/pokerchain/poker/v1/tx";
import { MsgSignWithdrawal } from "./types/pokerchain/poker/v1/tx";

const msgTypes: Array<[string, GeneratedType]>  = [
    ["/pokerchain.poker.v1.MsgUpdateParams", MsgUpdateParams],
    ["/pokerchain.poker.v1.MsgCreateGame", MsgCreateGame],
    ["/pokerchain.poker.v1.MsgJoinGame", MsgJoinGame],
    ["/pokerchain.poker.v1.MsgLeaveGame", MsgLeaveGame],
    ["/pokerchain.poker.v1.MsgDealCards", MsgDealCards],
    ["/pokerchain.poker.v1.MsgPerformAction", MsgPerformAction],
    ["/pokerchain.poker.v1.MsgMint", MsgMint],
    ["/pokerchain.poker.v1.MsgBurn", MsgBurn],
    ["/pokerchain.poker.v1.MsgProcessDeposit", MsgProcessDeposit],
    ["/pokerchain.poker.v1.MsgInitiateWithdrawal", MsgInitiateWithdrawal],
    ["/pokerchain.poker.v1.MsgSignWithdrawal", MsgSignWithdrawal],
    
];

export { msgTypes }