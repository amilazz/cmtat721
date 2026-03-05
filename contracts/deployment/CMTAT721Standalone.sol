// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {ICMTATConstructor} from "../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../modules/CMTAT721Base.sol";
import {ITokenIdEngine} from "../interfaces/ITokenIdEngine.sol";

/**
 * @title CMTAT721 Standalone Deployment
 * @notice Non-proxy deployment wrapper for `CMTAT721Base`.
 * @dev Constructor delegates to the initializer to keep a single initialization flow.
 */
contract CMTAT721Standalone is CMTAT721Base {
    /**
     * @notice Deploys and initializes a standalone CMTAT721 token.
     * @param admin Default admin role holder.
     * @param name_ ERC721 token name.
     * @param symbol_ ERC721 token symbol.
     * @param extraInformationAttributes_ CMTAT metadata bundle.
     * @param documentEngine_ External document engine.
     * @param ruleEngine_ External rule engine (optional).
     * @param tokenIdEngine_ External token ID engine (optional).
     * @param tokenIdManagementMode_ Mint mode policy.
     */
    constructor(
        address admin,
        string memory name_,
        string memory symbol_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) {
        initialize(
            admin,
            name_,
            symbol_,
            extraInformationAttributes_,
            documentEngine_,
            ruleEngine_,
            tokenIdEngine_,
            tokenIdManagementMode_
        );
    }
}
