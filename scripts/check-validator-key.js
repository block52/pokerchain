const ethers = require('ethers');

// The private key from app.toml
const privateKey = '0xbd78d63f1c1441e73e8b3e33263a0357b2673daf43eb52a75431da6ca413aae8';

// Create wallet from private key
const wallet = new ethers.Wallet(privateKey);

console.log('');
console.log('🔑 Validator Key Check');
console.log('━'.repeat(80));
console.log('Private Key:', privateKey);
console.log('Derived Address:', wallet.address);
console.log('');
console.log('📋 Next Steps:');
console.log('1. Check if this address is registered as a validator in the Vault contract');
console.log('2. Vault contract address: 0x893c26846d7cE76445230B2b6285a663BF4C3BF5');
console.log('3. You can check on Base Etherscan:');
console.log('   https://basescan.org/address/0x893c26846d7cE76445230B2b6285a663BF4C3BF5#readContract');
console.log('');
console.log('4. Or use this command to check if the address is a validator:');
console.log('   cast call 0x893c26846d7cE76445230B2b6285a663BF4C3BF5 "isValidator(address)" ' + wallet.address + ' --rpc-url https://mainnet.base.org');
console.log('');
console.log('━'.repeat(80));
