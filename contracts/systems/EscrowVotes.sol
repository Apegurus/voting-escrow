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

    StructCheckpoints.Trace private _globalCheckpoints;
    // Checkpoints.Trace208 private _totalCheckpointsSlope; // epoch -> unsigned global point

    mapping(uint256 tokenId => Checkpoints.Trace208) private _userCheckpointsBias;
    mapping(uint256 tokenId => Checkpoints.Trace208) private _userCheckpointsSlope;

    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsBias;
    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsSlope;
    mapping(uint256 tokenId => Checkpoints.Trace208) private _delegatee;

    mapping(uint256 => int128) public _slopeChanges;

    // mapping(uint48 checkPoint => uint256 tokenId) private _delegateCheckpointsTokenId;

    // mapping(uint256 => IVotingEscrow.UserPoint[1000000000000]) internal _delegatedPointHistory;
    // mapping(uint256 => uint256) public delegatedPointEpoch;

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
        return (Time.timestamp() / 1 days) * 1 days;
    }

    /**
     * @dev Clock used for flagging global checkpoints.
     */
    function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48) {
        return uint48((_timestamp / 1 days) * 1 days);
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
    /// @param uOldBias Pevious locked amount / end lock time for the user
    /// @param uOldSlope New locked amount / end lock time for the user
    /// @param uNewBias New locked amount / end lock time for the user
    /// @param uNewSlope New locked amount / end lock time for the user
    function _checkpoint(
        uint256 _tokenId,
        int128 uOldBias,
        int128 uOldSlope,
        int128 uNewBias,
        int128 uNewSlope,
        uint256 uOldEndTime,
        uint256 uNewEndTime
    ) internal {
        int128 oldDslope = 0;
        int128 newDslope = 0;

        // Go over weeks to fill history and calculate what the current point is
        _globalCheckpoint(_tokenId, uOldBias, uOldSlope, uNewBias, uNewSlope);

        uOldEndTime = toGlobalClock(uOldEndTime);
        uNewEndTime = toGlobalClock(uNewEndTime);

        if (_tokenId != 0) {
            oldDslope = _slopeChanges[uOldEndTime];
            if (uNewEndTime != 0) {
                if (uNewEndTime == uOldEndTime) {
                    newDslope = oldDslope;
                } else {
                    newDslope = _slopeChanges[uNewEndTime];
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
                _slopeChanges[uOldEndTime] = oldDslope;
                console.log("Pushed slope: %s to change: %s", uOldEndTime);
                console.logInt(oldDslope);
            }

            if (uNewEndTime > block.timestamp) {
                // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
                if ((uNewEndTime > uOldEndTime)) {
                    newDslope -= uNewSlope; // old slope disappeared at this point
                    _slopeChanges[uNewEndTime] = newDslope;
                    console.log("Pushed slope: %s to change: %s", uNewEndTime);
                    console.logInt(newDslope);
                }
                // else: we recorded it already in oldDslope
            }

            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [_newLocked.endTime]
            // and add old_user_slope to [_oldLocked.endTime]
            // if (_oldLocked.endTime > block.timestamp) {
            //     // oldDslope was <something> - uOld.slope, so we cancel that
            //     oldDslope += uOld.slope;
            //     if (_newLocked.endTime == _oldLocked.endTime) {
            //         oldDslope -= uNew.slope; // It was a new deposit, not extension
            //     }
            //     slopeChanges[_oldLocked.endTime] = oldDslope;
            // }

            // if (_newLocked.endTime > block.timestamp) {
            //     // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
            //     if ((_newLocked.endTime > _oldLocked.endTime)) {
            //         newDslope -= uNew.slope; // old slope disappeared at this point
            //         slopeChanges[_newLocked.endTime] = newDslope;
            //     }
            //     // else: we recorded it already in oldDslope
            // }
            // If timestamp of last user point is the same, overwrite the last user point
            // Else record the new user point into history
            // Exclude epoch 0

            // If
            // (, uint lastUserCheckPoint, uint256 lastUserBias) = _userCheckpointsBias[_tokenId].latestCheckpoint();
            // (, , uint256 lastUserSlope) = _userCheckpointsBias[_tokenId].latestCheckpoint();

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
    }

    function _userCheckpoint(uint256 _tokenId, int128 bias, int128 slope) internal {
        _push(_userCheckpointsBias[_tokenId], SafeCast.toUint208(uint128(bias)));
        _push(_userCheckpointsSlope[_tokenId], SafeCast.toUint208(uint128(slope)));
    }

    function _globalCheckpoint(
        uint256 _tokenId,
        int128 uOldBias,
        int128 uOldSlope,
        int128 uNewBias,
        int128 uNewSlope
    ) internal {
        (, uint lastPoint, StructCheckpoints.Point memory lastGlobal) = _globalCheckpoints.latestCheckpoint();
        int128 lastSlope = lastGlobal.slope;
        int128 lastBias = lastGlobal.bias;
        uint lastCheckpoint = lastPoint != 0 ? lastPoint : block.timestamp;

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
                lastBias.toUint256(),
                lastSlope.toUint256()
            );

            int128 preBias = lastBias - uOldBias;
            int128 preSlope = lastSlope - uOldSlope;

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

            lastSlope = preSlope + uNewSlope;
            lastBias = baseBias + uNewBias;
            // TODO: Consider what happens with different indexes
            // _push(_totalCheckpointsSlope, SafeCast.toUint208(lastSlope));
        } else {
            uint t_i = block.timestamp; // Initial value of t_i is always larger than the ts of the last point
            lastBias -= (lastSlope * (t_i - lastCheckpoint).toInt128()) / PRECISSION;
        }

        lastGlobal.slope = lastSlope;
        lastGlobal.bias = lastBias;

        console.log(
            "Ran globalUpdate %s - bias: %s - slope: %s",
            lastPoint,
            lastBias.toUint256(),
            lastSlope.toUint256()
        );

        _pushStruct(_globalCheckpoints, lastGlobal);

        // console.log("New Global Bias %s - New Glognal Slope: %s - Checkpoint: %s", lastBias, lastSlope, clock());

        // If timestamp of last global point is the same, overwrite the last global point
        // Else record the new global point into history
        // Exclude epoch 0 (note: _epoch is always >= 1, see above)
        // Two possible outcomes:
        // Missing global checkpoints in prior weeks. In this case, _epoch = epoch + x, where x > 1
        // No missing global checkpoints, but timestamp != block.timestamp. Create new checkpoint.
        // No missing global checkpoints, but timestamp == block.timestamp. Overwrite last checkpoint.
        // if (epoch != 1 && _pointHistory[epoch - 1].ts == block.timestamp) {
        //     // _epoch = epoch + 1, so we do not increment epoch
        //     _pointHistory[epoch - 1] = lastPoint;
        // } else {
        //     // more than one global point may have been written, so we update epoch
        //     epoch = epoch;
        //     _pointHistory[epoch] = lastPoint;
        // }
    }

    function getVotes(uint256 tokenId) external view override returns (uint256) {}

    /// @notice Retrieves historical voting balance for a token id at a given timestamp.
    /// @dev If a checkpoint does not exist prior to the timestamp, this will return 0.
    ///      The user must also own the token at the time in order to receive a voting balance.
    /// @param _tokenId .
    /// @param _timestamp .
    /// @return votes Total voting balance including delegations at a given timestamp.
    function getPastVotes(uint256 _tokenId, uint256 _timestamp) external view returns (uint256 votes) {
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint ts, uint lastBias) = _delegateCheckpointsBias[_tokenId].upperLookupRecent(clockTime);
        console.log("Clock Time %s - lastBiasUp: %s", clockTime);
        if (!exists) return 0;
        (, , uint lastSlope) = _delegateCheckpointsSlope[_tokenId].upperLookupRecent(clockTime);
        console.log("Last Bias %s - Checkpoint: %s - Clock() %s", lastBias, ts, clock());
        console.log("Last Slope %s - User Time: %s", lastSlope, ts);
        uint change = (((lastSlope * (_timestamp - ts)) / PRECISSION.toUint256()));
        votes = lastBias < change ? 0 : lastBias - change;
        return votes;
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
    function _delegate(uint256 _delegator, uint256 delegatee, int128 uBias, int128 uSlope) internal {
        uint256 currentDelegate = _delegatee[_delegator].latest();
        if (currentDelegate == delegatee) return;

        _checkpointDelegator(_delegator, delegatee, uBias, uSlope);

        // emit DelegateChanged(_msgSender(), currentDelegate, delegatee);
    }

    /// @notice Used by `_mint`, `_transferFrom`, `_burn` and `delegate`
    ///         to update delegator voting checkpoints.
    ///         Automatically dedelegates, then updates checkpoint.
    /// @dev This function depends on `_locked` and must be called prior to token state changes.
    ///      If you wish to dedelegate only, use `_delegate(tokenId, 0)` instead.
    /// @param _delegator The delegator to update checkpoints for
    /// @param delegatee The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead).
    function _checkpointDelegator(uint256 _delegator, uint256 delegatee, int128 uBias, int128 uSlope) internal {
        // (, uint ts, uint uBias) = _userCheckpointsBias[_delegator].latestCheckpoint();
        // (, , uint uSlope) = _userCheckpointsSlope[_delegator].latestCheckpoint();

        // console.log("Last Bias %s - Checkpoint: %s - Clock() %s", uBias, uSlope, clock());
        // console.log("Last Slope %s", uSlope);
        // uBias -= ((uSlope * (block.timestamp - ts)) / PRECISSION);
        // if (uBias < 0) {
        //     uBias = 0;
        // }

        // Dedelegate from delegatee if delegated
        uint256 oldDelegatee = _delegatee[_delegator].latest();
        console.log("Old Delegatee %s - Ubias: %s - uSlope: %s", oldDelegatee, uBias.toUint256(), uSlope.toUint256());
        if (oldDelegatee != delegatee && oldDelegatee != 0) _checkpointDelegatee(oldDelegatee, uBias, uSlope, false);
        // Delegate to new delegator
        _checkpointDelegatee(delegatee, uBias, uSlope, true);
        _push(_delegatee[_delegator], SafeCast.toUint208(delegatee));
        // checkpoint();
        _globalCheckpoint(0, 0, 0, 0, 0);
    }

    /// @notice Update delegatee's `delegatedBalance` by `balance`.
    ///         Only updates if delegating to a new delegatee.
    /// @dev If used with `balance` == `_locked[_tokenId].amount`, then this is the same as
    ///      delegating or dedelegating from `_tokenId`
    ///      If used with `balance` < `_locked[_tokenId].amount`, then this is used to adjust
    ///      `delegatedBalance` when a user's balance is modified (e.g. `increaseAmount`, `merge` etc).
    ///      If `delegatee` is 0 (i.e. user is not delegating), then do nothing.
    function _checkpointDelegatee(uint256 delegateeTokenId, int128 uNewBias, int128 uSlope, bool _increase) internal {
        // if (delegateeTokenId == 0) return;
        (, uint ts, uint lastBias) = _delegateCheckpointsBias[delegateeTokenId].latestCheckpoint();
        (, , uint lastSlope) = _delegateCheckpointsSlope[delegateeTokenId].latestCheckpoint();
        console.log("ts %s - lastBias: %s - lastSlope: %s", ts, lastBias, lastSlope);

        // TODO: Need to round down this
        uint256 baseBias = lastBias - (lastSlope * (block.timestamp - ts)) / PRECISSION.toUint256();
        // console.log("ts %s - baseBias: %s - uNewBias: %s", _increase, baseBias, uNewBias);
        int128 pushBias = baseBias.toInt128() + uNewBias;
        int128 pushSlope = lastSlope.toInt128() + uSlope;
        if (!_increase) {
            pushBias = uNewBias < baseBias.toInt128() ? baseBias.toInt128() - uNewBias : int128(0);
            pushSlope = uSlope < lastSlope.toInt128() ? lastSlope.toInt128() - uSlope : int128(0);
        }
        /// @dev bias can be rounded up by lack of precision. If slope is 0 we are out
        if (pushSlope == 0) pushBias = 0;
        _push(_delegateCheckpointsBias[delegateeTokenId], SafeCast.toUint208(uint128(pushBias)));
        _push(_delegateCheckpointsSlope[delegateeTokenId], SafeCast.toUint208(uint128(pushSlope)));

        // _globalCheckpoint(delegateeTokenId, lastBias, lastSlope, pushBias, pushSlope);
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
    function supplyAt(uint256 _timestamp) external view returns (int128) {
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint48 lastPoint, StructCheckpoints.Point memory lastGlobal) = _globalCheckpoints
            .upperLookupRecent(clockTime);
        if (!exists) return 0;
        int128 lastBias = lastGlobal.bias;
        int128 slope = lastGlobal.slope;
        console.log("Global Bias %s - Last Point: %s - Clock() %s", lastBias.toUint256(), lastPoint, _timestamp);
        uint256 t_i = toGlobalClock(lastPoint);
        while (true) {
            // LMAO
            // Iterates over a max of 255 weeks
            t_i += 1 days;
            int128 dSlope = 0;
            if (t_i > _timestamp) {
                t_i = _timestamp;
            } else {
                dSlope = _slopeChanges[t_i];
            }
            if (dSlope != 0) {
                console.log("Last slope %s - Last Bias: %s - Clock() %s", slope.toUint256(), lastBias.toUint256(), t_i);
                lastBias -= ((slope * (t_i - lastPoint).toInt128()) / PRECISSION);
                slope += dSlope;
                lastPoint = uint48(t_i);
            }
            if (t_i == _timestamp) {
                break;
            }
        }
        console.log("Timestamp %s - Last Point: %s - Last check %s", clockTime, lastPoint, t_i);
        int128 change = (slope * uint256(clockTime - lastPoint).toInt128()) / PRECISSION;
        lastBias = lastBias < change ? int128(0) : lastBias - change;

        return lastBias;
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    ///      Fetches last user point prior to a certain timestamp, then walks forward to timestamp.
    /// @param _tokenId NFT for lock
    /// @param _timestamp Epoch time to return voting power at
    /// @return User voting power
    function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        uint48 clockTime = SafeCast.toUint48(_timestamp);
        (bool exists, uint ts, uint lastBias) = _userCheckpointsBias[_tokenId].upperLookupRecent(clockTime);
        // console.log("Clock Time %s - lastBiasUp: %s", clockTime);
        if (!exists) return 0;
        (, , uint lastSlope) = _userCheckpointsSlope[_tokenId].upperLookupRecent(clockTime);
        console.log("Last Bias %s - Checkpoint: %s - Clock() %s", lastBias, ts, clock());
        console.log("Last Slope %s - User Time: %s", lastSlope, _timestamp);
        uint change = (((lastSlope * (clockTime - ts)) / PRECISSION.toUint256()));
        lastBias = lastBias < change ? 0 : lastBias - change;
        return lastBias;
    }
}
