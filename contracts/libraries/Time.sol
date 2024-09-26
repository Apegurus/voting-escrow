// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCastLibrary} from "./SafeCastLibrary.sol";

/**
 * @notice Adapted from OpenZeppelin's Time library: v5.0.0 for solc 0.8.19
 * @dev This library provides helpers for manipulating time-related objects.
 *
 * It uses the following types:
 * - `uint48` for timepoints
 * - `uint32` for durations
 *
 * While the library doesn't provide specific types for timepoints and duration, it does provide:
 * - a `Delay` type to represent duration that can be programmed to change value automatically at a given point
 * - additional helper functions
 */
library Time {
    using Time for *;

    /**
     * @dev Get the block timestamp as a Timepoint.
     */
    function timestamp() internal view returns (uint48) {
        return SafeCastLibrary.toUint48(block.timestamp);
    }

    /**
     * @dev Get the block number as a Timepoint.
     */
    function blockNumber() internal view returns (uint48) {
        return SafeCastLibrary.toUint48(block.number);
    }
}
