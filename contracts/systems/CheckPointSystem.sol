// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";
import "hardhat/console.sol";

/**
 * @title CheckPointSystem
 * @dev This contract is used to manage checkpoints in the system.
 */
contract CheckPointSystem is ReentrancyGuard, IERC6372 {
    using Checkpoints for Checkpoints.Trace;
    using Checkpoints for Checkpoints.TraceAddress;
    using SafeCastLibrary for int128;
    using SafeCastLibrary for uint256;

    /// @notice Maximum time for a checkpoint
    int128 public constant MAXTIME = 2 * 365 * 86400;
    /// @notice Precision of calculations
    // TODO: This is unused - Revisit need and eventually remove
    int128 public constant _PRECISSION = 1;
    /// @notice Unit of time for the clock
    uint48 public constant CLOCK_UNIT = 7 days;

    /*//////////////////////////////////////////////////////////////
                             CHECKPOINT STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Global checkpoints
    Checkpoints.Trace private _globalCheckpoints;
    /// @notice Mapping of global slope changes
    mapping(uint256 => int128) public globalSlopeChanges;

    /// @notice User checkpoints
    mapping(uint256 tokenId => Checkpoints.Trace) private _userCheckpoints;

    /// @notice Delegate checkpoints
    mapping(address delegatee => Checkpoints.Trace) private _delegateCheckpoints;
    /// @notice Delegatee mapping
    mapping(uint256 tokenId => Checkpoints.TraceAddress) private _delegatee;
    /// @notice Delegatee slope changes
    mapping(address tokenId => mapping(uint256 => int128)) public delegateeSlopeChanges;

    /*//////////////////////////////////////////////////////////////
                          /   CHECKPOINT STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The clock was incorrectly modified.
     */
    error ERC6372InconsistentClock();

    /**
     * @dev Lookup to future votes is not available.
     */
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

    /**
     * @notice Clock used for flagging checkpoints.
     * @return Current timestamp
     */
    function clock() public view virtual returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @notice Clock used for flagging global checkpoints.
     * @return Current timestamp rounded to the nearest clock unit
     */
    function globalClock() public view virtual returns (uint48) {
        return (Time.timestamp() / CLOCK_UNIT) * CLOCK_UNIT;
    }

    /**
     * @notice Converts a timestamp to a global clock value.
     * @param _timestamp The timestamp to convert
     * @return The converted global clock value
     */
    function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48) {
        return uint48((_timestamp / CLOCK_UNIT) * CLOCK_UNIT);
    }

    /**
     * @notice Machine-readable description of the clock as specified in EIP-6372.
     * @return The clock mode
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        // Check that the clock was not modified
        if (clock() != Time.timestamp()) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    /**
     * @dev Record global and per-user data to checkpoints. Used by VotingEscrow system.
     * @param _tokenId NFT token ID. No user checkpoint if 0
     * @param uOladamount Previous locked amount / end lock time for the user
     * @param uNewAmount New locked amount / end lock time for the user
     * @param uOldEndTime New locked amount / end lock time for the user
     * @param uNewEndTime New locked amount / end lock time for the user
     */
    function _checkpoint(
        uint256 _tokenId,
        int128 uOladamount,
        int128 uNewAmount,
        uint256 uOldEndTime,
        uint256 uNewEndTime
    ) internal {
        int128 oldDslope = 0;
        int128 newDslope = 0;
        Checkpoints.Point memory uOldPoint = Checkpoints.blankPoint();
        Checkpoints.Point memory uNewPoint = Checkpoints.blankPoint();
        /// @notice if this is not rounded to CLOCK_UNIT
        /// the system will not be able to go too long without checkpoints
        uNewEndTime = toGlobalClock(uNewEndTime);
        if (_tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            uNewPoint.permanent = uNewEndTime == 0 ? uNewAmount : int128(0);
            uOldPoint.permanent = uOldEndTime == 0 ? uOladamount : int128(0);
            if (uOldEndTime > block.timestamp && uOladamount > 0) {
                uOldPoint.slope = (uOladamount * _PRECISSION) / MAXTIME;
                uOldPoint.bias = (uOldPoint.slope * (uOldEndTime - block.timestamp).toInt128()) / _PRECISSION;
            }
            if (uNewEndTime > block.timestamp && uNewAmount > 0) {
                uNewPoint.slope = (uNewAmount * _PRECISSION) / MAXTIME;
                uNewPoint.bias = (uNewPoint.slope * (uNewEndTime - block.timestamp).toInt128()) / _PRECISSION;
            }
            oldDslope = globalSlopeChanges[uOldEndTime];
            if (uNewEndTime != 0) {
                if (uNewEndTime == uOldEndTime) {
                    newDslope = oldDslope;
                } else {
                    newDslope = globalSlopeChanges[uNewEndTime];
                }
            }

            // Schedule the slope changes (slope is going down)
            // We subtract new user slope from [_newLocked.endTime]
            // and add old_user_slope to [_oldLocked.end]
            if (uOldEndTime > block.timestamp) {
                // oldDslope was <something> - uOld.slope, so we cancel that
                oldDslope += uOldPoint.slope;
                if (uOldEndTime == uNewEndTime) {
                    oldDslope -= uNewPoint.slope; // It was a new deposit, not extension
                }
                globalSlopeChanges[uOldEndTime] = oldDslope;
            }

            if (uNewEndTime > block.timestamp) {
                // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
                if ((uNewEndTime > uOldEndTime)) {
                    newDslope -= uNewPoint.slope; // old slope disappeared at this point
                    globalSlopeChanges[uNewEndTime] = newDslope;
                    // console.log("Pushed slope: %s to change: %s", uNewEndTime);
                    // console.logInt(newDslope);
                }
                // else: we recorded it already in oldDslope
            }

            _userCheckpoint(_tokenId, uNewPoint);

            (, uint48 delegateTs, address delegateeAddress) = _delegatee[_tokenId].latestCheckpoint();

            if (delegateTs != 0) {
                /// @notice this can likely be handled more efficienttly
                _checkpointDelegatee(delegateeAddress, uOldPoint, uOldEndTime, false);
                _checkpointDelegatee(delegateeAddress, uNewPoint, uNewEndTime, true);
            }
        }

        _globalCheckpoint(_tokenId, uOldPoint, uNewPoint);
    }

    /**
     * @dev Internal function to update user checkpoint with new point
     * @param _tokenId The ID of the token
     * @param uNewPoint The new point to be updated
     */
    function _userCheckpoint(uint256 _tokenId, Checkpoints.Point memory uNewPoint) internal {
        _pushStruct(_userCheckpoints[_tokenId], uNewPoint);
    }

    /**
     * @dev Internal function to update global checkpoint
     */
    function _globalCheckpoint() internal {
        _globalCheckpoint(0, Checkpoints.blankPoint(), Checkpoints.blankPoint());
    }

    /**
     * @dev Internal function to update global checkpoint with new points
     * @param _tokenId The ID of the token
     * @param uOldPoint The old point to be updated
     * @param uNewPoint The new point to be updated
     */
    function _globalCheckpoint(
        uint256 _tokenId,
        Checkpoints.Point memory uOldPoint,
        Checkpoints.Point memory uNewPoint
    ) internal {
        (, uint48 lastPoint, Checkpoints.Point memory lastGlobal) = _globalCheckpoints.latestCheckpoint();
        uint48 lastCheckpoint = lastPoint != 0 ? lastPoint : uint48(block.timestamp);

        {
            // Go over weeks to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint); /// @dev  lastCheckpoint > tesTime
            uint maxTime = testTime + MAXTIME.toUint256();

            while (testTime != block.timestamp) {
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = block.timestamp.toUint48();
                } else {
                    dSlope = globalSlopeChanges[testTime];
                }
                if (dSlope != 0) {
                    console.log(
                        "Last slope %s - Last Bias: %s - Clock() %s",
                        lastGlobal.slope.toUint256(),
                        lastGlobal.bias.toUint256(),
                        testTime
                    );
                    lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastCheckpoint).toInt128()) /
                        _PRECISSION);
                    lastGlobal.slope += dSlope;
                    lastCheckpoint = testTime;
                    _globalCheckpoints.push(lastCheckpoint, lastGlobal);
                }
                if (testTime > maxTime) break;
            }
        }

        if (_tokenId != 0) {
            lastGlobal.bias =
                lastGlobal.bias -
                ((lastGlobal.slope * (block.timestamp - lastCheckpoint).toInt128()) / _PRECISSION);

            lastGlobal.slope += uNewPoint.slope - uOldPoint.slope;
            lastGlobal.bias += uNewPoint.bias - uOldPoint.bias;
            lastGlobal.permanent += uNewPoint.permanent - uOldPoint.permanent;
        } else {
            // Initial value of testTime is always larger than the ts of the last point
            uint256 testTime = block.timestamp;
            lastGlobal.bias -= (lastGlobal.slope * (testTime - lastCheckpoint).toInt128()) / _PRECISSION;
        }

        _pushStruct(_globalCheckpoints, lastGlobal);
    }

    /**
     * @dev Internal function to calculate total voting power at some point in the past
     * @param _delegateeAddress The address of the delegatee
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function _getAdjustedVotes(address _delegateeAddress, uint48 _timestamp) internal view returns (uint256) {
        Checkpoints.Point memory lastPoint = _getAdjustedVotesCheckpoint(_delegateeAddress, _timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /**
     * @dev Internal function to get delegated votes checkpoint at some point in the past
     * @param _delegateeAddress The address of the delegatee
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function _getAdjustedVotesCheckpoint(
        address _delegateeAddress,
        uint48 _timestamp
    ) internal view returns (Checkpoints.Point memory) {
        (bool exists, uint48 lastCheckpointTs, Checkpoints.Point memory lastPoint) = _delegateCheckpoints[
            _delegateeAddress
        ].upperLookupRecent(_timestamp);
        if (!exists) return lastPoint;
        uint48 testTime = toGlobalClock(lastCheckpointTs); /// @dev  lastCheckpointTs > tesTime
        uint maxTime = testTime + MAXTIME.toUint256();
        while (testTime != _timestamp) {
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = delegateeSlopeChanges[_delegateeAddress][testTime];
            }
            if (dSlope != 0) {
                console.log(
                    "Last slope %s - Last Bias: %s - Clock() %s",
                    lastPoint.slope.toUint256(),
                    lastPoint.bias.toUint256(),
                    testTime
                );
                lastPoint.bias -= ((lastPoint.slope * uint256(testTime - lastCheckpointTs).toInt128()) / _PRECISSION);
                lastPoint.slope += dSlope;
                lastCheckpointTs = uint48(testTime);
            }
            if (testTime > maxTime) break;
        }
        int128 change = (lastPoint.slope * uint256(_timestamp - lastCheckpointTs).toInt128()) / _PRECISSION;
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;

        return lastPoint;
    }

    /**
     * @notice Public function to get the delegate of a token
     * @param tokenId The ID of the token
     * @return The address of the delegate
     */
    function delegates(uint256 tokenId) public view returns (address) {
        return _delegates(tokenId, block.timestamp.toUint48());
    }

    /**
     * @notice Public function to get the delegate of a token at a specific timestamp
     * @param tokenId The ID of the token
     * @param timestamp The timestamp to get the delegate at
     * @return The address of the delegate
     */
    function delegates(uint256 tokenId, uint48 timestamp) external view returns (address) {
        return _delegates(tokenId, timestamp);
    }

    /**
     * @dev Internal function to get the delegate of a token at a specific timestamp
     * @param tokenId The ID of the token
     * @param timestamp The timestamp to get the delegate at
     * @return The address of the delegate
     */
    function _delegates(uint256 tokenId, uint48 timestamp) internal view returns (address) {
        return _delegatee[tokenId].upperLookupRecent(timestamp);
    }

    /**
     * @dev Internal function to record user delegation checkpoints. Used by voting system.
     * @param _delegator The ID of the delegator
     * @param delegatee The address of the delegatee
     * @param endTime The end time of the delegation
     */
    function _delegate(uint256 _delegator, address delegatee, uint256 endTime) internal {
        address currentDelegate = _delegatee[_delegator].latest();
        if (currentDelegate == delegatee) return;

        _checkpointDelegator(_delegator, delegatee, endTime);

        // emit DelegateChanged(_msgSender(), currentDelegate, delegatee);
    }

    /**
     * @dev Internal function used by `_delegate`
     *      to update delegator voting checkpoints.
     *      Automatically dedelegates, then updates checkpoint.
     * @param _delegator The delegator to update checkpoints for
     * @param delegatee The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead).
     * @param endTime The end time of the delegation
     */
    function _checkpointDelegator(uint256 _delegator, address delegatee, uint256 endTime) internal {
        (, uint48 ts, Checkpoints.Point memory lastPoint) = _userCheckpoints[_delegator].latestCheckpoint();
        lastPoint.bias -= ((lastPoint.slope * (block.timestamp - ts).toInt128()) / _PRECISSION);
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        // Dedelegate from delegatee if delegated
        address oldDelegatee = _delegatee[_delegator].latest();
        if (oldDelegatee != delegatee && oldDelegatee != address(0))
            _checkpointDelegatee(oldDelegatee, lastPoint, endTime, false);
        // Delegate to new delegator
        if (endTime > block.timestamp) _checkpointDelegatee(delegatee, lastPoint, endTime, true);
        _pushAddress(_delegatee[_delegator], delegatee);
    }

    /**
     * @dev Internal function to update delegatee's `delegatedBalance` by `balance`.
     *      Only updates if delegating to a new delegatee.
     * @param deelegateeAddress The address of the delegatee
     * @param userPoint The point of the user
     * @param endTime The end time of the delegation
     * @param _increase Whether to increase or decrease the balance
     */
    function _checkpointDelegatee(
        address deelegateeAddress,
        Checkpoints.Point memory userPoint,
        uint256 endTime,
        bool _increase
    ) internal {
        (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) = _baseCheckpointDelegatee(deelegateeAddress);

        int128 baseBias = lastPoint.bias -
            (lastPoint.slope * (block.timestamp - lastCheckpoint).toInt128()) /
            _PRECISSION;

        if (!_increase) {
            delegateeSlopeChanges[deelegateeAddress][endTime] += userPoint.slope;
            lastPoint.bias = userPoint.bias < baseBias ? baseBias - userPoint.bias : int128(0);
            lastPoint.slope = userPoint.slope < lastPoint.slope ? lastPoint.slope - userPoint.slope : int128(0);
            lastPoint.permanent = userPoint.permanent < lastPoint.permanent
                ? lastPoint.permanent - userPoint.permanent
                : int128(0);
        } else {
            delegateeSlopeChanges[deelegateeAddress][endTime] -= userPoint.slope;
            lastPoint.bias = baseBias + userPoint.bias;
            lastPoint.slope = lastPoint.slope + userPoint.slope;
            lastPoint.permanent = lastPoint.permanent + userPoint.permanent;
        }
        /// @dev bias can be rounded up by lack of precision. If slope is 0 we are out
        // if (lastPoint.slope == 0) lastPoint.bias = 0;
        _pushStruct(_delegateCheckpoints[deelegateeAddress], lastPoint);
    }

    /**
     * @dev Internal function to update delegatee's checkpoint
     * @param delegateeAddress The address of the delegatee
     * @return lastPoint The last point of the delegatee
     * @return lastCheckpoint The last checkpoint time of the delegatee
     */
    function _baseCheckpointDelegatee(
        address delegateeAddress
    ) internal returns (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) {
        (bool exists, uint48 ts, Checkpoints.Point memory point) = _delegateCheckpoints[delegateeAddress]
            .latestCheckpoint();
        lastPoint = point;
        lastCheckpoint = ts;
        if (exists) {
            // Go over days to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint); /// @dev  lastCheckpoint > tesTime

            uint maxTime = testTime + MAXTIME.toUint256();

            // Iterate over time until current block timestamp or maxtime
            while (testTime != block.timestamp) {
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = uint48(block.timestamp);
                } else {
                    dSlope = delegateeSlopeChanges[delegateeAddress][testTime];
                }
                if (dSlope != 0) {
                    console.log(
                        "Last slope %s - Last Bias: %s - Clock() %s",
                        lastPoint.slope.toUint256(),
                        lastPoint.bias.toUint256(),
                        testTime
                    );
                    lastPoint.bias -= ((lastPoint.slope * uint256(testTime - lastCheckpoint).toInt128()) / _PRECISSION);
                    lastPoint.slope += dSlope;
                    lastCheckpoint = uint48(testTime);
                    _delegateCheckpoints[delegateeAddress].push(lastCheckpoint, lastPoint);
                }
                if (testTime > maxTime) break;
            }
        }
    }

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

    /**
     * @dev Internal function to calculate total voting power at some point in the past
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function _getAdjustedGlobalVotes(uint48 _timestamp) internal view returns (uint256) {
        Checkpoints.Point memory lastPoint = _getAdjustedCheckpoint(_timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /**
     * @dev Internal function to get latest checkpoint of some point in the past
     * @param _timestamp Time to calculate the total voting power at
     * @return Total voting power at that time
     */
    function _getAdjustedCheckpoint(uint48 _timestamp) internal view returns (Checkpoints.Point memory) {
        uint48 clockTime = _timestamp;
        (bool exists, uint48 lastCheckpointTs, Checkpoints.Point memory lastGlobal) = _globalCheckpoints
            .upperLookupRecent(clockTime);
        if (!exists) return lastGlobal;
        uint48 testTime = toGlobalClock(lastCheckpointTs); /// @dev  lastCheckpointTs > tesTime
        uint maxTime = testTime + MAXTIME.toUint256();

        // Iterate over time until the specified timestamp or maxtime is reached
        while (testTime != _timestamp) {
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = globalSlopeChanges[testTime];
            }
            if (dSlope != 0) {
                console.log(
                    "Last slope %s - Last Bias: %s - Clock() %s",
                    lastGlobal.slope.toUint256(),
                    lastGlobal.bias.toUint256(),
                    testTime
                );
                lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastCheckpointTs).toInt128()) / _PRECISSION);
                lastGlobal.slope += dSlope;
                lastCheckpointTs = uint48(testTime);
            }
            if (testTime > maxTime) break;
        }

        int128 change = (lastGlobal.slope * uint256(clockTime - lastCheckpointTs).toInt128()) / _PRECISSION;
        lastGlobal.bias = lastGlobal.bias < change ? int128(0) : lastGlobal.bias - change;

        return lastGlobal;
    }

    /**
     * @notice Get the current bias for `_tokenId` at `_timestamp`
     * @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
     * @dev Fetches last user point prior to a certain timestamp, then walks forward to timestamp.
     * @param _tokenId NFT for lock
     * @param _timestamp Epoch time to return bias power at
     * @return NFT bias
     */
    function _getAdjustedNftBias(uint256 _tokenId, uint256 _timestamp) internal view returns (uint256) {
        uint48 clockTime = _timestamp.toUint48();
        (bool exists, uint48 ts, Checkpoints.Point memory lastPoint) = _userCheckpoints[_tokenId].upperLookupRecent(
            clockTime
        );
        if (!exists) return 0;
        if (lastPoint.permanent != 0) return lastPoint.permanent.toUint256();
        int128 change = (((lastPoint.slope * uint256(clockTime - ts).toInt128()) / _PRECISSION));
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;
        return lastPoint.bias.toUint256();
    }
}
