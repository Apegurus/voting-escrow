// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// TODO:
import {IVotes} from "../interfaces/IVotes.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";
import {StructCheckpoints} from "../libraries/StructCheckpoints.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {BalanceLogicLibrary} from "../libraries/BalanceLogicLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract EscrowVotes is IVotes, ReentrancyGuard {
    using StructCheckpoints for StructCheckpoints.Trace;
    using Checkpoints for Checkpoints.Trace208;
    using SafeCastLibrary for int128;
    using SafeCastLibrary for uint256;

    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    int128 internal constant MAXTIME = 2 * 365 * 86400;
    int128 internal constant PRECISSION = 1e12;
    uint48 public constant CLOCK_UNIT = 1 days;

    StructCheckpoints.Trace private _globalCheckpoints;
    mapping(uint256 => int128) public _globalSlopeChanges;

    mapping(uint256 tokenId => StructCheckpoints.Trace) private _userCheckpoints;

    mapping(uint256 delegatee => StructCheckpoints.Trace) private _delegateCheckpoints;
    mapping(uint256 tokenId => Checkpoints.Trace208) private _delegatee;
    mapping(uint256 tokenId => mapping(uint256 => int128)) public _delegateeSlopeChanges;

    uint256 public permanentLockBalance;

    /*//////////////////////////////////////////////////////////////
                          /   ESCROW STORAGE
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
        int128 uOldBias;
        int128 uOldSlope;
        int128 uNewBias;
        int128 uNewSlope;
        /// @notice if this is not rounded to days the system will not be able to handle much time without checkpoints
        uNewEndTime = toGlobalClock(uNewEndTime);

        if (_tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (uOldEndTime > block.timestamp && uOladamount > 0) {
                console.log("1 End Time %s -- Diff %s", uOldEndTime, uOldEndTime - block.timestamp);
                uOldSlope = (uOladamount * PRECISSION) / MAXTIME;
                uOldBias = (uOldSlope * (uOldEndTime - block.timestamp).toInt128()) / PRECISSION;
            }
            if (uNewEndTime > block.timestamp && uNewAmount > 0) {
                console.log("2 End Time %s -- Diff %s", uNewEndTime, uNewEndTime - block.timestamp);
                uNewSlope = (uNewAmount * PRECISSION) / MAXTIME;
                uNewBias = (uNewSlope * (uNewEndTime - block.timestamp).toInt128()) / PRECISSION;
            }
            oldDslope = _globalSlopeChanges[uOldEndTime];
            if (uNewEndTime != 0) {
                if (uNewEndTime == uOldEndTime) {
                    newDslope = oldDslope;
                } else {
                    newDslope = _globalSlopeChanges[uNewEndTime];
                }
            }

            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [_newLocked.end]
            // and add old_user_slope to [_oldLocked.end]
            if (uOldEndTime > block.timestamp) {
                // oldDslope was <something> - uOld.slope, so we cancel that
                oldDslope += uOldSlope;
                if (uOldEndTime == uNewEndTime) {
                    oldDslope -= uNewSlope; // It was a new deposit, not extension
                }
                _globalSlopeChanges[uOldEndTime] = oldDslope;
                console.log("Pushed slope: %s to change: %s", uOldEndTime);
                console.logInt(oldDslope);
            }

            if (uNewEndTime > block.timestamp) {
                // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
                if ((uNewEndTime > uOldEndTime)) {
                    newDslope -= uNewSlope; // old slope disappeared at this point
                    _globalSlopeChanges[uNewEndTime] = newDslope;
                    console.log("Pushed slope: %s to change: %s", uNewEndTime);
                    console.logInt(newDslope);
                }
                // else: we recorded it already in oldDslope
            }

            _userCheckpoint(_tokenId, uNewBias, uNewSlope);

            // (, uint DelegateTs, uint delegateeTokenId) = _delegatee[_tokenId].latestCheckpoint();

            // if (DelegateTs != 0) {
            //     (, uint ts, uint lastBias) = _delegateCheckpointsBias[delegateeTokenId].latestCheckpoint();

            //     (, , uint lastSlope) = _delegateCheckpointsSlope[delegateeTokenId].latestCheckpoint();
            //     uint256 preBias = DelegateTs <= lastUserCheckPoint ? lastBias - lastUserBias : lastBias;
            //     uint256 preSlope = DelegateTs <= lastUserCheckPoint ? lastSlope - lastUserSlope : lastSlope;

            //     uint256 baseBias = preBias - (preSlope * (ts - block.timestamp)) / PRECISSION;

            //     _push(_delegateCheckpointsBias[delegateeTokenId], SafeCast.toUint208(baseBias + uNewBias));
            //     _push(_delegateCheckpointsSlope[delegateeTokenId], SafeCast.toUint208(preSlope + uNewSlope));
            // }
        }

        _globalCheckpoint(_tokenId, uOldBias, uOldSlope, uNewBias, uNewSlope);
    }

    function _userCheckpoint(uint256 _tokenId, int128 bias, int128 slope) internal {
        _pushStruct(_userCheckpoints[_tokenId], StructCheckpoints.Point({bias: bias, slope: slope, permanent: 0}));
    }

    function _globalCheckpoint(
        uint256 _tokenId,
        int128 uOldBias,
        int128 uOldSlope,
        int128 uNewBias,
        int128 uNewSlope
    ) internal {
        (, uint48 lastPoint, StructCheckpoints.Point memory lastGlobal) = _globalCheckpoints.latestCheckpoint();
        uint48 lastCheckpoint = lastPoint != 0 ? lastPoint : uint48(block.timestamp);

        {
            // Go over weeks to fill history and calculate what the current point is
            uint48 t_i = toGlobalClock(lastCheckpoint);

            while (t_i != block.timestamp) {
                // LMAO Premium solidity dev over here
                t_i += CLOCK_UNIT;
                int128 dSlope = 0;
                if (t_i > block.timestamp) {
                    t_i = uint48(block.timestamp);
                } else {
                    dSlope = _globalSlopeChanges[t_i];
                }
                if (dSlope != 0) {
                    console.log(
                        "Last slope %s - Last Bias: %s - Clock() %s",
                        lastGlobal.slope.toUint256(),
                        lastGlobal.bias.toUint256(),
                        t_i
                    );
                    lastGlobal.bias -= ((lastGlobal.slope * uint256(t_i - lastCheckpoint).toInt128()) / PRECISSION);
                    lastGlobal.slope += dSlope;
                    lastCheckpoint = uint48(t_i);
                    // _pushStruct(_globalCheckpoints, lastGlobal);
                    _globalCheckpoints.push(lastCheckpoint, lastGlobal);
                }
            }
        }

        console.log(
            "Running checkpoint %s from %s to %s Bias",
            lastPoint,
            _tokenId,
            SafeCast.toUint256(int256(uNewBias))
        );

        if (_tokenId != 0) {
            console.log(
                "Running globalUpdate %s - bias: %s - slope: %s",
                lastPoint,
                lastGlobal.bias.toUint256(),
                lastGlobal.slope.toUint256()
            );

            int128 preBias = lastGlobal.bias - uOldBias;
            int128 preSlope = lastGlobal.slope - uOldSlope;

            console.log(
                "Running globalUpdate %s - preBias: %s - preSlope: %s",
                block.timestamp,
                preBias.toUint256(),
                preSlope.toUint256()
            );
            int128 baseBias = preBias - ((preSlope * (block.timestamp - lastCheckpoint).toInt128()) / PRECISSION);

            console.log(
                "Running newSlope %s - baseBias: %s - newBias: %s",
                uNewSlope.toUint256(),
                baseBias.toUint256(),
                uNewBias.toUint256()
            );

            lastGlobal.slope = preSlope + uNewSlope;
            lastGlobal.bias = baseBias + uNewBias;
        } else {
            uint t_i = block.timestamp; // Initial value of t_i is always larger than the ts of the last point
            lastGlobal.bias -= (lastGlobal.slope * (t_i - lastCheckpoint).toInt128()) / PRECISSION;
        }

        console.log(
            "Ran globalUpdate %s - bias: %s - slope: %s",
            lastPoint,
            lastGlobal.bias.toUint256(),
            lastGlobal.slope.toUint256()
        );

        _pushStruct(_globalCheckpoints, lastGlobal);

        console.log(
            "New Global Bias %s - New Glognal Slope: %s - Checkpoint: %s",
            lastGlobal.bias.toUint256(),
            lastGlobal.slope.toUint256(),
            clock()
        );
    }

    function getVotes(uint256 tokenId) external view override returns (uint256) {}

    /// @notice Retrieves historical voting balance for a token id at a given timestamp.
    /// @dev If a checkpoint does not exist prior to the timestamp, this will return 0.
    ///      The user must also own the token at the time in order to receive a voting balance.
    /// @param _tokenId .
    /// @param _timestamp .
    /// @return votes Total voting balance including delegations at a given timestamp.
    function getPastVotes(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return _getAdjustedVotesCheckpoint(_tokenId, SafeCast.toUint48(_timestamp)).bias.toUint256();
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedVotesCheckpoint(
        uint256 _tokenId,
        uint48 _timestamp
    ) internal view returns (StructCheckpoints.Point memory) {
        (bool exists, uint ts, StructCheckpoints.Point memory lastPoint) = _delegateCheckpoints[_tokenId]
            .upperLookupRecent(_timestamp);
        if (!exists) return lastPoint;
        uint48 t_i = toGlobalClock(ts);
        while (t_i != _timestamp) {
            // LMAO sure way to break everything
            t_i += CLOCK_UNIT;
            int128 dSlope = 0;
            if (t_i > _timestamp) {
                t_i = _timestamp;
            } else {
                dSlope = _delegateeSlopeChanges[_tokenId][t_i];
            }
            if (dSlope != 0) {
                console.log(
                    "Last slope %s - Last Bias: %s - Clock() %s",
                    lastPoint.slope.toUint256(),
                    lastPoint.bias.toUint256(),
                    t_i
                );
                lastPoint.bias -= ((lastPoint.slope * uint256(t_i - ts).toInt128()) / PRECISSION);
                lastPoint.slope += dSlope;
                ts = uint48(t_i);
            }
        }
        int128 change = (lastPoint.slope * uint256(_timestamp - ts).toInt128()) / PRECISSION;
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;

        return lastPoint;
    }

    function getPastTotalSupply(uint256 timepoint) external view override returns (uint256) {}

    function delegate(uint256 delegator, uint256 delegatee) external virtual override {}

    function delegates(uint256 tokenId) external view override returns (uint256) {
        return _delegatee[tokenId].latest();
    }

    function delegateBySig(
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {}

    /// @notice Record user delegation checkpoints. Used by voting system.
    /// @dev Skips delegation if already delegated to `delegatee`.
    function _delegate(uint256 _delegator, uint256 delegatee, uint256 endTime) internal {
        uint256 currentDelegate = _delegatee[_delegator].latest();
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
    function _checkpointDelegator(uint256 _delegator, uint256 delegatee, uint256 endTime) internal {
        (, uint ts, StructCheckpoints.Point memory lastPoint) = _userCheckpoints[_delegator].latestCheckpoint();
        lastPoint.bias -= ((lastPoint.slope * (block.timestamp - ts).toInt128()) / PRECISSION);
        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }

        // Dedelegate from delegatee if delegated
        uint256 oldDelegatee = _delegatee[_delegator].latest();
        console.log(
            "Old Delegatee %s - Ubias: %s - uSlope: %s",
            oldDelegatee,
            lastPoint.bias.toUint256(),
            lastPoint.slope.toUint256()
        );
        if (oldDelegatee != delegatee && oldDelegatee != 0)
            _checkpointDelegatee(oldDelegatee, lastPoint.bias, lastPoint.slope, endTime, false);
        // Delegate to new delegator
        _checkpointDelegatee(delegatee, lastPoint.bias, lastPoint.slope, endTime, true);
        _push(_delegatee[_delegator], SafeCast.toUint208(delegatee));
    }

    /// @notice Update delegatee's `delegatedBalance` by `balance`.
    ///         Only updates if delegating to a new delegatee.
    /// @dev If used with `balance` == `_locked[_tokenId].amount`, then this is the same as
    ///      delegating or dedelegating from `_tokenId`
    ///      If used with `balance` < `_locked[_tokenId].amount`, then this is used to adjust
    ///      `delegatedBalance` when a user's balance is modified (e.g. `increaseAmount`, `merge` etc).
    ///      If `delegatee` is 0 (i.e. user is not delegating), then do nothing.
    function _checkpointDelegatee(
        uint256 delegateeTokenId,
        int128 uNewBias,
        int128 uSlope,
        uint256 endTime,
        bool _increase
    ) internal {
        (StructCheckpoints.Point memory lastPoint, uint48 lastCheckpoint) = _baseCheckpointDelegatee(delegateeTokenId);

        int128 baseBias = lastPoint.bias -
            (lastPoint.slope * (block.timestamp - lastCheckpoint).toInt128()) /
            PRECISSION;

        if (!_increase) {
            _delegateeSlopeChanges[delegateeTokenId][endTime] += uSlope;
            lastPoint.bias = uNewBias < baseBias ? baseBias - uNewBias : int128(0);
            lastPoint.slope = uSlope < lastPoint.slope ? lastPoint.slope - uSlope : int128(0);
        } else {
            _delegateeSlopeChanges[delegateeTokenId][endTime] -= uSlope;
            lastPoint.bias = baseBias + uNewBias;
            lastPoint.slope = lastPoint.slope + uSlope;
        }
        /// @dev bias can be rounded up by lack of precision. If slope is 0 we are out
        if (lastPoint.slope == 0) lastPoint.bias = 0;
        _pushStruct(_delegateCheckpoints[delegateeTokenId], lastPoint);
    }

    function _baseCheckpointDelegatee(
        uint256 delegateeTokenId
    ) internal returns (StructCheckpoints.Point memory lastPoint, uint48 lastCheckpoint) {
        (bool exists, uint48 ts, StructCheckpoints.Point memory point) = _delegateCheckpoints[delegateeTokenId]
            .latestCheckpoint();
        lastPoint = point;
        lastCheckpoint = ts;
        if (exists) {
            // Go over weeks to fill history and calculate what the current point is
            uint48 t_i = toGlobalClock(lastCheckpoint);

            while (t_i != block.timestamp) {
                // LMAO Premium solidity dev over here
                t_i += CLOCK_UNIT;
                int128 dSlope = 0;
                if (t_i > block.timestamp) {
                    t_i = uint48(block.timestamp);
                } else {
                    dSlope = _delegateeSlopeChanges[delegateeTokenId][t_i];
                }
                if (dSlope != 0) {
                    console.log(
                        "Last slope %s - Last Bias: %s - Clock() %s",
                        lastPoint.slope.toUint256(),
                        lastPoint.bias.toUint256(),
                        t_i
                    );
                    lastPoint.bias -= ((lastPoint.slope * uint256(t_i - lastCheckpoint).toInt128()) / PRECISSION);
                    lastPoint.slope += dSlope;
                    lastCheckpoint = uint48(t_i);
                    _delegateCheckpoints[delegateeTokenId].push(lastCheckpoint, lastPoint);
                }
            }
        }
    }

    function _push(Checkpoints.Trace208 storage store, uint208 value) private returns (uint208, uint208) {
        return store.push(clock(), value);
    }

    function _pushStruct(
        StructCheckpoints.Trace storage store,
        StructCheckpoints.Point memory value
    ) private returns (StructCheckpoints.Point memory, StructCheckpoints.Point memory) {
        return store.push(clock(), value);
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function supplyAt(uint48 _timestamp) external view returns (int128) {
        return _getAdjustedCheckpoint(_timestamp).bias;
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _timestamp Time to calculate the total voting power at
    /// @return Total voting power at that time
    function _getAdjustedCheckpoint(uint48 _timestamp) internal view returns (StructCheckpoints.Point memory) {
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint48 lastPoint, StructCheckpoints.Point memory lastGlobal) = _globalCheckpoints
            .upperLookupRecent(clockTime);
        if (!exists) return lastGlobal;
        console.log("Global Bias %s - Last Point: %s - Clock() %s", lastGlobal.bias.toUint256(), lastPoint, _timestamp);
        uint48 t_i = toGlobalClock(lastPoint);
        while (t_i != _timestamp) {
            // LMAO sure way to break everything
            t_i += CLOCK_UNIT;
            int128 dSlope = 0;
            if (t_i > _timestamp) {
                t_i = _timestamp;
            } else {
                dSlope = _globalSlopeChanges[t_i];
            }
            if (dSlope != 0) {
                console.log(
                    "Last slope %s - Last Bias: %s - Clock() %s",
                    lastGlobal.slope.toUint256(),
                    lastGlobal.bias.toUint256(),
                    t_i
                );
                lastGlobal.bias -= ((lastGlobal.slope * uint256(t_i - lastPoint).toInt128()) / PRECISSION);
                lastGlobal.slope += dSlope;
                lastPoint = uint48(t_i);
            }
        }
        int128 change = (lastGlobal.slope * uint256(clockTime - lastPoint).toInt128()) / PRECISSION;
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
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint ts, StructCheckpoints.Point memory lastPoint) = _userCheckpoints[_tokenId].upperLookupRecent(
            clockTime
        );
        if (!exists) return 0;
        int128 change = (((lastPoint.slope * (clockTime - ts).toInt128()) / PRECISSION));
        lastPoint.bias = lastPoint.bias < change ? int128(0) : lastPoint.bias - change;
        return lastPoint.bias.toUint256();
    }
}
