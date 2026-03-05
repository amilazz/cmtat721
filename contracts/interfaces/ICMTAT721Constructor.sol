// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ICMTATConstructor} from "../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";

/**
 * @notice Constructor/initializer argument types for CMTAT721 deployments.
 * @dev Extends the base CMTAT constructor interface without changing it.
 */
interface ICMTAT721Constructor is ICMTATConstructor {
    /**
     * @notice Core ERC721 metadata attributes.
     * @param name Token name exposed by ERC721 metadata.
     * @param symbol Token symbol exposed by ERC721 metadata.
     */
    struct ERC721Attributes {
        // token name
        string name;
        // token symbol
        string symbol;
    }
}
