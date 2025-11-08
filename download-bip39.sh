#!/bin/bash
# Download BIP39 English wordlist

set -e

WORDLIST_URL="https://raw.githubusercontent.com/bitcoin/bips/master/bip-0039/english.txt"
OUTPUT_FILE="bip39.txt"

echo "Downloading BIP39 English wordlist..."

if command -v curl &> /dev/null; then
    curl -sL "$WORDLIST_URL" -o "$OUTPUT_FILE"
elif command -v wget &> /dev/null; then
    wget -q "$WORDLIST_URL" -O "$OUTPUT_FILE"
else
    echo "Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Verify we got 2048 words
WORD_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

if [ "$WORD_COUNT" != "2048" ]; then
    echo "Error: Expected 2048 words, got $WORD_COUNT"
    rm "$OUTPUT_FILE"
    exit 1
fi

echo "✓ Downloaded BIP39 wordlist: $OUTPUT_FILE (2048 words)"