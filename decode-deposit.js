#!/usr/bin/env node
/**
 * Decode CosmosBridge deposit transaction
 * Usage: node decode-deposit.js <tx-hash>
 */

const { ethers } = require('ethers');

// Bridge contract ABI for Deposited event
const BRIDGE_ABI = [
    "event Deposited(string indexed account, uint256 amount, uint256 index)"
];

const BRIDGE_ADDRESS = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B";
const BASE_RPC = "https://mainnet.base.org";

async function decodeDeposit(txHash) {
    const provider = new ethers.JsonRpcProvider(BASE_RPC);

    // Get transaction receipt
    const receipt = await provider.getTransactionReceipt(txHash);

    if (!receipt) {
        console.error("Transaction not found");
        process.exit(1);
    }

    // Create interface for decoding
    const iface = new ethers.Interface(BRIDGE_ABI);

    // Find and decode Deposited event
    for (const log of receipt.logs) {
        if (log.address.toLowerCase() === BRIDGE_ADDRESS.toLowerCase()) {
            try {
                const decoded = iface.parseLog(log);

                if (decoded.name === "Deposited") {
                    const account = decoded.args.account;  // Cosmos address
                    const amount = decoded.args.amount.toString();
                    const index = decoded.args.index.toString();

                    console.log("=".repeat(80));
                    console.log("DEPOSIT DECODED");
                    console.log("=".repeat(80));
                    console.log("Transaction Hash:", txHash);
                    console.log("Cosmos Recipient:", account);
                    console.log("Amount (raw):", amount);
                    console.log("Amount (USDC):", (Number(amount) / 1e6).toFixed(6));
                    console.log("Nonce/Index:", index);
                    console.log("=".repeat(80));
                    console.log("\nMint Command:");
                    console.log("=".repeat(80));
                    console.log(`pokerchaind tx poker mint \\`);
                    console.log(`  ${account} \\`);
                    console.log(`  ${amount} \\`);
                    console.log(`  ${txHash} \\`);
                    console.log(`  ${index} \\`);
                    console.log(`  --from <your-key> \\`);
                    console.log(`  --chain-id pokerchain \\`);
                    console.log(`  --fees 1000b52Token`);
                    console.log("=".repeat(80));

                    return;
                }
            } catch (e) {
                // Not the event we're looking for
            }
        }
    }

    console.error("No Deposited event found in transaction");
}

// Main
const txHash = process.argv[2];

if (!txHash) {
    console.error("Usage: node decode-deposit.js <tx-hash>");
    process.exit(1);
}

decodeDeposit(txHash).catch(console.error);
