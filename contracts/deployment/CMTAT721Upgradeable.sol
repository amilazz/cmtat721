// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {CMTAT721Base} from "../modules/CMTAT721Base.sol";

/**
 * @title CMTAT721 Upgradeable Deployment
 * @notice UUPS proxy implementation for CMTAT721.
 * @dev Initialization must be done through proxy using `initialize`.
 */
contract CMTAT721Upgradeable is CMTAT721Base, UUPSUpgradeable {
    /// @notice Role required to authorize UUPS implementation upgrades.
    bytes32 public constant PROXY_UPGRADE_ROLE = keccak256("PROXY_UPGRADE_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     * @dev Disables initializers on the implementation contract.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Authorizes implementation upgrade.
     */
    function _authorizeUpgrade(address) internal virtual override onlyRole(PROXY_UPGRADE_ROLE) {}
}
