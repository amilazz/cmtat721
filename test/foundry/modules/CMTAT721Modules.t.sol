// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";
import {IERC1643} from "../../../vendor/CMTAT/contracts/interfaces/engine/IDocumentEngine.sol";
import {IERC1643CMTAT} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {ICMTATBase} from "../../../vendor/CMTAT/contracts/interfaces/tokenization/ICMTAT.sol";

import {ITokenIdEngine} from "../../../contracts/interfaces/ITokenIdEngine.sol";
import {CMTAT721Base} from "../../../contracts/modules/CMTAT721Base.sol";
import {DocumentEngineMock} from "../../../contracts/mocks/DocumentEngineMock.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract CMTAT721ModulesTest is CMTAT721TestUtils {
    function testRestrictedModuleOperations() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();

        vm.startPrank(address1);
        vm.expectRevert();
        token.pause();
        vm.expectRevert();
        token.deactivateContract();
        vm.expectRevert();
        token.setAddressFrozen(address1, true);
        vm.expectRevert();
        token.setAddressAllowlist(address1, true);
        vm.expectRevert();
        token.setDocumentEngine(IERC1643(address(0)));
        vm.expectRevert();
        token.setTokenId("X");
        vm.expectRevert();
        token.mint(address1, 1, EMPTY_BYTES);
        address[] memory oneAddress = new address[](1);
        uint256[] memory oneTokenId = new uint256[](1);
        oneAddress[0] = address1;
        oneTokenId[0] = 1;
        vm.expectRevert();
        token.batchMint(oneAddress, oneTokenId, EMPTY_BYTES);
        vm.expectRevert();
        token.burn(address1, 1, EMPTY_BYTES);
        vm.expectRevert();
        token.batchBurn(oneAddress, oneTokenId, EMPTY_BYTES);
        vm.expectRevert(CMTAT721Base.CMTAT_InvalidMintMode.selector);
        token.mintByUser(1, EMPTY_BYTES);
        vm.expectRevert();
        token.setRuleEngine(IRuleEngine(address(0)));
        vm.expectRevert();
        token.setTokenIdEngine(ITokenIdEngine(address(0)));
        vm.stopPrank();

        token.pause();
        token.unpause();

        token.setAddressFrozen(address1, true);
        assertTrue(token.isFrozen(address1));
        address[] memory frozenAddresses = new address[](1);
        bool[] memory frozenFlags = new bool[](1);
        frozenAddresses[0] = address1;
        frozenFlags[0] = false;
        token.batchSetAddressFrozen(frozenAddresses, frozenFlags);
        assertFalse(token.isFrozen(address1));

        token.setAddressAllowlist(address1, true);
        assertTrue(token.isAllowlisted(address1));
        address[] memory allowlistAddresses = new address[](1);
        bool[] memory allowlistFlags = new bool[](1);
        allowlistAddresses[0] = address1;
        allowlistFlags[0] = false;
        token.batchSetAddressAllowlist(allowlistAddresses, allowlistFlags);
        assertFalse(token.isAllowlisted(address1));

        token.setTokenId("NEW-ID");
        assertEq(token.tokenId(), "NEW-ID");

        token.setInformation("updated-info");
        assertEq(token.information(), "updated-info");

        token.setTerms(IERC1643CMTAT.DocumentInfo({
            name: "new-terms",
            uri: "ipfs://new-terms",
            documentHash: keccak256(bytes("new-terms"))
        }));
        ICMTATBase.CMTATTerms memory terms_ = token.terms();
        assertEq(terms_.name, "new-terms");

        DocumentEngineMock newDocumentEngine = new DocumentEngineMock();
        token.setDocumentEngine(IERC1643(address(newDocumentEngine)));
        assertEq(address(token.documentEngine()), address(newDocumentEngine));

        token.enableAllowlist(false);
        token.mint(admin, 99, EMPTY_BYTES);
        token.mint(address1, 100, EMPTY_BYTES);
        token.enableAllowlist(true);
        vm.expectRevert();
        token.mint(address1, 101, EMPTY_BYTES);

        token.pause();
        token.deactivateContract();
        assertTrue(token.deactivated());
        vm.expectRevert();
        token.unpause();
        vm.expectRevert();
        token.mint(admin, 102, EMPTY_BYTES);
    }

    function testAllowlistTransferValidation() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();

        vm.expectRevert();
        token.mint(address1, 1, EMPTY_BYTES);

        _allowlist(address(token), admin, address1, address2);
        token.mint(address1, 1, EMPTY_BYTES);

        assertTrue(token.canTransfer(address1, address2, 999));
        assertFalse(token.canTransfer(outsider, address2, 1));
        assertFalse(token.canTransfer(address1, outsider, 1));
        assertFalse(token.canTransferFrom(outsider, address1, address2, 1));

        token.enableAllowlist(false);
        assertTrue(token.canTransfer(outsider, address2, 1));
        token.mint(address2, 2, EMPTY_BYTES);
    }

    function testBatchMintAndBurn() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();
        _allowlist(address(token), admin, address1, address2);

        address[] memory mintAccounts = new address[](1);
        uint256[] memory mintTokenIds = new uint256[](2);
        mintAccounts[0] = address1;
        mintTokenIds[0] = 1;
        mintTokenIds[1] = 2;
        vm.expectRevert(CMTAT721Base.CMTAT_InvalidLength.selector);
        token.batchMint(mintAccounts, mintTokenIds, EMPTY_BYTES);

        address[] memory accounts = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        accounts[0] = address1;
        accounts[1] = address2;
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        token.batchMint(accounts, tokenIds, EMPTY_BYTES);
        assertEq(token.ownerOf(1), address1);
        assertEq(token.ownerOf(2), address2);

        address[] memory burnAccounts = new address[](1);
        burnAccounts[0] = address1;
        vm.expectRevert(CMTAT721Base.CMTAT_InvalidLength.selector);
        token.batchBurn(burnAccounts, tokenIds, EMPTY_BYTES);

        token.batchBurn(accounts, tokenIds, EMPTY_BYTES);
        vm.expectRevert();
        token.ownerOf(1);
        vm.expectRevert();
        token.ownerOf(2);
    }

    function testPauseAndFreezeRestrictions() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();
        _allowlist(address(token), admin, address1, address2);

        token.mint(address1, 1, EMPTY_BYTES);
        vm.expectRevert();
        token.burn(address2, 1, EMPTY_BYTES);

        vm.prank(address1);
        token.approve(address1, 1);

        token.pause();
        vm.prank(address1);
        vm.expectRevert();
        token.transferFrom(address1, address2, 1);
        token.unpause();

        vm.prank(address1);
        token.transferFrom(address1, address2, 1);
        assertEq(token.ownerOf(1), address2);

        token.setAddressFrozen(address2, true);
        vm.expectRevert();
        token.burn(address2, 1, EMPTY_BYTES);
        token.setAddressFrozen(address2, false);
        token.burn(address2, 1, EMPTY_BYTES);
    }
}
