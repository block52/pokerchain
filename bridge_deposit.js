#!/usr/bin/env node

const { ethers } = require('ethers');
require('dotenv').config();

// Base Chain Configuration (from app.toml)
const BASE_RPC_URL = "https://base.llamarpc.com";
const BRIDGE_CONTRACT_ADDRESS = "0xcc391c8f1aFd6DB5D8b0e064BA81b1383b14FE5B";
const USDC_CONTRACT_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

// USDC has 6 decimals on Base
const USDC_DECIMALS = 6;

// Basic ERC20 ABI for USDC
const ERC20_ABI = [
    "function balanceOf(address owner) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",
];

// Bridge Contract ABI (based on the bridge documentation)
const BRIDGE_ABI = [
    "function depositForBridge(string memory cosmosRecipient, uint256 amount) external",
    "event DepositForBridge(address indexed from, string cosmosRecipient, uint256 amount, uint256 nonce)"
];

async function main() {
    const args = process.argv.slice(2);

    if (args.length < 3) {
        console.log("🌉 Base USDC Bridge Deposit Tool");
        console.log("================================");
        console.log("");
        console.log("Usage: node bridge_deposit.js <private_key> <cosmos_recipient> <amount_usdc>");
        console.log("");
        console.log("Arguments:");
        console.log("  private_key      - Your Base wallet private key (without 0x prefix)");
        console.log("  cosmos_recipient - Cosmos address to receive USDC (e.g., b521ls95ghxgwhp25kcpnu7pdxf09l448tssgxs3js)");
        console.log("  amount_usdc      - Amount of USDC to bridge (e.g., 10 for 10 USDC)");
        console.log("");
        console.log("Example:");
        console.log("  node bridge_deposit.js abc123... b521ls95ghxgwhp25kcpnu7pdxf09l448tssgxs3js 10");
        console.log("");
        console.log("💡 Tip: Make sure you have USDC and ETH for gas fees on Base Chain");
        console.log("");
        console.log("Contract Addresses:");
        console.log(`  Bridge: ${BRIDGE_CONTRACT_ADDRESS}`);
        console.log(`  USDC:   ${USDC_CONTRACT_ADDRESS}`);
        process.exit(1);
    }

    const [privateKey, cosmosRecipient, amountStr] = args;
    const amount = parseFloat(amountStr);

    if (isNaN(amount) || amount <= 0) {
        console.error("❌ Invalid amount. Please provide a positive number.");
        process.exit(1);
    }

    console.log("🌉 Starting Base USDC Bridge Deposit");
    console.log("===================================");
    console.log(`💰 Amount: ${amount} USDC`);
    console.log(`🎯 Recipient: ${cosmosRecipient}`);
    console.log(`🌐 Network: Base Chain`);
    console.log("");

    try {
        // Setup provider and wallet
        const provider = new ethers.JsonRpcProvider(BASE_RPC_URL);
        const wallet = new ethers.Wallet(privateKey.startsWith('0x') ? privateKey : '0x' + privateKey, provider);

        console.log(`👤 From Address: ${wallet.address}`);

        // Get network info
        const network = await provider.getNetwork();
        console.log(`🔗 Chain ID: ${network.chainId}`);

        // Setup contracts
        const usdcContract = new ethers.Contract(USDC_CONTRACT_ADDRESS, ERC20_ABI, wallet);
        const bridgeContract = new ethers.Contract(BRIDGE_CONTRACT_ADDRESS, BRIDGE_ABI, wallet);

        // Convert amount to USDC units (6 decimals)
        const amountInWei = ethers.parseUnits(amount.toString(), USDC_DECIMALS);
        console.log(`🔢 Amount in USDC units: ${amountInWei.toString()}`);

        // Check USDC balance
        console.log("💳 Checking USDC balance...");
        const balance = await usdcContract.balanceOf(wallet.address);
        const balanceFormatted = ethers.formatUnits(balance, USDC_DECIMALS);
        console.log(`   Balance: ${balanceFormatted} USDC`);

        if (balance < amountInWei) {
            console.error(`❌ Insufficient USDC balance. You have ${balanceFormatted} USDC but trying to bridge ${amount} USDC`);
            process.exit(1);
        }

        // Check ETH balance for gas
        const ethBalance = await provider.getBalance(wallet.address);
        const ethFormatted = ethers.formatEther(ethBalance);
        console.log(`⛽ ETH Balance: ${ethFormatted} ETH`);

        if (ethBalance < ethers.parseEther("0.001")) {
            console.warn("⚠️  Low ETH balance for gas fees. You might need more ETH.");
        }

        // Check current allowance
        console.log("🔐 Checking USDC allowance...");
        const allowance = await usdcContract.allowance(wallet.address, BRIDGE_CONTRACT_ADDRESS);
        const allowanceFormatted = ethers.formatUnits(allowance, USDC_DECIMALS);
        console.log(`   Current allowance: ${allowanceFormatted} USDC`);

        // Approve USDC if needed
        if (allowance < amountInWei) {
            console.log("📝 Approving USDC spend...");
            const approveTx = await usdcContract.approve(BRIDGE_CONTRACT_ADDRESS, amountInWei);
            console.log(`   Approval TX: ${approveTx.hash}`);
            console.log("   Waiting for confirmation...");
            await approveTx.wait();
            console.log("✅ USDC approved!");
        } else {
            console.log("✅ USDC already approved!");
        }

        // Deposit to bridge
        console.log("🌉 Depositing to bridge...");
        const depositTx = await bridgeContract.depositForBridge(cosmosRecipient, amountInWei);
        console.log(`🚀 Deposit TX: ${depositTx.hash}`);
        console.log("   Waiting for confirmation...");

        const receipt = await depositTx.wait();
        console.log("✅ Deposit confirmed!");
        console.log(`   Block: ${receipt.blockNumber}`);
        console.log(`   Gas used: ${receipt.gasUsed.toString()}`);

        // Parse events
        const depositEvent = receipt.logs.find(log => {
            try {
                const parsed = bridgeContract.interface.parseLog(log);
                return parsed && parsed.name === 'DepositForBridge';
            } catch {
                return false;
            }
        });

        if (depositEvent) {
            const parsed = bridgeContract.interface.parseLog(depositEvent);
            console.log("");
            console.log("🎉 Bridge Deposit Event:");
            console.log(`   From: ${parsed.args.from}`);
            console.log(`   Cosmos Recipient: ${parsed.args.cosmosRecipient}`);
            console.log(`   Amount: ${ethers.formatUnits(parsed.args.amount, USDC_DECIMALS)} USDC`);
            console.log(`   Nonce: ${parsed.args.nonce.toString()}`);
        }

        console.log("");
        console.log("🎯 Next Steps:");
        console.log("1. The bridge will monitor this transaction");
        console.log("2. USDC will be minted on Pokerchain automatically");
        console.log(`3. Check recipient balance: pokerchaind query bank balances ${cosmosRecipient}`);
        console.log("");
        console.log("🔗 Transaction Details:");
        console.log(`   Base TX: https://basescan.org/tx/${depositTx.hash}`);

    } catch (error) {
        console.error("❌ Error:", error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main().catch(console.error);
}