// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";

contract CheckPointSystem is ReentrancyGuard {
    using Checkpoints for Checkpoints.Trace;
    using Checkpoints for Checkpoints.TraceAddress;
    using SafeCastLibrary for int128;
    using SafeCastLibrary for uint256;

    int128 public constant MAXTIME = 2 * 365 * 86400;
    // TODO: Revisit need of presission
    int128 internal constant _PRECISSION = 1;
    uint48 public constant CLOCK_UNIT = 1 days;

    /*//////////////////////////////////////////////////////////////
                             CHECKPOINT STORAGE
    //////////////////////////////////////////////////////////////*/

    Checkpoints.Trace private _globalCheckpoints;
    mapping(uint256 => int128) public globalSlopeChanges;

    mapping(uint256 tokenId => Checkpoints.Trace) private _userCheckpoints;

    mapping(address delegatee => Checkpoints.Trace) private _delegateCheckpoints;
    mapping(uint256 tokenId => Checkpoints.TraceAddress) private _delegatee;
    mapping(address tokenId => mapping(uint256 => int128)) public delegateeSlopeChanges;

    // TODO: do we even need this or this = latestGlobalCheckpoint permanent balance
    // uint256 public permanentLockBalance;

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
     * @dev Clock used for flagging checkpoints.
     */
    function clock() public view virtual returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @dev Clock used for flagging global checkpoints.
     */
    function globalClock() public view virtual returns (uint48) {
        return (Time.timestamp() / CLOCK_UNIT) * CLOCK_UNIT;
    }

    /**
     * @dev Clock used for flagging global checkpoints.
     */
    function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48) {
        return uint48((_timestamp / CLOCK_UNIT) * CLOCK_UNIT);
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        // Check that the clock was not modified
        if (clock() != Time.timestamp()) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    /// @notice Record global and per-user data to checkpoints. Used by VotingEscrow system.
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param uOladamount Pevious locked amount / end lock time for the user
    /// @param uNewAmount New locked amount / end lock time for the user
    /// @param uOldEndTime New locked amount / end lock time for the user
    /// @param uNewEndTime New locked amount / end lock time for the user
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
        /// @notice if this is not rounded to days the system will not be able to handle much time without checkpoints
        uNewEndTime = toGlobalClock(uNewEndTime);
        if (_tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            uNewPoint.permanent = uNewEndTime == 0 ? uNewAmount : int128(0);
            uOldPoint.permanent = uOldEndTime == 0 ? uOladamount : int128(0);
            if (uOldEndTime > block.timestamp && uOladamount > 0) {
                // // console.log("1 End Time %s -- Diff %s", uOldEndTime, uOldEndTime - block.timestamp);
                uOldPoint.slope = (uOladamount * _PRECISSION) / MAXTIME;
                uOldPoint.bias = (uOldPoint.slope * (uOldEndTime - block.timestamp).toInt128()) / _PRECISSION;
            }
            if (uNewEndTime > block.timestamp && uNewAmount > 0) {
                // // console.log("2 End Time %s -- Diff %s", uNewEndTime, uNewEndTime - block.timestamp);
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
            // We subtract new_user_slope from [_newLocked.end]
            // and add old_user_slope to [_oldLocked.end]
            if (uOldEndTime > block.timestamp) {
                // oldDslope was <something> - uOld.slope, so we cancel that
                oldDslope += uOldPoint.slope;
                if (uOldEndTime == uNewEndTime) {
                    oldDslope -= uNewPoint.slope; // It was a new deposit, not extension
                }
                globalSlopeChanges[uOldEndTime] = oldDslope;
                // console.log("Pushed slope: %s to change: %s", uOldEndTime);
                // console.logInt(oldDslope);
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

            _userCheckpoint(_tokenId, uNewPoint.bias, uNewPoint.slope, uNewPoint.permanent);

            (, uint48 delegateTs, address delegateeAddress) = _delegatee[_tokenId].latestCheckpoint();

            if (delegateTs != 0) {
                /// @notice this can likely be handled more efficienttly
                _checkpointDelegatee(
                    delegateeAddress,
                    uOldPoint.bias,
                    uOldPoint.slope,
                    uOldPoint.permanent,
                    uOldEndTime,
                    false
                );
                _checkpointDelegatee(
                    delegateeAddress,
                    uNewPoint.bias,
                    uNewPoint.slope,
                    uNewPoint.permanent,
                    uNewEndTime,
                    true
                );
            }
        }

        _globalCheckpoint(
            _tokenId,
            uOldPoint.bias,
            uOldPoint.slope,
            uOldPoint.permanent,
            uNewPoint.bias,
            uNewPoint.slope,
            uNewPoint.permanent
        );
    }

    function _userCheckpoint(uint256 _tokenId, int128 bias, int128 slope, int128 permanent) internal {
        _pushStruct(_userCheckpoints[_tokenId], Checkpoints.Point({bias: bias, slope: slope, permanent: permanent}));
    }

    function _globalCheckpoint(
        uint256 _tokenId,
        int128 uOldBias,
        int128 uOldSlope,
        int128 uOldPermanent,
        int128 uNewBias,
        int128 uNewSlope,
        int128 uNewPermanent
    ) internal {
        (, uint48 lastPoint, Checkpoints.Point memory lastGlobal) = _globalCheckpoints.latestCheckpoint();
        uint48 lastCheckpoint = lastPoint != 0 ? lastPoint : uint48(block.timestamp);

        {
            // Go over weeks to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint);

            while (testTime != block.timestamp) {
                // TODO: Need to limit number of iterations
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = uint48(block.timestamp);
                } else {
                    dSlope = globalSlopeChanges[testTime];
                }
                if (dSlope != 0) {
                    // console.log(
                    //     "Last slope %s - Last Bias: %s - Clock() %s",
                    //     lastGlobal.slope.toUint256(),
                    //     lastGlobal.bias.toUint256(),
                    //     t_i
                    // );
                    lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastCheckpoint).toInt128()) /
                        _PRECISSION);
                    lastGlobal.slope += dSlope;
                    lastCheckpoint = uint48(testTime);
                    // _pushStruct(_globalCheckpoints, lastGlobal);
                    _globalCheckpoints.push(lastCheckpoint, lastGlobal);
                }
            }
        }

        // console.log(
        //     "Running checkpoint %s from %s to %s Bias",
        //     lastPoint,
        //     _tokenId,
        //     SafeCast.toUint256(int256(uNewBias))
        // );

        if (_tokenId != 0) {
            // console.log(
            //     "Running globalUpdate %s - bias: %s - slope: %s",
            //     lastPoint,
            //     lastGlobal.bias.toUint256(),
            //     lastGlobal.slope.toUint256()
            // );
            lastGlobal.bias =
                lastGlobal.bias -
                ((lastGlobal.slope * (block.timestamp - lastCheckpoint).toInt128()) / _PRECISSION);

            // int128 preBias = lastGlobal.bias - uOldBias;
            // int128 preSlope = lastGlobal.slope;

            // console.log(
            //     "Running globalUpdate %s - preBias: %s - preSlope: %s",
            //     block.timestamp,
            //     preBias.toUint256(),
            //     preSlope.toUint256()
            // );

            // console.log(
            //     "Running newSlope %s - baseBias: %s - newBias: %s",
            //     uNewSlope.toUint256(),
            //     preBias.toUint256(),
            //     uNewBias.toUint256()
            // );

            lastGlobal.slope += uNewSlope - uOldSlope;
            lastGlobal.bias += uNewBias - uOldBias;
            lastGlobal.permanent += uNewPermanent - uOldPermanent;
        } else {
            // Initial value of testTime is always larger than the ts of the last point
            uint256 testTime = block.timestamp;
            lastGlobal.bias -= (lastGlobal.slope * (testTime - lastCheckpoint).toInt128()) / _PRECISSION;
        }

        // console.log(
        //     "Ran globalUpdate %s - bias: %s - slope: %s",
        //     lastPoint,
        //     lastGlobal.bias.toUint256(),
        //     lastGlobal.slope.toUint256()
        // );

        _pushStruct(_globalCheckpoints, lastGlobal);

        // console.log(
        //     "New Global Bias %s - New Glognal Slope: %s - Checkpoint: %s",
        //     lastGlobal.bias.toUint256(),
        //     lastGlobal.slope.toUint256(),
        //     clock()
        // );
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedVotes(address _delegateeAddress, uint48 _timestamp) internal view returns (uint256) {
        Checkpoints.Point memory lastPoint = _getAdjustedVotesCheckpoint(_delegateeAddress, _timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /// @notice Get delegated votes checkpoint at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedVotesCheckpoint(
        address _delegateeAddress,
        uint48 _timestamp
    ) internal view returns (Checkpoints.Point memory) {
        (bool exists, uint48 ts, Checkpoints.Point memory lastPoint) = _delegateCheckpoints[_delegateeAddress]
            .upperLookupRecent(_timestamp);
        if (!exists) return lastPoint;
        uint48 testTime = toGlobalClock(ts);
        while (testTime != _timestamp) {
            // LMAO sure way to break everything
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = delegateeSlopeChanges[_delegateeAddress][testTime];
            }
            if (dSlope != 0) {
                // console.log(
                //     "Last slope %s - Last Bias: %s - Clock() %s",
                //     lastPoint.slope.toUint256(),
                //     lastPoint.bias.toUint256(),
                //     t_i
                // );
                lastPoint.bias -= ((lastPoint.slope * uint256(testTime - ts).toInt128()) / _PRECISSION);
                lastPoint.slope += dSlope;
                ts = uint48(testTime);
            }
        }
        int128 change = (lastPoint.slope * uint256(_timestamp - ts).toInt128()) / _PRECISSION;
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;

        return lastPoint;
    }

    function delegates(uint256 tokenId) public view returns (address) {
        return _delegates(tokenId, SafeCast.toUint48(block.timestamp));
    }

    function delegates(uint256 tokenId, uint48 timestamp) external view returns (address) {
        return _delegates(tokenId, timestamp);
    }

    function _delegates(uint256 tokenId, uint48 timestamp) internal view returns (address) {
        return _delegatee[tokenId].upperLookupRecent(timestamp);
    }

    /// @notice Record user delegation checkpoints. Used by voting system.
    /// @dev Skips delegation if already delegated to `delegatee`.
    function _delegate(uint256 _delegator, address delegatee, uint256 endTime) internal {
        address currentDelegate = _delegatee[_delegator].latest();
        if (currentDelegate == delegatee) return;

        _checkpointDelegator(_delegator, delegatee, endTime);

        // emit DelegateChanged(_msgSender(), currentDelegate, delegatee);
    }

    /// @notice Used by `_mint`, `_transferFrom`, `_burn` and `delegate`
    ///         to update delegator voting checkpoints.
    ///         Automatically dedelegates, then updates checkpoint.
    /// @dev This function depends on `_locked` and must be called prior to token state changes.
    ///      If you wish to dedelegate only, use `_delegate(tokenId, 0)` instead.
    /// @param _delegator The delegator to update checkpoints for
    /// @param delegatee The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead).
    function _checkpointDelegator(uint256 _delegator, address delegatee, uint256 endTime) internal {
        (, uint48 ts, Checkpoints.Point memory lastPoint) = _userCheckpoints[_delegator].latestCheckpoint();
        lastPoint.bias -= ((lastPoint.slope * (block.timestamp - ts).toInt128()) / _PRECISSION);
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        // Dedelegate from delegatee if delegated
        address oldDelegatee = _delegatee[_delegator].latest();
        // console.log(
        //     "Old Delegatee %s - Ubias: %s - uSlope: %s",
        //     oldDelegatee,
        //     lastPoint.bias.toUint256(),
        //     lastPoint.slope.toUint256()
        // );
        if (oldDelegatee != delegatee && oldDelegatee != address(0))
            _checkpointDelegatee(oldDelegatee, lastPoint.bias, lastPoint.slope, lastPoint.permanent, endTime, false);
        // Delegate to new delegator
        _checkpointDelegatee(delegatee, lastPoint.bias, lastPoint.slope, lastPoint.permanent, endTime, true);
        _pushAddress(_delegatee[_delegator], delegatee);
    }

    /// @notice Update delegatee's `delegatedBalance` by `balance`.
    ///         Only updates if delegating to a new delegatee.
    /// @dev If used with `balance` == `_locked[_tokenId].amount`, then this is the same as
    ///      delegating or dedelegating from `_tokenId`
    ///      If used with `balance` < `_locked[_tokenId].amount`, then this is used to adjust
    ///      `delegatedBalance` when a user's balance is modified (e.g. `increaseAmount`, `merge` etc).
    ///      If `delegatee` is 0 (i.e. user is not delegating), then do nothing.
    function _checkpointDelegatee(
        address deelegateeAddress,
        int128 uBias,
        int128 uSlope,
        int128 uPermanent,
        uint256 endTime,
        bool _increase
    ) internal {
        (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) = _baseCheckpointDelegatee(deelegateeAddress);

        int128 baseBias = lastPoint.bias -
            (lastPoint.slope * (block.timestamp - lastCheckpoint).toInt128()) /
            _PRECISSION;

        if (!_increase) {
            delegateeSlopeChanges[deelegateeAddress][endTime] += uSlope;
            lastPoint.bias = uBias < baseBias ? baseBias - uBias : int128(0);
            lastPoint.slope = uSlope < lastPoint.slope ? lastPoint.slope - uSlope : int128(0);
            lastPoint.permanent = uPermanent < lastPoint.permanent ? lastPoint.permanent - uPermanent : int128(0);
        } else {
            delegateeSlopeChanges[deelegateeAddress][endTime] -= uSlope;
            lastPoint.bias = baseBias + uBias;
            lastPoint.slope = lastPoint.slope + uSlope;
            lastPoint.permanent = lastPoint.permanent + uPermanent;
        }
        /// @dev bias can be rounded up by lack of precision. If slope is 0 we are out
        // if (lastPoint.slope == 0) lastPoint.bias = 0;
        _pushStruct(_delegateCheckpoints[deelegateeAddress], lastPoint);
    }

    function _baseCheckpointDelegatee(
        address delegateeAddress
    ) internal returns (Checkpoints.Point memory lastPoint, uint48 lastCheckpoint) {
        (bool exists, uint48 ts, Checkpoints.Point memory point) = _delegateCheckpoints[delegateeAddress]
            .latestCheckpoint();
        lastPoint = point;
        lastCheckpoint = ts;
        if (exists) {
            // Go over days to fill history and calculate what the current point is
            uint48 testTime = toGlobalClock(lastCheckpoint);

            while (testTime != block.timestamp) {
                // LMAO Premium solidity dev over here
                testTime += CLOCK_UNIT;
                int128 dSlope = 0;
                if (testTime > block.timestamp) {
                    testTime = uint48(block.timestamp);
                } else {
                    dSlope = delegateeSlopeChanges[delegateeAddress][testTime];
                }
                if (dSlope != 0) {
                    // console.log(
                    //     "Last slope %s - Last Bias: %s - Clock() %s",
                    //     lastPoint.slope.toUint256(),
                    //     lastPoint.bias.toUint256(),
                    //     t_i
                    // );
                    lastPoint.bias -= ((lastPoint.slope * uint256(testTime - lastCheckpoint).toInt128()) / _PRECISSION);
                    lastPoint.slope += dSlope;
                    lastCheckpoint = uint48(testTime);
                    _delegateCheckpoints[delegateeAddress].push(lastCheckpoint, lastPoint);
                }
            }
        }
    }

    function _pushAddress(Checkpoints.TraceAddress storage store, address value) private returns (address, address) {
        return store.push(clock(), value);
    }

    function _pushStruct(
        Checkpoints.Trace storage store,
        Checkpoints.Point memory value
    ) private returns (Checkpoints.Point memory, Checkpoints.Point memory) {
        return store.push(clock(), value);
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedGlobalVotes(uint48 _timestamp) internal view returns (uint256) {
        Checkpoints.Point memory lastPoint = _getAdjustedCheckpoint(_timestamp);
        return (lastPoint.bias + lastPoint.permanent).toUint256();
    }

    /// @notice Get latest checkpointo of some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedCheckpoint(uint48 _timestamp) internal view returns (Checkpoints.Point memory) {
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint48 lastPoint, Checkpoints.Point memory lastGlobal) = _globalCheckpoints.upperLookupRecent(
            clockTime
        );
        if (!exists) return lastGlobal;
        // console.log("Global Bias %s - Last Point: %s - Clock() %s",
        // lastGlobal.bias.toUint256(), lastPoint, _timestamp);
        uint48 testTime = toGlobalClock(lastPoint);
        while (testTime != _timestamp) {
            // LMAO sure way to break everything
            testTime += CLOCK_UNIT;
            int128 dSlope = 0;
            if (testTime > _timestamp) {
                testTime = _timestamp;
            } else {
                dSlope = globalSlopeChanges[testTime];
            }
            if (dSlope != 0) {
                // console.log(
                //     "Last slope %s - Last Bias: %s - Clock() %s",
                //     lastGlobal.slope.toUint256(),
                //     lastGlobal.bias.toUint256(),
                //     testTime
                // );
                lastGlobal.bias -= ((lastGlobal.slope * uint256(testTime - lastPoint).toInt128()) / _PRECISSION);
                lastGlobal.slope += dSlope;
                lastPoint = uint48(testTime);
            }
        }
        int128 change = (lastGlobal.slope * uint256(clockTime - lastPoint).toInt128()) / _PRECISSION;
        lastGlobal.bias = lastGlobal.bias < change ? int128(0) : lastGlobal.bias - change;

        return lastGlobal;
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    ///      Fetches last user point prior to a certain timestamp, then walks forward to timestamp.
    /// @param _tokenId NFT for lock
    /// @param _timestamp Epoch time to return voting power at
    /// @return User voting power
    function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        // TODO: Esto no va aca (carajo)
        uint48 clockTime = SafeCast.toUint48(_timestamp);
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
