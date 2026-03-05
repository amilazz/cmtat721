// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title Token ID Engine Interface
 * @notice External engine used by CMTAT721 contracts to resolve token IDs at mint time.
 * @dev Implementations can apply arbitrary policies (sequences, hashes, off-chain sync, etc.).
 */
interface ITokenIdEngine {
    /**
     * @notice Returns the token ID to use for a mint operation.
     * @param operator Caller that triggered minting in the token contract.
     * @param account Receiver account of the minted token.
     * @param data Opaque payload forwarded by the token contract.
     * @return tokenId Token ID selected by the engine.
     */
    function getTokenId(address operator, address account, bytes calldata data) external returns (uint256 tokenId);
}
