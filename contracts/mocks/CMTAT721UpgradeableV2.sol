// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {CMTAT721Upgradeable} from "../deployment/CMTAT721Upgradeable.sol";

/**
 * @title CMTAT721 Upgradeable V2 Mock
 * @notice Minimal upgraded implementation used in UUPS upgrade tests.
 */
contract CMTAT721UpgradeableV2 is CMTAT721Upgradeable {
    /**
     * @notice Returns a fixed marker used to confirm upgrade success.
     * @return versionMarker Constant `"2"` string.
     */
    function mockVersion2() external pure returns (string memory) {
        return "2";
    }
}
