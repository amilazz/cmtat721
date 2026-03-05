// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IRuleEngine} from "../../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {ICMTATConstructor} from "../../../vendor/CMTAT/contracts/interfaces/technical/ICMTATConstructor.sol";
import {IERC1643CMTAT} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC1643CMTAT.sol";

import {ITokenIdEngine} from "../../../contracts/interfaces/ITokenIdEngine.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../../../contracts/modules/CMTAT721Base.sol";
import {CMTAT721Standalone} from "../../../contracts/deployment/CMTAT721Standalone.sol";
import {CMTAT721Upgradeable} from "../../../contracts/deployment/CMTAT721Upgradeable.sol";
import {DocumentEngineMock} from "../../../contracts/mocks/DocumentEngineMock.sol";

abstract contract CMTAT721TestUtils is Test {
    bytes internal constant EMPTY_BYTES = "";

    address internal admin = address(this);
    address internal address1 = address(0x1001);
    address internal address2 = address(0x1002);
    address internal address3 = address(0x1003);
    address internal outsider = address(0x1004);

    function _extraInfo() internal pure returns (ICMTATConstructor.ExtraInformationAttributes memory extraInfo_) {
        extraInfo_ = ICMTATConstructor.ExtraInformationAttributes({
            tokenId: "CH0000NFT721",
            terms: IERC1643CMTAT.DocumentInfo({
                name: "terms",
                uri: "ipfs://terms",
                documentHash: keccak256(bytes("terms-hash"))
            }),
            information: "CMTAT 721 compatible token"
        });
    }

    function _deployStandalone(
        address admin_,
        string memory name_,
        string memory symbol_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode mode_
    ) internal returns (CMTAT721Standalone token_, DocumentEngineMock documentEngine_) {
        documentEngine_ = new DocumentEngineMock();
        token_ = new CMTAT721Standalone(
            admin_,
            name_,
            symbol_,
            _extraInfo(),
            IERC1643(address(documentEngine_)),
            ruleEngine_,
            tokenIdEngine_,
            mode_
        );
    }

    function _deployStandaloneDefault() internal returns (CMTAT721Standalone token_, DocumentEngineMock documentEngine_) {
        return _deployStandalone(
            admin,
            "CMTAT 721",
            "C721",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );
    }

    function _deployUUPSProxy(
        address admin_,
        string memory name_,
        string memory symbol_,
        IRuleEngine ruleEngine_,
        ITokenIdEngine tokenIdEngine_,
        TokenIdManagementMode mode_
    ) internal returns (CMTAT721Upgradeable token_, DocumentEngineMock documentEngine_, CMTAT721Upgradeable implementation_) {
        implementation_ = new CMTAT721Upgradeable();
        documentEngine_ = new DocumentEngineMock();

        bytes memory initData = abi.encodeWithSelector(
            CMTAT721Base.initialize.selector,
            admin_,
            name_,
            symbol_,
            _extraInfo(),
            IERC1643(address(documentEngine_)),
            ruleEngine_,
            tokenIdEngine_,
            mode_
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation_), initData);
        token_ = CMTAT721Upgradeable(address(proxy));
    }

    function _deployUUPSDefault()
        internal
        returns (CMTAT721Upgradeable token_, DocumentEngineMock documentEngine_, CMTAT721Upgradeable implementation_)
    {
        return _deployUUPSProxy(
            admin,
            "CMTAT 721 Proxy",
            "C721P",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );
    }

    function _allowlist(address tokenAddress, address a1, address a2, address a3) internal {
        CMTAT721Standalone token_ = CMTAT721Standalone(tokenAddress);
        address[] memory addresses = new address[](3);
        bool[] memory values = new bool[](3);
        addresses[0] = a1;
        addresses[1] = a2;
        addresses[2] = a3;
        values[0] = true;
        values[1] = true;
        values[2] = true;
        token_.batchSetAddressAllowlist(addresses, values);
    }
}
