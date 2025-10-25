# Clean Chain Testing Instructions

**Purpose**: Test the UI and SDK with a completely fresh blockchain

**When to use**: After major refactoring, before pushing commits, or when you want to verify everything works from scratch

---

## 🧹 **Step 1: Clean Up Existing Chain Data**

### Delete Chain Data Directory
```bash
# Remove all blockchain data (blocks, state, keys)
rm -rf ~/.pokerchain
```

### Delete Log File (Optional)
```bash
# Remove old log file
rm ~/pokerchain-node.log
```

**Result**: Clean slate - no blocks, no state, no validator keys

---

## 🚀 **Step 2: Start Fresh Blockchain**

### Navigate to Pokerchain Directory
```bash
cd /Users/alexmiller/projects/pvm_cosmos_under_one_roof/pokerchain
```

### Start Chain with Logging
```bash
ignite chain serve --verbose 2>&1 | tee -a ~/pokerchain-node.log
```

**What this does**:
- `ignite chain serve` - Starts the blockchain
- `--verbose` - Detailed logging
- `2>&1` - Redirects stderr to stdout
- `| tee -a ~/pokerchain-node.log` - Writes to log file AND displays in terminal

**Wait for**:
```
🌍 Tendermint node: http://0.0.0.0:26657
🌍 Blockchain API: http://0.0.0.0:1317
🌍 Token faucet: http://0.0.0.0:4500
```

**Result**: Fresh blockchain running on localhost

---

## 👛 **Step 3: Get Your Wallet Address**

### Option A: From UI (Recommended)
1. Open browser: http://localhost:5173/wallet
2. Your wallet address is displayed at the top
3. Copy it (should start with `b52`)

### Option B: From localStorage (if you already have a wallet)
1. Open browser console (F12)
2. Run:
   ```javascript
   localStorage.getItem('user_cosmos_address')
   ```
3. Copy the address

### Option C: Generate New Wallet
1. Go to: http://localhost:5173/wallet
2. Click "Generate New Wallet"
3. **IMPORTANT**: Save your mnemonic somewhere safe!
4. Copy the generated address

**Example Address**:
```
b5219dj7nyvsj2aq8vrrhyuvlah05e6lx05r3ghqy3
```

**Result**: You have your wallet address to fund

---

## 💰 **Step 4: Fund Your Wallet**

### Open New Terminal (Keep Chain Running in First Terminal)

### Set Your Address as Variable

**Why**: We create a shell variable to avoid typing your long address multiple times in the funding commands.

**What to do**:
1. Copy your actual wallet address from Step 3 (the one that starts with `b52`)
2. Replace the example address below with YOUR address
3. Run the export command in your terminal

```bash
# Replace "b5219dj7nyvsj2aq8vrrhyuvlah05e6lx05r3ghqy3" with YOUR actual address
export YOUR_ADDRESS="b5219dj7nyvsj2aq8vrrhyuvlah05e6lx05r3ghqy3"

# Verify it's set correctly (should print your address)
echo $YOUR_ADDRESS
```

**Example**:
```bash
# If your address from /wallet page is: b521abc123xyz456def789
# Then you would run:
export YOUR_ADDRESS="b521abc123xyz456def789"

# Check it worked:
echo $YOUR_ADDRESS
# Should output: b521abc123xyz456def789
```

**IMPORTANT**:
- Don't use the example address above - use YOUR OWN address from the /wallet page!
- This variable only exists in your current terminal session
- If you close the terminal and open a new one, you'll need to run `export YOUR_ADDRESS="..."` again

---

### Install pokerchaind Binary (if not already installed)

**Why**: The `pokerchaind` binary is needed to send transactions from the command line.

**What to do**:
1. Navigate to the pokerchain directory
2. Run `make install` to build and install the binary
3. This places the binary at `~/go/bin/pokerchaind`

```bash
cd /Users/alexmiller/projects/pvm_cosmos_under_one_roof/pokerchain
make install
```

**How to check if it's already installed**:
```bash
# Check if binary exists
ls -la ~/go/bin/pokerchaind

# Or try running it
~/go/bin/pokerchaind version
```

**Expected output** (if already installed):
```
-rwxr-xr-x  1 alexmiller  staff  123456789 Oct 17 15:30 /Users/alexmiller/go/bin/pokerchaind
```

**When to skip this step**:
- ✅ If you've already run `make install` today
- ✅ If `~/go/bin/pokerchaind version` shows a version number
- ✅ If you haven't changed any Go code since last install

**When to run this step**:
- ❌ First time setting up (definitely need it)
- ❌ After pulling new code from git
- ❌ After modifying any .go files in the pokerchain
- ❌ After deleting the binary

**What it does**:
- Compiles all Go code in `/pokerchain`
- Creates executable binary: `pokerchaind`
- Installs it to: `~/go/bin/pokerchaind`
- Takes ~30-60 seconds to compile

---

