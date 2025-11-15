# Pokerchain Documentation Index

All project documentation has been organized into this `documents/` folder.

## Core Documentation

### Getting Started

-   [**README.md**](./README.md) - Main project overview and quick start guide
-   [**QUICKSTART.md**](./QUICKSTART.md) - Quick setup guide for different node types
-   [**CLAUDE.md**](./CLAUDE.md) - Project overview and guidance for AI assistants

### Development

-   [**RUN_DEV_NODE.md**](./RUN_DEV_NODE.md) - Developer node setup guide
-   [**README_SCRIPTS.md**](./README_SCRIPTS.md) - Documentation for startup scripts
-   [**MAKEFILE_TARGETS.md**](./MAKEFILE_TARGETS.md) - Available make commands
-   [**BINARY-MANAGEMENT.md**](./BINARY-MANAGEMENT.md) - Binary build and deployment practices

### Deployment

-   [**DEPLOYMENT.md**](./DEPLOYMENT.md) - Master node deployment guide
-   [**VALIDATOR_GUIDE.md**](./VALIDATOR_GUIDE.md) - Complete validator guide
-   [**VALIDATOR-SETUP.md**](./VALIDATOR-SETUP.md) - Node1 validator setup details

### Bridge

-   [**BRIDGE_README.md**](./BRIDGE_README.md) - Ethereum USDC bridge overview
-   [**BRIDGE_CONFIGURATION.md**](./BRIDGE_CONFIGURATION.md) - Bridge configuration guide
-   [**BRIDGE_DEPOSIT_FLOW.md**](./BRIDGE_DEPOSIT_FLOW.md) - Bridge deposit processing flow (archived)

### Testing & Operations

-   [**BLOCK-PRODUCTION-TESTING.md**](./BLOCK-PRODUCTION-TESTING.md) - Block production verification guide
-   [**BLOCK-PRODUCTION-SUMMARY.md**](./BLOCK-PRODUCTION-SUMMARY.md) - Block production implementation summary
-   [**TEST_ACTORS.md**](./TEST_ACTORS.md) - Test accounts with seed phrases

### Network Configuration

-   [**GENESIS_SUMMARY.md**](./GENESIS_SUMMARY.md) - Genesis file creation summary

### Planning & Architecture

-   [**deleting_the_pvm.md**](./deleting_the_pvm.md) - PVM migration planning (future work)

## Archived Documents

Documents related to completed work or resolved issues are in the [`archived/`](./archived/) folder:

-   [**.github-issue-ts-client-generation.md**](./archived/.github-issue-ts-client-generation.md) - TypeScript client generation (resolved)
-   [**.github-issue-sdk-protobuf-types.md**](./archived/.github-issue-sdk-protobuf-types.md) - SDK protobuf types automation (resolved)

## Document Relevance Review

All documents were reviewed on November 15, 2025:

### ✅ Still Relevant

-   All core documentation (README, QUICKSTART, CLAUDE.md)
-   All development guides (RUN_DEV_NODE, MAKEFILE_TARGETS, etc.)
-   All deployment and validator guides
-   Bridge documentation (actively used feature)
-   Test actors (used for development)
-   Block production testing (operational necessity)
-   PVM deletion planning (future work)

### 📦 Archived

-   GitHub issue documents about TypeScript/SDK generation (already resolved)
-   BRIDGE_DEPOSIT_FLOW.md marked as complete/archived but kept for reference

### ❌ Removed

-   None - all documents contain useful information

## Updating This Documentation

When adding new documentation:

1. Place the file in this `documents/` folder
2. Update this INDEX.md with a link and description
3. Use relative links when referencing other docs
