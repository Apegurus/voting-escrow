// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {CheckpointSystemLib} from "./CheckpointSystem.sol";

/**
 * @title CheckpointSystemStorage
 * @dev This contract serves as the storage for checkpoints in the system.
 */
contract CheckpointSystemStorage {
    using CheckpointSystemLib for CheckpointSystemLib.CheckpointSystemStorage;

    /// @notice Storage struct for the checkpoint system
    CheckpointSystemLib.CheckpointSystemStorage internal csStorage;

    uint256 MAX_TIME = uint256(uint128(CheckpointSystemLib.MAX_TIME));

    /// @notice Gap for future upgrades
    uint256[50] private __gap;

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function globalSlopeChanges(uint256 _timestamp) external view returns (int128) {
        return csStorage.globalSlopeChanges[_timestamp];
    }

    function delegateeSlopeChanges(address _delegatee, uint256 _timestamp) external view returns (int128) {
        return csStorage.delegateeSlopeChanges[_delegatee][_timestamp];
    }

    /// -----------------------------------------------------------------------
    ///
    /// -----------------------------------------------------------------------

    function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48) {
        return CheckpointSystemLib.toGlobalClock(_timestamp);
    }
}
