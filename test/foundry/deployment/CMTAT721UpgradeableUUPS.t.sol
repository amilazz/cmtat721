// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTAT721Upgradeable} from "../../../contracts/deployment/CMTAT721Upgradeable.sol";
import {TokenIdManagementMode} from "../../../contracts/modules/CMTAT721Base.sol";
import {CMTAT721UpgradeableV2} from "../../../contracts/mocks/CMTAT721UpgradeableV2.sol";

import {CMTAT721TestUtils} from "../utils/CMTAT721TestUtils.sol";

contract CMTAT721UpgradeableUUPSTest is CMTAT721TestUtils {
    function testDeployUUPSProxyAndMint() external {
        (CMTAT721Upgradeable token,,) = _deployUUPSDefault();

        _allowlist(address(token), admin, address1, address(0x1234));
        token.mint(address1, 1, EMPTY_BYTES);

        assertEq(token.ownerOf(1), address1);
        assertEq(token.version(), "3.1.0");
        assertEq(token.name(), "CMTAT 721 Proxy");
        assertEq(uint8(token.tokenIdManagementMode()), uint8(TokenIdManagementMode.MINTER_INPUT));
    }

    function testUUPSUpgradeAccessControl() external {
        (CMTAT721Upgradeable token,,) = _deployUUPSDefault();
        CMTAT721UpgradeableV2 implementationV2 = new CMTAT721UpgradeableV2();

        vm.prank(address1);
        vm.expectRevert();
        token.upgradeToAndCall(address(implementationV2), "");

        token.upgradeToAndCall(address(implementationV2), "");
        CMTAT721UpgradeableV2 upgraded = CMTAT721UpgradeableV2(address(token));
        assertEq(upgraded.mockVersion2(), "2");
    }
}
