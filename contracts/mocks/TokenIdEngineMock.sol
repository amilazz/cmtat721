// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ITokenIdEngine} from "../interfaces/ITokenIdEngine.sol";

/**
 * @title Minimal User Mint Entry Point
 * @notice Interface used by `TokenIdEngineMock` for reentrancy simulations in USER_INPUT mode.
 */
interface ICMTAT721MintByUser {
    /**
     * @notice Mints to `msg.sender` in USER_INPUT mode.
     * @param tokenId Token ID requested by caller.
     * @param data Arbitrary mint payload.
     */
    function mintByUser(uint256 tokenId, bytes calldata data) external;
}

/**
 * @title Minimal Minter Entry Points
 * @notice Interface used by `TokenIdEngineMock` for reentrancy simulations in MINTER_INPUT mode.
 */
interface ICMTAT721Minter {
    /**
     * @notice Mints one token to a target account.
     * @param account Recipient account.
     * @param tokenId Token ID to mint.
     * @param data Arbitrary mint payload.
     */
    function mint(address account, uint256 tokenId, bytes calldata data) external;
    /**
     * @notice Batch mint entry point.
     * @param accounts Recipient accounts.
     * @param tokenIds Token IDs.
     * @param data Arbitrary mint payload.
     */
    function batchMint(address[] calldata accounts, uint256[] calldata tokenIds, bytes calldata data) external;
}

/**
 * @title Token ID Engine Mock
 * @notice Test token ID engine with fallback and reentrancy scenarios.
 */
contract TokenIdEngineMock is ITokenIdEngine {
    /// @notice Token ID returned by default by `getTokenId`.
    uint256 public tokenIdToReturn;
    /// @notice Forces `getTokenId` to revert when set.
    bool public shouldRevert;

    /// @notice Enables the configured reentrancy attempt mode.
    bool public shouldAttemptReentrancy;
    /// @notice Flag set when reentrancy was blocked by target contract.
    bool public reentrancyBlocked;
    /// @notice Reentrancy mode (`1`: mintByUser, `2`: mint, `3`: batchMint).
    uint8 public reentrancyMode;
    /// @notice Target CMTAT721 contract for reentrancy attempts.
    address public reentrancyTarget;
    /// @notice Account used for `mint` and `batchMint` reentrancy attempts.
    address public reentrancyAccount;
    /// @notice Token ID used during reentrancy attempts.
    uint256 public reentrancyTokenId;
    /// @notice Payload forwarded during reentrancy attempts.
    bytes public reentrancyData;

    /**
     * @notice Creates the mock with an initial token ID result.
     * @param tokenIdToReturn_ Initial `getTokenId` output.
     */
    constructor(uint256 tokenIdToReturn_) {
        tokenIdToReturn = tokenIdToReturn_;
    }

    /**
     * @notice Updates the token ID returned by `getTokenId`.
     * @param tokenIdToReturn_ New token ID value.
     */
    function setTokenIdToReturn(uint256 tokenIdToReturn_) external {
        tokenIdToReturn = tokenIdToReturn_;
    }

    /**
     * @notice Configures whether `getTokenId` should revert.
     * @param shouldRevert_ Revert flag.
     */
    function setShouldRevert(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    /**
     * @notice Configures a reentrancy probe during `getTokenId`.
     * @param target CMTAT721 target contract.
     * @param account Account used for minter-mode reentrancy.
     * @param tokenId Token ID to use in reentrancy call.
     * @param data Payload forwarded to reentrancy call.
     * @param mode Reentrancy mode (`0` disables attempts).
     */
    function configureReentrancy(
        address target,
        address account,
        uint256 tokenId,
        bytes calldata data,
        uint8 mode
    ) external {
        reentrancyTarget = target;
        reentrancyAccount = account;
        reentrancyTokenId = tokenId;
        reentrancyData = data;
        reentrancyMode = mode;
        shouldAttemptReentrancy = mode != 0;
        reentrancyBlocked = false;
    }

    /**
     * @inheritdoc ITokenIdEngine
     * @dev Can optionally revert or attempt one reentrant call before returning.
     */
    function getTokenId(address, address, bytes calldata) external override returns (uint256 tokenId) {
        if (shouldRevert) {
            revert("engine unavailable");
        }

        if (shouldAttemptReentrancy) {
            if (reentrancyMode == 1) {
                try ICMTAT721MintByUser(reentrancyTarget).mintByUser(reentrancyTokenId, reentrancyData) {
                    reentrancyBlocked = false;
                } catch {
                    reentrancyBlocked = true;
                }
            } else if (reentrancyMode == 2) {
                try ICMTAT721Minter(reentrancyTarget).mint(reentrancyAccount, reentrancyTokenId, reentrancyData) {
                    reentrancyBlocked = false;
                } catch {
                    reentrancyBlocked = true;
                }
            } else if (reentrancyMode == 3) {
                address[] memory accounts = new address[](1);
                uint256[] memory tokenIds = new uint256[](1);
                accounts[0] = reentrancyAccount;
                tokenIds[0] = reentrancyTokenId;
                try ICMTAT721Minter(reentrancyTarget).batchMint(accounts, tokenIds, reentrancyData) {
                    reentrancyBlocked = false;
                } catch {
                    reentrancyBlocked = true;
                }
            }
        }

        return tokenIdToReturn;
    }
}
