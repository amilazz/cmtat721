// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTAT721Base} from "../../../contracts/modules/CMTAT721Base.sol";
import {RuleEngine721Mock} from "../../../contracts/mocks/RuleEngine721Mock.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract RuleEngineModuleTest is CMTAT721TestUtils {
    function testRuleEngineValidationAndCallbacks() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();
        RuleEngine721Mock ruleEngine = new RuleEngine721Mock();

        _allowlist(address(token), admin, address1, address2);

        token.setRuleEngine(ruleEngine);
        vm.expectRevert(CMTAT721Base.CMTAT_ValidationModule_SameValue.selector);
        token.setRuleEngine(ruleEngine);

        token.mint(address1, 1, EMPTY_BYTES);
        assertEq(ruleEngine.transferredNoSpenderCount(), 1);

        assertTrue(token.canTransfer(address1, address2, 17));
        ruleEngine.setTransfersAllowed(false);
        assertFalse(token.canTransfer(address1, address2, 17));
        vm.expectRevert();
        token.mint(address2, 2, EMPTY_BYTES);

        ruleEngine.setTransfersAllowed(true);
        token.mint(address2, 2, EMPTY_BYTES);

        ruleEngine.setTransferFromAllowed(false);
        vm.prank(address1);
        vm.expectRevert();
        token.transferFrom(address1, address2, 1);

        ruleEngine.setTransferFromAllowed(true);
        vm.prank(address1);
        token.transferFrom(address1, address2, 1);
        assertEq(ruleEngine.transferredWithSpenderCount(), 1);

        vm.prank(address2);
        token.safeTransferFrom(address2, address1, 1, EMPTY_BYTES);
        assertEq(ruleEngine.transferredWithSpenderCount(), 2);
        assertEq(token.ownerOf(1), address1);
    }

    function testForcedTransferWithRuleEngine() external {
        (CMTAT721Base token,) = _deployStandaloneDefault();
        RuleEngine721Mock ruleEngine = new RuleEngine721Mock();

        _allowlist(address(token), admin, address1, address2);
        token.setRuleEngine(ruleEngine);
        token.mint(address1, 1, EMPTY_BYTES);

        token.pause();
        token.setAddressFrozen(address1, true);

        vm.prank(outsider);
        vm.expectRevert();
        token.forcedTransfer(address1, address2, 1, EMPTY_BYTES);

        token.forcedTransfer(address1, address2, 1, EMPTY_BYTES);
        assertEq(token.ownerOf(1), address2);
        assertEq(ruleEngine.transferredWithSpenderCount(), 1);
    }
}
