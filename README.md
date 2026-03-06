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
3. If the engine call fails and degraded mode is enabled, it falls back to the provided tokenId.
4. If the engine call fails and degraded mode is disabled, mint reverts with `CMTAT_TokenIdEngineUnavailable`.

This gives deterministic behavior and keeps fallback policy explicitly governed.

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

If no token ID engine is configured, minting uses the provided fallback tokenId and emits `TokenIdFallbackUsed`.

When a token ID engine is configured:
- If `getTokenId(...)` succeeds, the engine-provided tokenId is used.
- If `getTokenId(...)` reverts:
  - With degraded mode disabled, mint reverts (`CMTAT_TokenIdEngineUnavailable`).
  - With degraded mode enabled, fallback tokenId is used and `TokenIdFallbackUsed` is emitted.

Degraded mode is controlled by `setTokenIdEngineDegradedMode(bool)` and restricted to `TOKEN_ID_ENGINE_GUARDIAN_ROLE`.

### Rule Engine (`IRuleEngine`)
- Interface source: `vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol`
- Test implementation: `contracts/mocks/RuleEngine721Mock.sol`
- Token wiring: `contracts/modules/CMTAT721Base.sol`

## Complete Function Matrix

The table below covers **all callable functions** in the deployed `CMTAT721Standalone` ABI.

- `State = view` gives the view-only surface you asked for.
- `State = nonpayable` are state-changing functions.

