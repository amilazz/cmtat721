// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ICMTATBase} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/ICMTAT.sol";
import {IERC1643} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC1643.sol";
import {IRuleEngine} from "../../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IAllowlistModule} from "../../../vendor/CMTAT/contracts/interfaces/modules/IAllowlistModule.sol";
import {IERC3643ComplianceRead} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC7551.sol";

import {ITokenIdEngine} from "../../../contracts/interfaces/ITokenIdEngine.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../../../contracts/modules/CMTAT721Base.sol";
import {DocumentEngineMock} from "../../../contracts/mocks/DocumentEngineMock.sol";
import {TokenIdEngineMock} from "../../../contracts/mocks/TokenIdEngineMock.sol";
import {CMTAT721InitHarness} from "../../../contracts/mocks/CMTAT721InitHarness.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract CMTAT721DeploymentTest is CMTAT721TestUtils {
    function testKeepCoreInformationAndDefaults() external {
        (CMTAT721Base token, DocumentEngineMock documentEngine) = _deployStandaloneDefault();

        assertEq(token.name(), "CMTAT 721");
        assertEq(token.symbol(), "C721");
        assertEq(token.version(), "3.1.0");
        assertEq(token.tokenId(), "CH0000NFT721");
        assertEq(token.information(), "CMTAT 721 compatible token");
        assertTrue(token.isAllowlistEnabled());
        assertEq(address(token.tokenIdEngine()), address(0));

        ICMTATBase.CMTATTerms memory terms_ = token.terms();
        assertEq(terms_.name, "terms");
        assertEq(terms_.doc.uri, "ipfs://terms");
        assertEq(terms_.doc.documentHash, keccak256(bytes("terms-hash")));
        assertGt(terms_.doc.lastModified, 0);

        documentEngine.setDocument("prospectus", "ipfs://prospectus", keccak256(bytes("doc-hash")));
        IERC1643.Document memory storedDoc = token.getDocument("prospectus");
        assertEq(storedDoc.uri, "ipfs://prospectus");
        assertEq(storedDoc.documentHash, keccak256(bytes("doc-hash")));
    }

    function testCannotReinitialize() external {
        (CMTAT721Base token, DocumentEngineMock documentEngine) = _deployStandaloneDefault();

        vm.expectRevert();
        token.initialize(
            admin,
            "x",
            "x",
            _extraInfo(),
            IERC1643(address(documentEngine)),
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );
    }

    function testSupportsInterfaces() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();

        assertTrue(token.supportsInterface(0x80ac58cd)); // IERC721
        assertTrue(token.supportsInterface(0x7965db0b)); // IAccessControl
        assertTrue(token.supportsInterface(type(IAllowlistModule).interfaceId));
        assertTrue(token.supportsInterface(type(IERC3643ComplianceRead).interfaceId));
        assertTrue(token.supportsInterface(type(IERC7551Compliance).interfaceId));
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function testDeployUserManagedMode() external {
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721 UserManaged",
            "C721U",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.USER_INPUT
        );

        _allowlist(address(token), admin, address1, address(0x1234));

        vm.expectRevert(CMTAT721Base.CMTAT_InvalidMintMode.selector);
        token.mint(address1, 1, EMPTY_BYTES);

        address[] memory singleAccount = new address[](1);
        uint256[] memory singleTokenId = new uint256[](1);
        singleAccount[0] = address1;
        singleTokenId[0] = 1;
        vm.expectRevert(CMTAT721Base.CMTAT_InvalidMintMode.selector);
        token.batchMint(singleAccount, singleTokenId, EMPTY_BYTES);

        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdFallbackUsed(address1, address1, 1, address(0), false);
        vm.prank(address1);
        token.mintByUser(1, EMPTY_BYTES);
        assertEq(token.ownerOf(1), address1);
        assertEq(uint8(token.tokenIdManagementMode()), uint8(TokenIdManagementMode.USER_INPUT));
    }

    function testInitializeTokenIdEngineAtDeployment() external {
        TokenIdEngineMock tokenIdEngine = new TokenIdEngineMock(5000);
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721",
            "C721",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(tokenIdEngine)),
            TokenIdManagementMode.MINTER_INPUT
        );

        assertEq(address(token.tokenIdEngine()), address(tokenIdEngine));

        _allowlist(address(token), admin, address1, address(0x1234));
        token.mint(address1, 1, EMPTY_BYTES);
        assertEq(token.ownerOf(5000), address1);
    }

    function testBaseURIAndTokenURI() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();

        _allowlist(address(token), admin, address1, address(0x1234));
        token.mint(address1, 1, EMPTY_BYTES);

        assertEq(token.baseURI(), "");
        assertEq(token.tokenURI(1), "");

        vm.prank(address1);
        vm.expectRevert();
        token.setBaseURI("ipfs://meta/");

        token.setBaseURI("ipfs://meta/");

        vm.expectRevert(CMTAT721Base.CMTAT_BaseURI_SameValue.selector);
        token.setBaseURI("ipfs://meta/");

        assertEq(token.baseURI(), "ipfs://meta/");
        assertEq(token.tokenURI(1), "ipfs://meta/1");
    }

    function testCMTATStyleInitFlowEntryPoints() external {
        CMTAT721InitHarness harness = new CMTAT721InitHarness();

        vm.expectRevert();
        harness.callInitializeInternal(
            admin,
            "X",
            "X",
            _extraInfo(),
            IERC1643(address(0)),
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );

        vm.expectRevert();
        harness.callCMTAT721Init(
            admin,
            "X",
            "X",
            _extraInfo(),
            IERC1643(address(0)),
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );

        vm.expectRevert();
        harness.callCMTAT721InternalInit(
            IRuleEngine(address(0)), ITokenIdEngine(address(0)), TokenIdManagementMode.MINTER_INPUT
        );

        vm.expectRevert();
        harness.callCMTAT721ModulesInit();

        vm.expectRevert();
        harness.callTokenIdEngineInit(ITokenIdEngine(address(0)));
    }
}
