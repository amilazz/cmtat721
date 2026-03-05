// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";

/**
 * @title Rule Engine 721 Mock
 * @notice Test double for transfer validation and transfer notifications.
 */
contract RuleEngine721Mock is IRuleEngine {
    /// @notice Whether `canTransfer` and `transferred(from,to,value)` are allowed.
    bool public transfersAllowed = true;
    /// @notice Whether `canTransferFrom` and `transferred(spender,from,to,value)` are allowed.
    bool public transferFromAllowed = true;

    /// @notice Number of transfer notifications without explicit spender.
    uint256 public transferredNoSpenderCount;
    /// @notice Number of transfer notifications with explicit spender.
    uint256 public transferredWithSpenderCount;

    /**
     * @notice Sets transfer policy for `canTransfer`.
     * @param allowed_ New policy value.
     */
    function setTransfersAllowed(bool allowed_) external {
        transfersAllowed = allowed_;
    }

    /**
     * @notice Sets transfer policy for `canTransferFrom`.
     * @param allowed_ New policy value.
     */
    function setTransferFromAllowed(bool allowed_) external {
        transferFromAllowed = allowed_;
    }

    /**
     * @notice Validates transfer without explicit spender.
     * @param value Transfer value.
     * @return allowed `true` when transfer is allowed.
     */
    function canTransfer(address, address, uint256 value) external view override returns (bool) {
        return transfersAllowed && value == 1;
    }

    /**
     * @notice Validates transfer with explicit spender.
     * @param value Transfer value.
     * @return allowed `true` when transfer is allowed.
     */
    function canTransferFrom(address, address, address, uint256 value) external view override returns (bool) {
        return transferFromAllowed && value == 1;
    }

    /**
     * @notice Notifies engine about transfer without explicit spender.
     * @param value Transfer value.
     */
    function transferred(address, address, uint256 value) external override {
        require(transfersAllowed && value == 1, "invalid transfer");
        unchecked {
            ++transferredNoSpenderCount;
        }
    }

    /**
     * @notice Notifies engine about transfer with explicit spender.
     * @param value Transfer value.
     */
    function transferred(address, address, address, uint256 value) external override {
        require(transferFromAllowed && value == 1, "invalid transferFrom");
        unchecked {
            ++transferredWithSpenderCount;
        }
    }

    /**
     * @notice Returns restriction code for transfer without explicit spender.
     * @param from Source account.
     * @param to Destination account.
     * @param value Transfer value.
     * @return restrictionCode `0` when allowed, `1` otherwise.
     */
    function detectTransferRestriction(address from, address to, uint256 value) external view override returns (uint8) {
        return this.canTransfer(from, to, value) ? 0 : 1;
    }

    /**
     * @notice Returns restriction code for transfer with explicit spender.
     * @param spender Token spender.
     * @param from Source account.
     * @param to Destination account.
     * @param value Transfer value.
     * @return restrictionCode `0` when allowed, `1` otherwise.
     */
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        external
        view
        override
        returns (uint8)
    {
        return this.canTransferFrom(spender, from, to, value) ? 0 : 1;
    }

    /**
     * @notice Returns a human-readable description for a restriction code.
     * @param restrictionCode Restriction code.
     * @return message Description of the code.
     */
    function messageForTransferRestriction(uint8 restrictionCode) external pure override returns (string memory) {
        return restrictionCode == 0 ? "OK" : "BLOCKED";
    }
}