| Function | Module | Inputs | Outputs | State | Who Can Invoke |
|---|---|---|---|---|---|
| `ALLOWLIST_ROLE()` | AllowlistModule | - | `bytes32` | `view` | No restriction (constant getter) |
| `BURNER_ROLE()` | CMTAT721Base | - | `bytes32` | `view` | No restriction (constant getter) |
| `DEFAULT_ADMIN_ROLE()` | AccessControlUpgradeable | - | `bytes32` | `view` | No restriction (constant getter) |
| `DOCUMENT_ROLE()` | DocumentEngineModule | - | `bytes32` | `view` | No restriction (constant getter) |
| `ENFORCER_ROLE()` | EnforcementModule | - | `bytes32` | `view` | No restriction (constant getter) |
| `EXTRA_INFORMATION_ROLE()` | ExtraInformationModule | - | `bytes32` | `view` | No restriction (constant getter) |
| `MINTER_ROLE()` | CMTAT721Base | - | `bytes32` | `view` | No restriction (constant getter) |
| `PAUSER_ROLE()` | PauseModule | - | `bytes32` | `view` | No restriction (constant getter) |
| `TOKEN_ID_ENGINE_GUARDIAN_ROLE()` | CMTAT721Base | - | `bytes32` | `view` | No restriction (constant getter) |
| `approve(address,uint256)` | ERC721Upgradeable | `address` to<br>`uint256` tokenId | - | `nonpayable` | Token owner or approved operator |
| `balanceOf(address)` | ERC721Upgradeable | `address` owner | `uint256` | `view` | Read-only |
| `baseURI()` | CMTAT721Base (metadata) | - | `string` | `view` | Read-only |
| `batchBurn(address[],uint256[],bytes)` | CMTAT721Base (mint/burn) | `address[]` accounts<br>`uint256[]` tokenIds<br>`bytes` data | - | `nonpayable` | `BURNER_ROLE` |
| `batchMint(address[],uint256[],bytes)` | CMTAT721Base (mint/burn) | `address[]` accounts<br>`uint256[]` tokenIds<br>`bytes` data | - | `nonpayable` | `MINTER_ROLE` + `tokenIdManagementMode == MINTER_INPUT` |
| `batchSetAddressAllowlist(address[],bool[])` | AllowlistModule | `address[]` accounts<br>`bool[]` status | - | `nonpayable` | `ALLOWLIST_ROLE` |
| `batchSetAddressFrozen(address[],bool[])` | EnforcementModule | `address[]` accounts<br>`bool[]` freezes | - | `nonpayable` | `ENFORCER_ROLE` |
| `burn(address,uint256,bytes)` | CMTAT721Base (mint/burn) | `address` account<br>`uint256` tokenId<br>`bytes` data | - | `nonpayable` | `BURNER_ROLE` |
| `canTransfer(address,address,uint256)` | CMTAT721Base (validation) | `address` from<br>`address` to<br>`uint256` | `bool` | `view` | Read-only |
| `canTransferFrom(address,address,address,uint256)` | CMTAT721Base (validation) | `address` spender<br>`address` from<br>`address` to<br>`uint256` | `bool` | `view` | Read-only |
| `deactivateContract()` | PauseModule | - | - | `nonpayable` | `DEFAULT_ADMIN_ROLE` and contract must be paused |
| `deactivated()` | PauseModule | - | `bool` | `view` | Read-only |
| `documentEngine()` | DocumentEngineModule | - | `address` documentEngine_ | `view` | Read-only |
| `enableAllowlist(bool)` | AllowlistModule | `bool` status | - | `nonpayable` | `ALLOWLIST_ROLE` |
| `forcedTransfer(address,address,uint256,bytes)` | CMTAT721Base (enforcement) | `address` from<br>`address` to<br>`uint256` tokenId<br>`bytes` data | `bool` | `nonpayable` | `DEFAULT_ADMIN_ROLE` |
| `getAllDocuments()` | DocumentEngineModule | - | `string[]` documentNames_ | `view` | Read-only |
| `getApproved(uint256)` | ERC721Upgradeable | `uint256` tokenId | `address` | `view` | Read-only |
| `getDocument(string)` | DocumentEngineModule | `string` name | `tuple` document | `view` | Read-only |
| `getRoleAdmin(bytes32)` | AccessControlUpgradeable | `bytes32` role | `bytes32` | `view` | Read-only |
| `grantRole(bytes32,address)` | AccessControlUpgradeable | `bytes32` role<br>`address` account | - | `nonpayable` | Caller must have admin role for target role |
| `hasRole(bytes32,address)` | AccessControlUpgradeable | `bytes32` role<br>`address` account | `bool` | `view` | Read-only |
| `information()` | ExtraInformationModule | - | `string` information_ | `view` | Read-only |
| `initialize(address,string,string,tuple,address,address,address,uint8)` | CMTAT721Base (init) | `address` admin<br>`string` name_<br>`string` symbol_<br>`tuple` extraInformationAttributes_ (string tokenId; tuple terms; string information)<br>`address` documentEngine_<br>`address` ruleEngine_<br>`address` tokenIdEngine_<br>`uint8` tokenIdManagementMode_ | - | `nonpayable` | Initializer: callable once |
| `initializeWithERC721Attributes(address,tuple,tuple,address,address,address,uint8)` | CMTAT721Base (init) | `address` admin<br>`tuple` ERC721Attributes_ (string name; string symbol)<br>`tuple` extraInformationAttributes_ (string tokenId; tuple terms; string information)<br>`address` documentEngine_<br>`address` ruleEngine_<br>`address` tokenIdEngine_<br>`uint8` tokenIdManagementMode_ | - | `nonpayable` | Initializer: callable once |
| `isAllowlistEnabled()` | AllowlistModule | - | `bool` | `view` | Read-only |
| `isAllowlisted(address)` | AllowlistModule | `address` account | `bool` | `view` | Read-only |
| `isApprovedForAll(address,address)` | ERC721Upgradeable | `address` owner<br>`address` operator | `bool` | `view` | Read-only |
| `isFrozen(address)` | EnforcementModule | `address` account | `bool` isFrozen_ | `view` | Read-only |
| `mint(address,uint256,bytes)` | CMTAT721Base (mint/burn) | `address` account<br>`uint256` tokenId<br>`bytes` data | - | `nonpayable` | `MINTER_ROLE` + `tokenIdManagementMode == MINTER_INPUT` |
| `mintByUser(uint256,bytes)` | CMTAT721Base (mint/burn) | `uint256` tokenId<br>`bytes` data | - | `nonpayable` | Any caller, but only when `tokenIdManagementMode == USER_INPUT` |
| `name()` | ERC721Upgradeable | - | `string` | `view` | Read-only |
| `ownerOf(uint256)` | ERC721Upgradeable | `uint256` tokenId | `address` | `view` | Read-only |
| `pause()` | PauseModule | - | - | `nonpayable` | `PAUSER_ROLE` |
| `paused()` | PauseModule | - | `bool` | `view` | Read-only |
| `renounceRole(bytes32,address)` | AccessControlUpgradeable | `bytes32` role<br>`address` callerConfirmation | - | `nonpayable` | Caller can only renounce own role |
| `revokeRole(bytes32,address)` | AccessControlUpgradeable | `bytes32` role<br>`address` account | - | `nonpayable` | Caller must have admin role for target role |
| `ruleEngine()` | ValidationModuleRuleEngineInternal | - | `address` | `view` | Read-only |
| `safeTransferFrom(address,address,uint256)` | ERC721Upgradeable/CMTAT721Base | `address` from<br>`address` to<br>`uint256` tokenId | - | `nonpayable` | Token owner or approved operator; transfer checks enforced |
| `safeTransferFrom(address,address,uint256,bytes)` | ERC721Upgradeable/CMTAT721Base | `address` from<br>`address` to<br>`uint256` tokenId<br>`bytes` data | - | `nonpayable` | Token owner or approved operator; transfer checks enforced |
| `setAddressAllowlist(address,bool,bytes)` | AllowlistModule | `address` account<br>`bool` status<br>`bytes` data | - | `nonpayable` | `ALLOWLIST_ROLE` |
| `setAddressAllowlist(address,bool)` | AllowlistModule | `address` account<br>`bool` status | - | `nonpayable` | `ALLOWLIST_ROLE` |
| `setAddressFrozen(address,bool,bytes)` | EnforcementModule | `address` account<br>`bool` freeze<br>`bytes` data | - | `nonpayable` | `ENFORCER_ROLE` |
| `setAddressFrozen(address,bool)` | EnforcementModule | `address` account<br>`bool` freeze | - | `nonpayable` | `ENFORCER_ROLE` |
| `setApprovalForAll(address,bool)` | ERC721Upgradeable | `address` operator<br>`bool` approved | - | `nonpayable` | Token owner |
| `setBaseURI(string)` | CMTAT721Base (metadata) | `string` baseURI_ | - | `nonpayable` | `DEFAULT_ADMIN_ROLE` |
| `setDocumentEngine(address)` | DocumentEngineModule | `address` documentEngine_ | - | `nonpayable` | `DOCUMENT_ROLE` |
| `setInformation(string)` | ExtraInformationModule | `string` information_ | - | `nonpayable` | `EXTRA_INFORMATION_ROLE` |
| `setRuleEngine(address)` | CMTAT721Base (rule engine) | `address` ruleEngine_ | - | `nonpayable` | `DEFAULT_ADMIN_ROLE` |
| `setTerms(tuple)` | ExtraInformationModule | `tuple` terms_ (string name; string uri; bytes32 documentHash) | - | `nonpayable` | `EXTRA_INFORMATION_ROLE` |
| `setTokenId(string)` | ExtraInformationModule | `string` tokenId_ | - | `nonpayable` | `EXTRA_INFORMATION_ROLE` |
| `setTokenIdEngine(address)` | CMTAT721Base (tokenId engine) | `address` tokenIdEngine_ | - | `nonpayable` | `DEFAULT_ADMIN_ROLE` |
| `setTokenIdEngineDegradedMode(bool)` | CMTAT721Base (tokenId engine) | `bool` enabled | - | `nonpayable` | `TOKEN_ID_ENGINE_GUARDIAN_ROLE` |
| `supportsInterface(bytes4)` | ERC165/AccessControl/CMTAT721Base | `bytes4` interfaceId | `bool` | `view` | Read-only |
| `symbol()` | ERC721Upgradeable | - | `string` | `view` | Read-only |
| `terms()` | ExtraInformationModule | - | `tuple` terms_ | `view` | Read-only |
| `tokenId()` | ExtraInformationModule | - | `string` tokenId_ | `view` | Read-only |
| `tokenIdEngine()` | CMTAT721Base (tokenId engine) | - | `address` | `view` | Read-only |
| `tokenIdEngineDegradedMode()` | CMTAT721Base (tokenId engine) | - | `bool` | `view` | Read-only |
| `tokenIdManagementMode()` | CMTAT721Base (tokenId engine) | - | `uint8` | `view` | Read-only |
| `tokenURI(uint256)` | ERC721Upgradeable/CMTAT721Base | `uint256` tokenId | `string` | `view` | Read-only |
| `transferFrom(address,address,uint256)` | ERC721Upgradeable/CMTAT721Base | `address` from<br>`address` to<br>`uint256` tokenId | - | `nonpayable` | Token owner or approved operator; transfer checks enforced |
| `unpause()` | PauseModule | - | - | `nonpayable` | `PAUSER_ROLE` and contract must not be deactivated |
| `version()` | VersionModule | - | `string` version_ | `view` | Read-only |

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
- Token ID engine degraded-mode governance and fallback events
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