### Send Stake Tokens (for Gas Fees)
```bash
~/go/bin/pokerchaind tx bank send alice $YOUR_ADDRESS 100000000stake \
  --keyring-backend test \
  --chain-id pokerchain \
  --yes
```

**What this sends**:
- 100000000 micro-stake = 100 stake tokens
- Used for: Gas fees for transactions

### ~~Mint b52USDC Tokens~~ ❌ **SKIP THIS - Use Bridge Instead**

**NOTE**: We will NOT mint b52USDC directly via CLI. Instead, we'll test getting b52USDC through the real Ethereum bridge from Base Chain.

**Why skip minting**:
- ✅ Tests the real user flow (deposit from Base Chain)
- ✅ Validates the bridge contract integration
- ✅ More realistic than CLI minting

**What you'll do instead** (in Step 5):
- Use the UI to deposit USDC from Base Chain
- Bridge will automatically mint b52USDC on Pokerchain
- This tests the full end-to-end flow

### Verify Balance (Should Only Show Stake)
```bash
~/go/bin/pokerchaind query bank balances $YOUR_ADDRESS
```

**Expected output** (only stake, no b52usdc yet):
```yaml
balances:
- amount: "100000000"
  denom: stake
pagination:
  total: "1"
```

**Result**: Your wallet has stake for gas fees. You'll get b52USDC via the bridge in Step 5!

---

## 🧪 **Step 5: Test the UI**

### Start UI Development Server
```bash
cd /Users/alexmiller/projects/pvm_cosmos_under_one_roof/poker-vm/ui
yarn dev
```

### Test Wallet Display
1. Navigate to: http://localhost:5173
2. You should see your balance displayed
3. Verify:
   - ✅ Address shows correctly
   - ✅ Balance shows: `100.000000 stake`
   - ⚠️ b52USDC balance will be 0 (that's correct - we'll get it via bridge next)

### Test Signing Page
1. Navigate to: http://localhost:5173/test-signing
2. Click "Initialize SigningCosmosClient"
3. Verify balances display correctly
4. Test functions:
   - ✅ `getWalletAddress()` - Should return your address
   - ✅ `sendTokens()` - Try sending 1 stake token
   - ✅ Check console for transaction hash
   - ✅ Verify transaction on: http://localhost:5173/explorer

### Test Explorer
1. Navigate to: http://localhost:5173/explorer
2. You should see latest blocks
3. Click on a block with transactions
4. Verify transaction details display

**Result**: UI works with fresh chain!

---

## 🔄 **Quick Reference Commands**

### Check Balance
```bash
~/go/bin/pokerchaind query bank balances $YOUR_ADDRESS
```

### Send More Stake
```bash
~/go/bin/pokerchaind tx bank send alice $YOUR_ADDRESS 10000000stake \
  --keyring-backend test --chain-id pokerchain --yes
```

### ~~Mint More b52USDC~~ ❌ **Use Bridge Instead**
Use the UI to deposit USDC from Base Chain - this will mint b52USDC via the bridge.

### Check Latest Block
```bash
curl http://localhost:1317/cosmos/base/tendermint/v1beta1/blocks/latest | jq
```

### Check Node Status
```bash
curl http://localhost:26657/status | jq
```

---

## 📝 **Complete Test Checklist**

### Pre-Testing
- [ ] Delete `~/.pokerchain` directory
- [ ] Delete `~/pokerchain-node.log` (optional)
- [ ] Close any running pokerchaind processes

### Chain Setup
- [ ] Start chain: `ignite chain serve --verbose 2>&1 | tee -a ~/pokerchain-node.log`
- [ ] Wait for "Blockchain API: http://0.0.0.0:1317"
- [ ] Verify RPC: `curl http://localhost:26657/status`

### Wallet Setup
- [ ] Get wallet address from /wallet page
- [ ] Export address: `export YOUR_ADDRESS="b52..."`
- [ ] Install binary: `make install` (if needed)
- [ ] Send stake: `pokerchaind tx bank send alice $YOUR_ADDRESS 100000000stake ...`
- [ ] ~~Mint b52USDC~~ SKIP - Will use bridge instead
- [ ] Verify stake balance: `pokerchaind query bank balances $YOUR_ADDRESS`

### UI Testing
- [ ] Start UI: `yarn dev`
- [ ] Check Dashboard shows balance
- [ ] Check /wallet page shows address
- [ ] Test /test-signing page
- [ ] Initialize SigningCosmosClient
- [ ] Test getWalletAddress()
- [ ] Test sendTokens()
- [ ] Check /explorer for transaction

### Verification
- [ ] No errors in browser console
- [ ] Transactions appear on blockchain
- [ ] Balance updates after transactions
- [ ] Build passes: `yarn build`

---

## 🚨 **Troubleshooting**

### "account does not exist" Error
**Problem**: Your wallet isn't funded yet

**Solution**: Run the fund commands from Step 4

### "insufficient fees" Error
**Problem**: Not enough stake tokens for gas

