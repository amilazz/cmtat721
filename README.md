# CMTAT721

CMTAT721 is an ERC721 adaptation of CMTA CMTAT modules, with compliance-focused controls and pluggable external engines.

It combines:
- ERC721 token behavior (OpenZeppelin upgradeable base)
- CMTA modules (allowlist, validation, enforcement, pause, document engine, extra info)
- Optional external `IRuleEngine` (transfer validation and callbacks)
- Optional external `ITokenIdEngine` (token ID assignment strategy)

## Why the New Token ID Engine Exists

### Short answer
The token ID strategy is business-specific, so this project externalizes it to `ITokenIdEngine` instead of hardcoding one minting policy.

### Rationale
The same token can need different ID policies depending on issuer requirements:
- Minter-provided IDs
- User-provided IDs
- Auto-generated IDs from external logic
- Fallback behavior if engine is unavailable

`ITokenIdEngine` keeps mint flow stable while allowing ID policy to evolve independently.

### How it works
1. `CMTAT721Base` calls `tokenIdEngine.getTokenId(...)` during mint when an engine is configured.
2. If no engine is configured, it uses the provided tokenId.
3. If the engine call fails, it falls back to the provided tokenId.

This gives deterministic behavior and avoids mint failures caused by optional engine outages.

## New Non-Breaking Constructor Extension

To avoid modifying vendor CMTA interfaces directly, this project adds a local extension:
- `contracts/interfaces/ICMTAT721Constructor.sol`

It introduces:
- `ERC721Attributes { name, symbol }`

and keeps existing APIs intact.

Added non-breaking entrypoints:
- `initializeWithERC721Attributes(...)` in `CMTAT721Base`
- `CMTAT721StandaloneWithERC721Attributes` deployment contract

Existing `initialize(...)` and `CMTAT721Standalone` remain fully supported.

## ERC721 Metadata URI Support

This project now includes explicit base URI support:
- `setBaseURI(string)` (admin-only)
- `baseURI()` getter
- `_baseURI()` override used by OpenZeppelin `tokenURI(tokenId)`

Behavior:
- Default base URI is empty string
- `tokenURI(tokenId)` resolves to `<baseURI><tokenId>` after setting base URI
- Re-setting the same URI reverts with `CMTAT_BaseURI_SameValue`

## Engines in This Repo

### Token ID Engine (`ITokenIdEngine`)
- Interface: `contracts/interfaces/ITokenIdEngine.sol`
- Mock: `contracts/mocks/TokenIdEngineMock.sol`
- Token wiring: `contracts/modules/CMTAT721Base.sol`

If no token ID engine is configured, minting uses the provided fallback tokenId.

### Rule Engine (`IRuleEngine`)
- Interface source: `vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol`
- Test implementation: `contracts/mocks/RuleEngine721Mock.sol`
- Token wiring: `contracts/modules/CMTAT721Base.sol`

## Contracts

Core:
- `contracts/modules/CMTAT721Base.sol`

Deployment:
- `contracts/deployment/CMTAT721Standalone.sol`
- `contracts/deployment/CMTAT721StandaloneWithERC721Attributes.sol`
- `contracts/deployment/CMTAT721Upgradeable.sol` (UUPS)

Mocks:
- `contracts/mocks/RuleEngine721Mock.sol`
- `contracts/mocks/TokenIdEngineMock.sol`
- `contracts/mocks/DocumentEngineMock.sol`
- `contracts/mocks/CMTAT721InitHarness.sol`

## Test Coverage

Hardhat tests (`test/*.js`) and Foundry tests (`test/foundry/*.t.sol`) cover:
- Deployment flows (standalone + UUPS)
- Rule engine integration and callbacks
- Allowlist/pause/freeze module behavior
- Token ID engine behavior
- ERC721 base URI and `tokenURI` behavior
- Fuzz flows for core mint/transfer behavior

## Local Development

Requirements:
- Node.js + npm
- Foundry (`forge`)

Install:
```bash
npm install
```

Compile:
```bash
npm run compile
```

Run Hardhat tests:
```bash
npm test
```

Run Foundry tests:
```bash
npm run test:forge
```

## Notes on Upgrade Warnings

Hardhat upgrade checks currently emit initializer-order warnings inherited from CMTA module composition. Tests intentionally allow the known flags used in this project (`unsafeAllow`) to keep compatibility with the current architecture.

## Summary

The token is built to be **engine-driven**:
- Token core remains stable and reusable
- Token ID policy is pluggable via `ITokenIdEngine`
- Compliance policy is pluggable via `IRuleEngine`
- Tests use mocks for deterministic validation
