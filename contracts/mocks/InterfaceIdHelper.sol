// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IAllowlistModule} from "../../vendor/CMTAT/contracts/interfaces/modules/IAllowlistModule.sol";
import {IERC3643ComplianceRead} from "../../vendor/CMTAT/contracts/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "../../vendor/CMTAT/contracts/interfaces/tokenization/draft-IERC7551.sol";

/**
 * @title Interface ID Helper Mock
 * @notice Utility contract returning interface IDs used by tests.
 */
contract InterfaceIdHelper {
    /**
     * @notice Returns `IAllowlistModule` interface ID.
     */
    function allowlistId() external pure returns (bytes4) {
        return type(IAllowlistModule).interfaceId;
    }

    /**
     * @notice Returns `IERC3643ComplianceRead` interface ID.
     */
    function complianceReadId() external pure returns (bytes4) {
        return type(IERC3643ComplianceRead).interfaceId;
    }

    /**
     * @notice Returns `IERC7551Compliance` interface ID.
     */
    function complianceId() external pure returns (bytes4) {
        return type(IERC7551Compliance).interfaceId;
    }
}
