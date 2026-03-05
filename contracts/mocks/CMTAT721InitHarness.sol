// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {ICMTATConstructor} from "../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../modules/CMTAT721Base.sol";
import {ITokenIdEngine} from "../interfaces/ITokenIdEngine.sol";

/**
 * @title CMTAT721 Initializer Harness
 * @notice Test-only harness exposing internal initializer stages.
 * @dev Used to validate initializer guards and CMTAT-style init sequencing.
 */
contract CMTAT721InitHarness is CMTAT721Base {
    /**
     * @notice Calls `_initialize` directly.
     * @param admin Default admin role holder.
     * @param name_ ERC721 token name.
     * @param symbol_ ERC721 token symbol.
     * @param extraInformationAttributes_ CMTAT metadata attributes.
     * @param documentEngine_ Document engine address.
     * @param ruleEngine_ Rule engine address.
     * @param tokenIdEngine_ Token ID engine address.
     * @param tokenIdManagementMode_ Mint mode configuration.
     */
    function callInitializeInternal(
        address admin,
        string calldata name_,
        string calldata symbol_,
        ICMTATConstructor.ExtraInformationAttributes calldata extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) external {
        _initialize(
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

    /**
     * @notice Calls `__CMTAT721_init` directly.
     * @param admin Default admin role holder.
     * @param name_ ERC721 token name.
     * @param symbol_ ERC721 token symbol.
     * @param extraInformationAttributes_ CMTAT metadata attributes.
     * @param documentEngine_ Document engine address.
     * @param ruleEngine_ Rule engine address.
     * @param tokenIdEngine_ Token ID engine address.
     * @param tokenIdManagementMode_ Mint mode configuration.
     */
    function callCMTAT721Init(
        address admin,
        string calldata name_,
        string calldata symbol_,
        ICMTATConstructor.ExtraInformationAttributes calldata extraInformationAttributes_,
        IERC1643 documentEngine_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) external {
        __CMTAT721_init(
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

    /**
     * @notice Calls `__CMTAT721_internal_init_unchained` directly.
     * @param ruleEngine_ Rule engine address.
     * @param tokenIdEngine_ Token ID engine address.
     * @param tokenIdManagementMode_ Mint mode configuration.
     */
    function callCMTAT721InternalInit(
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode tokenIdManagementMode_
    ) external {
        __CMTAT721_internal_init_unchained(ruleEngine_, tokenIdEngine_, tokenIdManagementMode_);
    }

    /**
     * @notice Calls `__CMTAT721_modules_init_unchained` directly.
     */
    function callCMTAT721ModulesInit() external {
        __CMTAT721_modules_init_unchained();
    }

    /**
     * @notice Calls `__TokenIdEngine_init_unchained` directly.
     * @param tokenIdEngine_ Token ID engine address.
     */
    function callTokenIdEngineInit(ITokenIdEngine tokenIdEngine_) external {
        __TokenIdEngine_init_unchained(tokenIdEngine_);
    }
}