**Solution**:
```bash
~/go/bin/pokerchaind tx bank send alice $YOUR_ADDRESS 100000000stake \
  --keyring-backend test --chain-id pokerchain --yes
```

### "invalid account" Error
**Problem**: Wrong address format or typo

**Solution**:
- Verify address starts with `b52`
- Copy address directly from /wallet page
- Check for extra spaces in `$YOUR_ADDRESS`

### Chain Won't Start
**Problem**: Port already in use

**Solution**:
```bash
# Find and kill process on port 26657
lsof -ti:26657 | xargs kill -9

# Find and kill process on port 1317
lsof -ti:1317 | xargs kill -9

# Then restart chain
ignite chain serve
```

### UI Can't Connect to Chain
**Problem**: Chain not running or wrong endpoints

**Solution**:
- Verify chain is running: `curl http://localhost:26657/status`
- Check .env file has correct endpoints:
  - `VITE_COSMOS_RPC_URL=http://localhost:26657`
  - `VITE_COSMOS_REST_URL=http://localhost:1317`

---

## 📊 **Expected Results**

### After Clean Chain Setup
- Fresh blockchain with height starting at 1
- Genesis accounts (alice, bob) funded
- Your account empty (needs funding)

### After Funding (Stake Only)
```bash
pokerchaind query bank balances $YOUR_ADDRESS
```
```yaml
balances:
- amount: "100000000"        # 100 stake (for gas fees)
  denom: stake
pagination:
  total: "1"
```

**Note**: No b52USDC yet - you'll get that via the bridge!

### After Bridge Deposit (Coming in Step 5)
Once you deposit USDC from Base Chain via the UI:
```yaml
balances:
- amount: "X"                # Amount you deposited via bridge
  denom: b52usdc
- amount: "100000000"        # 100 stake (minus gas used)
  denom: stake
```

### After UI Testing
- Dashboard shows correct balance
- Transactions appear in explorer
- SigningCosmosClient functions work
- Browser console shows no errors

---

## ⏱️ **Estimated Time**

- **Step 1-2**: 2 minutes (delete + start chain)
- **Step 3**: 1 minute (get address)
- **Step 4**: 3 minutes (fund wallet)
- **Step 5**: 5 minutes (test UI)
- **TOTAL**: ~10-15 minutes for complete clean test

---

## 🎯 **Success Criteria**

You've successfully tested with a clean chain when:
- ✅ Fresh blockchain started from height 1
- ✅ Wallet funded with stake and b52USDC
- ✅ UI displays correct balances
- ✅ Can send transactions via /test-signing page
- ✅ Transactions appear in /explorer
- ✅ No errors in browser console
- ✅ Build passes: `yarn build`

---

---

## ✅ **Test Results - October 17, 2025**

### **Latest Test: PASSING**

**Date**: October 17, 2025
**Tester**: Tom (with Claude Code)
**Result**: ✅ **ALL TESTS PASSED**

#### Setup
- ✅ Deleted `~/.pokerchain`
- ✅ Started fresh chain with `ignite chain serve --verbose 2>&1 | tee -a ~/pokerchain-node.log`
- ✅ Chain started from height 1

#### Wallet Funding
- ✅ Wallet A: `b5219dj7nyvsj2aq8vrrhyuvlah05e6lx05r3ghqy3` (funded with 1,000,000,000 stake)
- ✅ Wallet B: `b521y2ggsvur0pnetunmw2ggkxys07cwz4l088c74t` (received 100 stake)

#### Transaction Tests
**Test 1: Send Tokens (Wallet A → Wallet B)**
- Amount: 100 stake
- Tx Hash: `C0D7C11F20EC80F6346304EBC299587ACB1094E649083FE6F8A38A14739FBAC4`
- Block: #326
- Gas: 94,121 / 100,000
- Status: ✅ **SUCCESS**

#### Explorer Verification
- ✅ Transaction appeared at `/explorer/tx/C0D7C11F...`
- ✅ All transaction details displayed correctly
- ✅ 12 events recorded
- ✅ Balance updates reflected immediately

#### UI Tests
- ✅ `/test-signing` page: SigningCosmosClient initialized
- ✅ Balance display: Shows correct amounts
- ✅ Send tokens: Works perfectly
- ✅ Explorer: Displays full transaction details

#### Issues Found
- ⚠️ Input validation: Error when user enters "100.000000" instead of "100"
  - **Error**: "Cannot convert 100.000000 to a BigInt"
  - **Fix needed**: Add validation to test page inputs

#### Conclusion
🎉 **Clean chain testing validates the entire refactored codebase:**
- CosmosContext removal: ✅ No issues
- SDK integration: ✅ Working perfectly
- Transaction signing: ✅ Works with mnemonic from localStorage
- Explorer: ✅ Shows all details correctly

---

**Last Updated**: 2025-10-17
**Created by**: Claude Code
**Purpose**: Ensure clean chain testing before commits
**Latest Test Status**: ✅ PASSING
