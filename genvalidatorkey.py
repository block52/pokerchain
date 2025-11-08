#!/usr/bin/env python3
"""
Generate Tendermint/CometBFT validator keys from BIP39 mnemonic phrases.

Usage:
    python genvalidatorkey.py generate [output_file]
    python genvalidatorkey.py "mnemonic phrase" [output_file]
    
Examples:
    # Generate new mnemonic and key
    python genvalidatorkey.py generate
    
    # Use existing mnemonic
    python genvalidatorkey.py "word1 word2 ... word24" priv_validator_key.json
"""

import sys
import json
import hashlib
import hmac
import os
import secrets
import base64
from pathlib import Path

# Try to import nacl for ed25519
try:
    import nacl.signing
    import nacl.encoding
    HAS_NACL = True
except ImportError:
    HAS_NACL = False
    print("Warning: PyNaCl not found. Install with: pip install PyNaCl", file=sys.stderr)
    print("Attempting to use cryptography library as fallback...", file=sys.stderr)

# Fallback to cryptography library
if not HAS_NACL:
    try:
        from cryptography.hazmat.primitives.asymmetric import ed25519
        from cryptography.hazmat.primitives import serialization
        HAS_CRYPTOGRAPHY = True
    except ImportError:
        HAS_CRYPTOGRAPHY = False
        print("Error: Neither PyNaCl nor cryptography library found!", file=sys.stderr)
        print("Install with: pip install PyNaCl", file=sys.stderr)
        sys.exit(1)
else:
    HAS_CRYPTOGRAPHY = False


