// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "../../../vendor/CMTAT/contracts/interfaces/engine/IRuleEngine.sol";

import {ITokenIdEngine} from "../../../contracts/interfaces/ITokenIdEngine.sol";
import {CMTAT721Base, TokenIdManagementMode} from "../../../contracts/modules/CMTAT721Base.sol";
import {RuleEngine721Mock} from "../../../contracts/mocks/RuleEngine721Mock.sol";
import {TokenIdEngineMock} from "../../../contracts/mocks/TokenIdEngineMock.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract CMTAT721FuzzTest is CMTAT721TestUtils {
    function testFuzz_MinterCanMintArbitraryTokenIds(uint256 tokenId, address recipient) external {
        vm.assume(recipient != address(0));
        (CMTAT721Base token,) = _deployStandaloneDefault();

        address[] memory recipients = new address[](2);
        bool[] memory allowlisted = new bool[](2);
        recipients[0] = admin;
        recipients[1] = recipient;
        allowlisted[0] = true;
        allowlisted[1] = true;
        token.batchSetAddressAllowlist(recipients, allowlisted);

        token.mint(recipient, tokenId, EMPTY_BYTES);
        assertEq(token.ownerOf(tokenId), recipient);
    }

    function testFuzz_UserModeMintByUserRespectsCaller(uint256 tokenId, address user) external {
        vm.assume(user != address(0));
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721 UserManaged",
            "C721U",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.USER_INPUT
        );

        address[] memory recipients = new address[](2);
        bool[] memory allowlisted = new bool[](2);
        recipients[0] = admin;
        recipients[1] = user;
        allowlisted[0] = true;
        allowlisted[1] = true;
        token.batchSetAddressAllowlist(recipients, allowlisted);

        vm.prank(user);
        token.mintByUser(tokenId, EMPTY_BYTES);
        assertEq(token.ownerOf(tokenId), user);
    }

    function testFuzz_FallbackTokenIdWhenEngineUnavailable(uint256 fallbackTokenId, address recipient) external {
        vm.assume(recipient != address(0));
        TokenIdEngineMock tokenIdEngine = new TokenIdEngineMock(12345);
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721",
            "C721",
            IRuleEngine(address(0)),
            ITokenIdEngine(address(tokenIdEngine)),
            TokenIdManagementMode.MINTER_INPUT
        );

        address[] memory recipients = new address[](2);
        bool[] memory allowlisted = new bool[](2);
        recipients[0] = admin;
        recipients[1] = recipient;
        allowlisted[0] = true;
        allowlisted[1] = true;
        token.batchSetAddressAllowlist(recipients, allowlisted);

        tokenIdEngine.setShouldRevert(true);
        token.mint(recipient, fallbackTokenId, EMPTY_BYTES);
        assertEq(token.ownerOf(fallbackTokenId), recipient);
    }

    function testFuzz_TransferRoundTripWithRuleEngine(uint256 tokenId, address from, address to) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);

        RuleEngine721Mock ruleEngine = new RuleEngine721Mock();
        (CMTAT721Base token,) = _deployStandalone(
            admin,
            "CMTAT 721",
            "C721",
            IRuleEngine(address(ruleEngine)),
            ITokenIdEngine(address(0)),
            TokenIdManagementMode.MINTER_INPUT
        );

        address[] memory recipients = new address[](3);
        bool[] memory allowlisted = new bool[](3);
        recipients[0] = admin;
        recipients[1] = from;
        recipients[2] = to;
        allowlisted[0] = true;
        allowlisted[1] = true;
        allowlisted[2] = true;
        token.batchSetAddressAllowlist(recipients, allowlisted);

        token.mint(from, tokenId, EMPTY_BYTES);
        vm.prank(from);
        token.transferFrom(from, to, tokenId);
        assertEq(token.ownerOf(tokenId), to);
        assertEq(ruleEngine.transferredWithSpenderCount(), 1);
    }
}
