// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";

// TODO: Rename to VotingEscrowCheckpointsLib
// library EscrowDelegateCheckpointsLib {

/**
 * @title CheckPointSystem
 * @dev This contract is used to manage checkpoints in the system.
 */
library CheckpointSystemLib {
    using Checkpoints for Checkpoints.Trace;
    using Checkpoints for Checkpoints.TraceAddress;
    using SafeCastLibrary for int128;
    using SafeCastLibrary for uint256;

    /// @notice Maximum time for a checkpoint
    int128 public constant MAX_TIME = 2 * 365 * 86400;
    /// @notice Precision of calculations
    // TODO: This is unused - Revisit need and eventually remove
    int128 public constant PRECISION = 1;
    /// @notice Unit of time for the clock
    uint48 public constant CLOCK_UNIT = 7 days;

    struct CheckpointSystemStorage {
        /// @notice Global checkpoints
        Checkpoints.Trace _globalCheckpoints;
        /// @notice Mapping of global slope changes
        /// @dev Intended to be exposed with a getter
        mapping(uint256 timestamp => int128 slopeChange) globalSlopeChanges;
        /// @notice escrow lock checkpoints
        mapping(uint256 escrowId => Checkpoints.Trace) _lockCheckpoints;
        /// @notice Delegate checkpoints
        mapping(address delegatee => Checkpoints.Trace) _delegateCheckpoints;
        /// @notice escrow lock to delegatee mapping
        mapping(uint256 escrowId => Checkpoints.TraceAddress) _escrowDelegateeAddress;
        /// @notice Delegatee slope changes
        /// @dev Intended to be exposed with a getter
        mapping(address delegatee => mapping(uint256 timestamp => int128 slopeChange)) delegateeSlopeChanges;
    }

    /**
     * @notice Clock used for flagging checkpoints.
     * @return Current timestamp
     */
    function clock() public view returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @notice Clock used for flagging global checkpoints.
     * @return Current timestamp rounded to the nearest clock unit
     */
    function globalClock() public view returns (uint48) {
        return toGlobalClock(Time.timestamp());
    }

    /**
     * @notice Converts a timestamp to a global clock value.
     * @param _timestamp The timestamp to convert
     * @return The converted global clock value
     */
    function toGlobalClock(uint256 _timestamp) internal pure returns (uint48) {
        return uint48((_timestamp / CLOCK_UNIT) * CLOCK_UNIT);
    }

    /**
     * @dev Record global and per-escrow data to checkpoints. Used by VotingEscrow system.
     * @param storage_ The CheckpointSystemStorage struct containing all the storage mappings.
     * @param _escrowId NFT escrow lock ID. No escrow checkpoint if 0
     * @param uOldAmount Locked amount from last checkpoint
     * @param uNewAmount Locked amount from current checkpoint
     * @param uOldEndTime Last checkpoint time
     * @param uNewEndTime Current checkpoint time
     */
    function checkpoint(
        CheckpointSystemStorage storage storage_,
        uint256 _escrowId,
        int128 uOldAmount,
        int128 uNewAmount,
        uint256 uOldEndTime,
        uint256 uNewEndTime
    ) external {
        int128 oldDslope = 0;
        int128 newDslope = 0;
        Checkpoints.Point memory uOldPoint = Checkpoints.blankPoint();
        Checkpoints.Point memory uNewPoint = Checkpoints.blankPoint();
        /// @notice if this is not rounded to CLOCK_UNIT
        /// the system will not be able to go too long without checkpoints
        uNewEndTime = toGlobalClock(uNewEndTime);
        if (_escrowId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            uNewPoint.permanent = uNewEndTime == 0 ? uNewAmount : int128(0);
            uOldPoint.permanent = uOldEndTime == 0 ? uOldAmount : int128(0);
            if (uOldEndTime > block.timestamp && uOldAmount > 0) {
                /// @dev  Calculate the slope based on the older checkpoint amount
                uOldPoint.slope = (uOldAmount * PRECISION) / MAX_TIME;
                uOldPoint.bias = (uOldPoint.slope * (uOldEndTime - block.timestamp).toInt128()) / PRECISION;
            }
            if (uNewEndTime > block.timestamp && uNewAmount > 0) {
                uNewPoint.slope = (uNewAmount * PRECISION) / MAX_TIME;
                uNewPoint.bias = (uNewPoint.slope * (uNewEndTime - block.timestamp).toInt128()) / PRECISION;
            }
            oldDslope = storage_.globalSlopeChanges[uOldEndTime];
            if (uNewEndTime != 0) {
                if (uNewEndTime == uOldEndTime) {
                    newDslope = oldDslope;
                } else {
                    newDslope = storage_.globalSlopeChanges[uNewEndTime];
                }
            }

            // Schedule the slope changes (slope is going down)
            // We subtract new escrow slope from [_newLocked.endTime]
            // and add old_escrow_slope to [_oldLocked.end]
            if (uOldEndTime > block.timestamp) {
                // oldDslope was <something> - uOld.slope, so we cancel that
                oldDslope += uOldPoint.slope;
                if (uOldEndTime == uNewEndTime) {
                    oldDslope -= uNewPoint.slope; // It was a new deposit, not extension
                }
                storage_.globalSlopeChanges[uOldEndTime] = oldDslope;
            }

            if (uNewEndTime > block.timestamp) {
                // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
                if ((uNewEndTime > uOldEndTime)) {
                    newDslope -= uNewPoint.slope; // old slope disappeared at this point
                    storage_.globalSlopeChanges[uNewEndTime] = newDslope;
                    // console.log("Pushed slope: %s to change: %s", uNewEndTime);
                    // console.logInt(newDslope);
                }
                // else: we recorded it already in oldDslope
            }

            escrowCheckpoint(storage_, _escrowId, uNewPoint);

            (, uint48 delegateTs, address delegateeAddress) = storage_
                ._escrowDelegateeAddress[_escrowId]
                .latestCheckpoint();

            if (delegateTs != 0) {
                /// @notice this can likely be handled more efficiently
                checkpointDelegatee(storage_, delegateeAddress, uOldPoint, uOldEndTime, false);
                checkpointDelegatee(storage_, delegateeAddress, uNewPoint, uNewEndTime, true);
            }
        }
        /// @dev If escrowId is 0,  this  will still create a global checkpoint
        globalCheckpoint(storage_, _escrowId, uOldPoint, uNewPoint);
    }

    /**
     * @dev Internal function to update escrow checkpoint with new point
     * @param _escrowId The ID of the escrow lock
     * @param uNewPoint The new point to be updated
     */
    function escrowCheckpoint(
        CheckpointSystemStorage storage storage_,
        uint256 _escrowId,
        Checkpoints.Point memory uNewPoint
    ) public {
        _pushStruct(storage_._lockCheckpoints[_escrowId], uNewPoint);
    }

    /**
     * @dev Internal function to update global checkpoint
     */
    function globalCheckpoint(CheckpointSystemStorage storage storage_) internal {
        globalCheckpoint(storage_, 0, Checkpoints.blankPoint(), Checkpoints.blankPoint());
    }

    /**
     * @dev Internal function to update global checkpoint with new points
     * @param _escrowId The ID of the escrow lock
     * @param uOldPoint The old point to be updated
     * @param uNewPoint The new point to be updated
     */
    function globalCheckpoint(
        CheckpointSystemStorage storage storage_,
        uint256 _escrowId,
        Checkpoints.Point memory uOldPoint,
        Checkpoints.Point memory uNewPoint
    ) public {
        (, uint48 lastPoint, Checkpoints.Point memory lastGlobal) = storage_._globalCheckpoints.latestCheckpoint();
        uint48 lastCheckpoint = lastPoint != 0 ? lastPoint : uint48(block.timestamp);

        {
            // Go over weeks to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint); /// @dev  lastCheckpoint > tesTime
            uint256 maxTime = testTime + MAX_TIME.toUint256();

            while (testTime != block.timestamp) {
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = block.timestamp.toUint48();
                } else {
                    dSlope = storage_.globalSlopeChanges[testTime];
                }
                if (dSlope != 0) {
                    lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastCheckpoint).toInt128()) / PRECISION);
                    lastGlobal.slope += dSlope;
                    lastCheckpoint = testTime;
                    storage_._globalCheckpoints.push(lastCheckpoint, lastGlobal);
                }
                if (testTime > maxTime) break;
            }
        }

        if (_escrowId != 0) {
            lastGlobal.bias =
                lastGlobal.bias -
                ((lastGlobal.slope * (block.timestamp - lastCheckpoint).toInt128()) / PRECISION);

            lastGlobal.slope += uNewPoint.slope - uOldPoint.slope;
            lastGlobal.bias += uNewPoint.bias - uOldPoint.bias;
            lastGlobal.permanent += uNewPoint.permanent - uOldPoint.permanent;
        } else {
            // Initial value of testTime is always larger than the ts of the last point
            uint256 testTime = block.timestamp;
            lastGlobal.bias -= (lastGlobal.slope * (testTime - lastCheckpoint).toInt128()) / PRECISION;
        }

        _pushStruct(storage_._globalCheckpoints, lastGlobal);
    }

    /**
     * @dev Internal function to calculate total voting power at some point in the past
     * @param _delegateeAddress The address of the delegatee
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function getAdjustedVotes(
        CheckpointSystemStorage storage storage_,
        address _delegateeAddress,
        uint48 _timestamp
    ) external view returns (uint256) {
        Checkpoints.Point memory lastPoint = getAdjustedVotesCheckpoint(storage_, _delegateeAddress, _timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /**
     * @dev Internal function to get delegated votes checkpoint at some point in the past
     * @param _delegateeAddress The address of the delegatee
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function getAdjustedVotesCheckpoint(
        CheckpointSystemStorage storage storage_,
        address _delegateeAddress,
        uint48 _timestamp
    ) public view returns (Checkpoints.Point memory) {
        (bool exists, uint48 lastCheckpointTs, Checkpoints.Point memory lastPoint) = storage_
            ._delegateCheckpoints[_delegateeAddress]
            .upperLookupRecent(_timestamp);
        if (!exists) return lastPoint;
        uint48 testTime = toGlobalClock(lastCheckpointTs); /// @dev  lastCheckpointTs > tesTime
        uint256 maxTime = testTime + MAX_TIME.toUint256();
        while (testTime != _timestamp) {
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = storage_.delegateeSlopeChanges[_delegateeAddress][testTime];
            }
            if (dSlope != 0) {
                lastPoint.bias -= ((lastPoint.slope * uint256(testTime - lastCheckpointTs).toInt128()) / PRECISION);
                lastPoint.slope += dSlope;
                lastCheckpointTs = uint48(testTime);
            }
            if (testTime > maxTime) break;
        }
        int128 change = (lastPoint.slope * uint256(_timestamp - lastCheckpointTs).toInt128()) / PRECISION;
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;

        return lastPoint;
    }

    /**
     * @notice Public function to get the delegatee of an escrow lock
     * @param escrowId The ID of the escrow
     * @return The address of the delegate
     */
    // TODO: Create a delegates function which uses this in VotingEscrow
    function getEscrowDelegatee(
        CheckpointSystemStorage storage storage_,
        uint256 escrowId
    ) external view returns (address) {
        return getEscrowDelegateeAtTime(storage_, escrowId, block.timestamp.toUint48());
    }

    /**
     * @notice Public function to get the delegatee of an escrow lock
     * @param escrowId The ID of the escrow lock
     * @param timestamp The timestamp to get the delegate at
     * @return The address of the delegate
     */
    function getEscrowDelegateeAtTime(
        CheckpointSystemStorage storage storage_,
        uint256 escrowId,
        uint48 timestamp
    ) public view returns (address) {
        return storage_._escrowDelegateeAddress[escrowId].upperLookupRecent(timestamp);
    }

    /**
     * @dev Internal function to record escrow delegation checkpoints. Used by voting system.
     * @param escrowId The ID of the escrow lock
     * @param delegatee The address of the delegatee
     * @param endTime The end time of the delegation
     */
    function delegate(
        CheckpointSystemStorage storage storage_,
        uint256 escrowId,
        address delegatee,
        uint256 endTime
    ) external {
        address currentDelegate = storage_._escrowDelegateeAddress[escrowId].latest();
        if (currentDelegate == delegatee) return;

        checkpointDelegator(storage_, escrowId, delegatee, endTime);
        // TODO: commented event
        // emit DelegateChanged(_msgSender(), currentDelegate, delegatee);
    }

    /**
     * @dev Internal function used by `_delegate`
     *      to update delegator voting checkpoints.
     *      Automatically delegates, then updates checkpoint.
     * @param escrowId The ID of the escrow lock lock
     * @param delegatee The new delegatee for the escrowId.
     * @param endTime The end time of the delegation
     */
    function checkpointDelegator(
        CheckpointSystemStorage storage storage_,
        uint256 escrowId,
        address delegatee,
        uint256 endTime
    ) public {
        (, uint48 ts, Checkpoints.Point memory lastPoint) = storage_._lockCheckpoints[escrowId].latestCheckpoint();
        lastPoint.bias -= ((lastPoint.slope * (block.timestamp - ts).toInt128()) / PRECISION);
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        // Dedelegate from delegatee if delegated
        address oldDelegatee = storage_._escrowDelegateeAddress[escrowId].latest();
        if (oldDelegatee != delegatee && oldDelegatee != address(0))
            checkpointDelegatee(storage_, oldDelegatee, lastPoint, endTime, false);
        // Delegate to new delegator
        if (endTime > block.timestamp) checkpointDelegatee(storage_, delegatee, lastPoint, endTime, true);
        _pushAddress(storage_._escrowDelegateeAddress[escrowId], delegatee);
    }

    /**
     * @dev Internal function to update delegatee's `delegatedBalance` by `balance`.
     *      Only updates if delegating to a new delegatee.
     * @param delegateeAddress The address of the delegatee
     * @param escrowPoint The point of the escrow
     * @param endTime The end time of the delegation
     * @param _increase Whether to increase or decrease the balance
     */
    function checkpointDelegatee(
        CheckpointSystemStorage storage storage_,
        address delegateeAddress,
        Checkpoints.Point memory escrowPoint,
        uint256 endTime,
        bool _increase
    ) public {
        (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) = baseCheckpointDelegatee(
            storage_,
            delegateeAddress
        );

        int128 baseBias = lastPoint.bias -
            (lastPoint.slope * (block.timestamp - lastCheckpoint).toInt128()) /
            PRECISION;

        if (!_increase) {
            storage_.delegateeSlopeChanges[delegateeAddress][endTime] += escrowPoint.slope;
            lastPoint.bias = escrowPoint.bias < baseBias ? baseBias - escrowPoint.bias : int128(0);
            lastPoint.slope = escrowPoint.slope < lastPoint.slope ? lastPoint.slope - escrowPoint.slope : int128(0);
            lastPoint.permanent = escrowPoint.permanent < lastPoint.permanent
                ? lastPoint.permanent - escrowPoint.permanent
                : int128(0);
        } else {
            storage_.delegateeSlopeChanges[delegateeAddress][endTime] -= escrowPoint.slope;
            lastPoint.bias = baseBias + escrowPoint.bias;
            lastPoint.slope = lastPoint.slope + escrowPoint.slope;
            lastPoint.permanent = lastPoint.permanent + escrowPoint.permanent;
        }
        /// @dev bias can be rounded up by lack of precision. If slope is 0 we are out
        // if (lastPoint.slope == 0) lastPoint.bias = 0;
        _pushStruct(storage_._delegateCheckpoints[delegateeAddress], lastPoint);
    }

    /**
     * @dev Internal function to update delegatee's checkpoint
     * @param delegateeAddress The address of the delegatee
     * @return lastPoint The last point of the delegatee
     * @return lastCheckpoint The last checkpoint time of the delegatee
     */
    function baseCheckpointDelegatee(
        CheckpointSystemStorage storage storage_,
        address delegateeAddress
    ) public returns (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) {
        (bool exists, uint48 ts, Checkpoints.Point memory point) = storage_
            ._delegateCheckpoints[delegateeAddress]
            .latestCheckpoint();
        lastPoint = point;
        lastCheckpoint = ts;
        if (exists) {
            // Go over days to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint); /// @dev  lastCheckpoint > tesTime

            uint256 maxTime = testTime + MAX_TIME.toUint256();

            // Iterate over time until current block timestamp or maxtime
            while (testTime != block.timestamp) {
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = uint48(block.timestamp);
                } else {
                    dSlope = storage_.delegateeSlopeChanges[delegateeAddress][testTime];
                }
                if (dSlope != 0) {
                    lastPoint.bias -= ((lastPoint.slope * uint256(testTime - lastCheckpoint).toInt128()) / PRECISION);
                    lastPoint.slope += dSlope;
                    lastCheckpoint = uint48(testTime);
                    storage_._delegateCheckpoints[delegateeAddress].push(lastCheckpoint, lastPoint);
                }
                if (testTime > maxTime) break;
            }
        }
    }

    /**
     * @dev Internal function to calculate total voting power at some point in the past
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function getAdjustedGlobalVotes(
        CheckpointSystemStorage storage storage_,
        uint48 _timestamp
    ) external view returns (uint256) {
        Checkpoints.Point memory lastPoint = getAdjustedCheckpoint(storage_, _timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /**
     * @dev Internal function to get latest checkpoint of some point in the past
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function getAdjustedCheckpoint(
        CheckpointSystemStorage storage storage_,
        uint48 _timestamp
    ) public view returns (Checkpoints.Point memory) {
        uint48 clockTime = _timestamp;
        (bool exists, uint48 lastCheckpointTs, Checkpoints.Point memory lastGlobal) = storage_
            ._globalCheckpoints
            .upperLookupRecent(clockTime);
        if (!exists) return lastGlobal;
        uint48 testTime = toGlobalClock(lastCheckpointTs); /// @dev  lastCheckpointTs > tesTime
        uint256 maxTime = testTime + MAX_TIME.toUint256();

        // Iterate over time until the specified timestamp or maxtime is reached
        while (testTime != _timestamp) {
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = storage_.globalSlopeChanges[testTime];
            }
            if (dSlope != 0) {
                lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastCheckpointTs).toInt128()) / PRECISION);
                lastGlobal.slope += dSlope;
                lastCheckpointTs = uint48(testTime);
            }
            if (testTime > maxTime) break;
        }

        int128 change = (lastGlobal.slope * uint256(clockTime - lastCheckpointTs).toInt128()) / PRECISION;
        lastGlobal.bias = lastGlobal.bias < change ? int128(0) : lastGlobal.bias - change;

        return lastGlobal;
    }

    /**
     * @notice Get the current bias for `_escrowId` at `_timestamp`
     * @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
     * @dev Fetches last escrow point prior to a certain timestamp, then walks forward to timestamp.
     * @param _escrowId NFT for lock
     * @param _timestamp Epoch time to return bias power at
     * @return NFT bias
     */
    function getAdjustedNftBias(
        CheckpointSystemStorage storage storage_,
        uint256 _escrowId,
        uint256 _timestamp
    ) external view returns (uint256) {
        uint48 clockTime = _timestamp.toUint48();
        (bool exists, uint48 ts, Checkpoints.Point memory lastPoint) = storage_
            ._lockCheckpoints[_escrowId]
            .upperLookupRecent(clockTime);
        if (!exists) return 0;
        if (lastPoint.permanent != 0) return lastPoint.permanent.toUint256();
        int128 change = (((lastPoint.slope * uint256(clockTime - ts).toInt128()) / PRECISION));
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;
        return lastPoint.bias.toUint256();
    }

    /// -----------------------------------------------------------------------
    /// Private functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Internal function to push an address to the checkpoint
     * @param store The storage to push the address to
     * @param value The address to be pushed
     * @return The old and new address
     */
    function _pushAddress(Checkpoints.TraceAddress storage store, address value) private returns (address, address) {
        return store.push(clock(), value);
    }

    /**
     * @dev Internal function to push a struct to the checkpoint
     * @param store The storage to push the struct to
     * @param value The struct to be pushed
     * @return The old and new struct
     */
    function _pushStruct(
        Checkpoints.Trace storage store,
        Checkpoints.Point memory value
    ) private returns (Checkpoints.Point memory, Checkpoints.Point memory) {
        return store.push(clock(), value);
    }
}