class BIP39:
    """BIP39 mnemonic generation and validation."""
    
    def __init__(self, wordlist_path="bip39.txt"):
        """Load BIP39 wordlist from file."""
        self.wordlist = self._load_wordlist(wordlist_path)
        self.wordlist_dict = {word: idx for idx, word in enumerate(self.wordlist)}
    
    def _load_wordlist(self, path):
        """Load wordlist from file."""
        wordlist_path = Path(path)
        if not wordlist_path.exists():
            # Try current directory and script directory
            script_dir = Path(__file__).parent
            for check_path in [Path(path), script_dir / path, script_dir / "bip39.txt"]:
                if check_path.exists():
                    wordlist_path = check_path
                    break
            else:
                raise FileNotFoundError(
                    f"BIP39 wordlist not found at {path}\n"
                    f"Please download from: https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt\n"
                    f"Or create bip39.txt with 2048 words (one per line)"
                )
        
        with open(wordlist_path, 'r', encoding='utf-8') as f:
            wordlist = [line.strip() for line in f if line.strip()]
        
        if len(wordlist) != 2048:
            raise ValueError(f"Invalid wordlist: expected 2048 words, got {len(wordlist)}")
        
        return wordlist
    
    def generate_mnemonic(self, strength=256):
        """
        Generate a new mnemonic phrase.
        
        Args:
            strength: Bits of entropy (128, 160, 192, 224, or 256)
                     128 = 12 words, 256 = 24 words
        
        Returns:
            Mnemonic phrase as string
        """
        if strength not in [128, 160, 192, 224, 256]:
            raise ValueError("Strength must be 128, 160, 192, 224, or 256")
        
        # Generate random entropy
        entropy_bytes = secrets.token_bytes(strength // 8)
        
        # Convert entropy to mnemonic
        return self._entropy_to_mnemonic(entropy_bytes)
    
    def _entropy_to_mnemonic(self, entropy):
        """Convert entropy bytes to mnemonic phrase."""
        if len(entropy) not in [16, 20, 24, 28, 32]:
            raise ValueError("Entropy length must be 16, 20, 24, 28, or 32 bytes")
        
        # Calculate checksum
        checksum_length = len(entropy) // 4
        checksum = hashlib.sha256(entropy).digest()
        
        # Combine entropy and checksum
        bits = bin(int.from_bytes(entropy, 'big'))[2:].zfill(len(entropy) * 8)
        checksum_bits = bin(int.from_bytes(checksum, 'big'))[2:].zfill(256)[:checksum_length]
        bits += checksum_bits
        
        # Convert to words
        words = []
        for i in range(0, len(bits), 11):
            idx = int(bits[i:i+11], 2)
            words.append(self.wordlist[idx])
        
        return ' '.join(words)
    
    def validate_mnemonic(self, mnemonic):
        """
        Validate a mnemonic phrase.
        
        Returns:
            True if valid, False otherwise
        """
        words = mnemonic.strip().split()
        
        if len(words) not in [12, 15, 18, 21, 24]:
            return False
        
        # Check all words are in wordlist
        try:
            indices = [self.wordlist_dict[word] for word in words]
        except KeyError:
            return False
        
        # Convert to bits
        bits = ''.join(bin(idx)[2:].zfill(11) for idx in indices)
        
        # Split entropy and checksum
        checksum_length = len(words) // 3
        entropy_bits = bits[:-checksum_length]
        checksum_bits = bits[-checksum_length:]
        
        # Convert entropy bits to bytes
        entropy = int(entropy_bits, 2).to_bytes(len(entropy_bits) // 8, 'big')
        
        # Verify checksum
        expected_checksum = bin(int.from_bytes(hashlib.sha256(entropy).digest(), 'big'))[2:].zfill(256)
        expected_checksum = expected_checksum[:checksum_length]
        
        return checksum_bits == expected_checksum
    
    def mnemonic_to_seed(self, mnemonic, passphrase=""):
        """
        Convert mnemonic to seed using PBKDF2.
        
        Args:
            mnemonic: Mnemonic phrase
            passphrase: Optional passphrase
        
        Returns:
            64-byte seed
        """
        mnemonic_bytes = mnemonic.encode('utf-8')
        salt = ('mnemonic' + passphrase).encode('utf-8')
        
        # PBKDF2-HMAC-SHA512 with 2048 rounds
        seed = hashlib.pbkdf2_hmac('sha512', mnemonic_bytes, salt, 2048)
        
        return seed


class ValidatorKey:
    """Generate Tendermint/CometBFT validator keys."""
    
    @staticmethod
    def generate_from_seed(seed):
        """
        Generate ed25519 key pair from seed.
        
        Args:
            seed: 64-byte seed from BIP39
        
        Returns:
            dict with 'private_key' and 'public_key' (bytes)
        """
        # Use first 32 bytes of seed after hashing for key generation
        # This matches the Go implementation
        key_material = hashlib.sha256(seed).digest()
        
        if HAS_NACL:
            # Use PyNaCl
            signing_key = nacl.signing.SigningKey(key_material)
            private_key = bytes(signing_key)  # 32 bytes
            public_key = bytes(signing_key.verify_key)  # 32 bytes
            
            # For Tendermint, we need the 64-byte private key format
            # which is [32-byte seed][32-byte public key]
            private_key_full = private_key + public_key
        else:
            # Use cryptography library
            private_key_obj = ed25519.Ed25519PrivateKey.from_private_bytes(key_material)
            public_key = private_key_obj.public_key().public_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PublicFormat.Raw
            )
            
            # For Tendermint, we need the 64-byte private key format
            private_key_full = key_material + public_key
        
        return {
            'private_key': private_key_full,  # 64 bytes
            'public_key': public_key  # 32 bytes
        }
    
    @staticmethod
    def generate_address(public_key):
        """
        Generate Tendermint address from public key.
        
        Args:
            public_key: 32-byte ed25519 public key
        
        Returns:
            Hex-encoded address (uppercase)
        """
        # Tendermint address is first 20 bytes of SHA256(public_key)
        hash_result = hashlib.sha256(public_key).digest()
        address = hash_result[:20]
        return address.hex().upper()
    
    @staticmethod
    def create_priv_validator_key(private_key, public_key):
        """
        Create priv_validator_key.json structure.
        
        Args:
            private_key: 64-byte private key
            public_key: 32-byte public key
        
        Returns:
            dict ready for JSON serialization
        """
        address = ValidatorKey.generate_address(public_key)
        
        return {
            "address": address,
            "pub_key": {
                "type": "tendermint/PubKeyEd25519",
                "value": base64.b64encode(public_key).decode('ascii')
            },
            "priv_key": {
                "type": "tendermint/PrivKeyEd25519",
                "value": base64.b64encode(private_key).decode('ascii')
            }
        }


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: genvalidatorkey.py <mnemonic|generate> [output_file]")
        print()
        print("Examples:")
        print("  # Generate new mnemonic and key")
        print("  python genvalidatorkey.py generate")
        print()
        print("  # Use existing mnemonic")
        print('  python genvalidatorkey.py "word1 word2 ... word24" priv_validator_key.json')
        sys.exit(1)
    
    # Load BIP39 wordlist
    try:
        bip39 = BIP39()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Determine output file
    output_file = "priv_validator_key.json"
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    
    # Generate or use provided mnemonic
    if sys.argv[1].lower() == "generate":
        print("Generated mnemonic (SAVE THIS SECURELY):")
        mnemonic = bip39.generate_mnemonic(strength=256)  # 24 words
        print(mnemonic)
        print()
    else:
        mnemonic = sys.argv[1]
        
        # Validate mnemonic
        if not bip39.validate_mnemonic(mnemonic):
            print("Error: Invalid mnemonic phrase", file=sys.stderr)
            sys.exit(1)
    
    # Generate seed from mnemonic
    seed = bip39.mnemonic_to_seed(mnemonic)
    
    # Generate validator key
    keys = ValidatorKey.generate_from_seed(seed)
    
    # Create priv_validator_key structure
    validator_key = ValidatorKey.create_priv_validator_key(
        keys['private_key'],
        keys['public_key']
    )
    
    # Write to file
    with open(output_file, 'w') as f:
        json.dump(validator_key, f, indent=2)
    
    print(f"✓ Created validator key file: {output_file}")
    print(f"  Address: {validator_key['address']}")
    print(f"  PubKey:  {validator_key['pub_key']['value']}")
    print()
    print("⚠️  IMPORTANT: Keep your mnemonic phrase secure!")
    print("   It can be used to recover this validator key.")


if __name__ == "__main__":
    main()