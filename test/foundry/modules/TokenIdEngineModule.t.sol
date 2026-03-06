// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";

import {ITokenIdEngine} from "../../../contracts/interfaces/ITokenIdEngine.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../../../contracts/modules/CMTAT721Base.sol";
import {TokenIdEngineMock} from "../../../contracts/mocks/TokenIdEngineMock.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract TokenIdEngineModuleTest is CMTAT721TestUtils {
    function testSetTokenIdEngineAndFallback() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();
        TokenIdEngineMock tokenIdEngine = new TokenIdEngineMock(777);

        vm.prank(address1);
        vm.expectRevert();
        token.setTokenIdEngine(tokenIdEngine);

        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdEngineSet(admin, address(0), address(tokenIdEngine));
        token.setTokenIdEngine(tokenIdEngine);

        vm.expectRevert(CMTAT721Base.CMTAT_TokenIdEngine_SameValue.selector);
        token.setTokenIdEngine(tokenIdEngine);

        _allowlist(address(token), admin, address1, address2);
        token.mint(address1, 1, EMPTY_BYTES);
        assertEq(token.ownerOf(777), address1);
        vm.expectRevert();
        token.ownerOf(1);

        tokenIdEngine.setShouldRevert(true);
        vm.expectRevert(CMTAT721Base.CMTAT_TokenIdEngineUnavailable.selector);
        token.mint(address1, 2, EMPTY_BYTES);
        vm.prank(address1);
        vm.expectRevert();
        token.setTokenIdEngineDegradedMode(true);
        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdEngineDegradedModeSet(admin, true);
        token.setTokenIdEngineDegradedMode(true);
        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdFallbackUsed(admin, address1, 2, address(tokenIdEngine), true);
        token.mint(address1, 2, EMPTY_BYTES);
        assertEq(token.ownerOf(2), address1);

        tokenIdEngine.setShouldRevert(false);
        token.grantRole(token.MINTER_ROLE(), address(tokenIdEngine));

        tokenIdEngine.setTokenIdToReturn(1001);
        tokenIdEngine.configureReentrancy(address(token), address1, 1200, EMPTY_BYTES, 2);
        token.mint(address1, 3, EMPTY_BYTES);
        assertTrue(tokenIdEngine.reentrancyBlocked());
        assertEq(token.ownerOf(1001), address1);
        vm.expectRevert();
        token.ownerOf(1200);

        tokenIdEngine.setTokenIdToReturn(1002);
        tokenIdEngine.configureReentrancy(address(token), address1, 1300, EMPTY_BYTES, 3);
        address[] memory accounts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        accounts[0] = address1;
        tokenIds[0] = 4;
        token.batchMint(accounts, tokenIds, EMPTY_BYTES);
        assertTrue(tokenIdEngine.reentrancyBlocked());
        assertEq(token.ownerOf(1002), address1);
        vm.expectRevert();
        token.ownerOf(1300);
    }

    function testUserModeReentrancyBlock() external {
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721 UserManaged",
            "C721U",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.USER_INPUT
        );
        TokenIdEngineMock tokenIdEngine = new TokenIdEngineMock(888);

        _allowlist(address(token), admin, address1, address2);
        token.setTokenIdEngine(tokenIdEngine);

        tokenIdEngine.configureReentrancy(address(token), address1, 999, EMPTY_BYTES, 1);
        vm.prank(address1);
        token.mintByUser(7, EMPTY_BYTES);

        assertTrue(tokenIdEngine.reentrancyBlocked());
        assertEq(token.ownerOf(888), address1);
        vm.expectRevert();
        token.ownerOf(999);

        tokenIdEngine.setShouldRevert(true);
        vm.prank(address1);
        vm.expectRevert(CMTAT721Base.CMTAT_TokenIdEngineUnavailable.selector);
        token.mintByUser(11, EMPTY_BYTES);
        vm.prank(address1);
        vm.expectRevert();
        token.setTokenIdEngineDegradedMode(true);
        token.grantRole(token.TOKEN_ID_ENGINE_GUARDIAN_ROLE(), address3);
        vm.prank(address3);
        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdEngineDegradedModeSet(address3, true);
        token.setTokenIdEngineDegradedMode(true);
        vm.expectEmit(address(token));
        emit CMTAT721Base.TokenIdFallbackUsed(address1, address1, 11, address(tokenIdEngine), true);
        vm.prank(address1);
        token.mintByUser(11, EMPTY_BYTES);
        assertEq(token.ownerOf(11), address1);
    }
}
