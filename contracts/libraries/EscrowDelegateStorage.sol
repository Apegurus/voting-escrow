// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {EscrowDelegateCheckpoints} from "./EscrowDelegateCheckpoints.sol";

/**
 * @title EscrowDelegateStorage
 * @dev This contract serves as the storage for checkpoints in the system.
 */
contract EscrowDelegateStorage {
    using EscrowDelegateCheckpoints for EscrowDelegateCheckpoints.EscrowDelegateStore;

    /// @notice Storage struct for the checkpoint system
    EscrowDelegateCheckpoints.EscrowDelegateStore internal edStore;

    uint256 MAX_TIME = uint256(uint128(EscrowDelegateCheckpoints.MAX_TIME));

    /// @notice Gap for future upgrades
    uint256[50] private __gap;

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function globalSlopeChanges(uint256 _timestamp) external view returns (int128) {
        return edStore.globalSlopeChanges[_timestamp];
    }

    function delegateeSlopeChanges(address _delegatee, uint256 _timestamp) external view returns (int128) {
        return edStore.delegateeSlopeChanges[_delegatee][_timestamp];
    }

    /// -----------------------------------------------------------------------
    ///
    /// -----------------------------------------------------------------------

    function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48) {
        return EscrowDelegateCheckpoints.toGlobalClock(_timestamp);
    }
}
