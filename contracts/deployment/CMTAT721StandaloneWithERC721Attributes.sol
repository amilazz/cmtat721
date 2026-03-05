// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {ICMTATConstructor} from "../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";
import {ICMTAT721Constructor} from "../interfaces/ICMTAT721Constructor.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../modules/CMTAT721Base.sol";
import {ITokenIdEngine} from "../interfaces/ITokenIdEngine.sol";

/**
 * @title CMTAT721 Standalone Deployment (ERC721 Attribute Struct)
 * @notice Non-proxy deployment wrapper using a struct for ERC721 name/symbol.
 * @dev Constructor delegates to `initializeWithERC721Attributes` for consistency with base init flow.
 */
contract CMTAT721StandaloneWithERC721Attributes is CMTAT721Base {
    /**
     * @notice Deploys and initializes a standalone CMTAT721 token.
     * @param admin Default admin role holder.
     * @param ERC721Attributes_ ERC721 metadata attributes.
     * @param extraInformationAttributes_ CMTAT metadata bundle.
     * @param documentEngine_ External document engine.
     * @param ruleEngine_ External rule engine (optional).
     * @param tokenIdEngine_ External token ID engine (optional).
     * @param tokenIdManagementMode_ Mint mode policy.
     */
    constructor(
        address admin,
        ICMTAT721Constructor.ERC721Attributes memory ERC721Attributes_,
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) {
        initializeWithERC721Attributes(
            admin,
            ERC721Attributes_,
            extraInformationAttributes_,
            documentEngine_,
            ruleEngine_,
            tokenIdEngine_,
            tokenIdManagementMode_
        );
    }
}
