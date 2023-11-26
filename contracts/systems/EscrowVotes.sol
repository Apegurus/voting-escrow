// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// TODO:
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IVotes} from "../interfaces/IVotes.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {BalanceLogicLibrary} from "../libraries/BalanceLogicLibrary.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract EscrowVotes is IVotes, ReentrancyGuard {
    using Checkpoints for Checkpoints.Trace208;
    using SafeCast for int256;

    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAXTIME = 2 * 365 * 86400;
    uint256 internal constant PRECISSION = 1e12;

    Checkpoints.Trace208 private _totalCheckpointsBias;
    Checkpoints.Trace208 private _totalCheckpointsSlope; // epoch -> unsigned global point

    mapping(uint256 tokenId => Checkpoints.Trace208) private _userCheckpointsBias;
    mapping(uint256 tokenId => Checkpoints.Trace208) private _userCheckpointsSlope;

    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsBias;
    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsSlope;
    mapping(uint256 tokenId => uint256) private _delegatee;

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
     * @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based
     * checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
     */
    function clock() public view virtual returns (uint48) {
        return Time.timestamp();
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

    function checkpoint() public nonReentrant {
        _checkpoint(0, IVotingEscrow.LockDetails(0, 0, 0, false), IVotingEscrow.LockDetails(0, 0, 0, false));
    }

    /// @notice Record global and per-user data to checkpoints. Used by VotingEscrow system.
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param _oldLocked Pevious locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpoint(
        uint256 _tokenId,
        IVotingEscrow.LockDetails memory _oldLocked,
        IVotingEscrow.LockDetails memory _newLocked
    ) internal {
        uint uOldBias;
        uint uOldSlope;
        uint uNewBias;
        uint uNewSlope;
        console.log("Running checkpoint %s from %s to %s okens", _tokenId, _newLocked.amount);

        if (_tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (_oldLocked.endTime > block.timestamp && _oldLocked.amount > 0) {
                console.log("1 End Time %s -- Diff %s", _oldLocked.endTime, _oldLocked.endTime - block.timestamp);
                uOldSlope = (_oldLocked.amount * PRECISSION) / MAXTIME;
                uOldBias = (uOldSlope * (_oldLocked.endTime - block.timestamp)) / PRECISSION;
                console.log("2 testBias %s -- testSlope %s", uOldSlope, uOldBias);
            }
            if (_newLocked.endTime > block.timestamp && _newLocked.amount > 0) {
                console.log("2 End Time %s -- Diff %s", _newLocked.endTime, _newLocked.endTime - block.timestamp);
                uNewSlope = (_newLocked.amount * PRECISSION) / MAXTIME;
                uNewBias = (uNewSlope * (_newLocked.endTime - block.timestamp)) / PRECISSION;
                console.log("2 testBias %s -- testSlope %s", uNewBias, uNewSlope);
            }
        }

        // If last point is already recorded in this block, slope=0
        // But that's ok b/c we know the block in such case

        // Go over weeks to fill history and calculate what the current point is
        {
            (, uint lastPoint, uint lastBias) = _totalCheckpointsBias.latestCheckpoint();
            uint256 lastSlope = _totalCheckpointsSlope.latest();
            uint lastCheckpoint = lastPoint != 0 ? lastPoint : block.timestamp;

            console.log("Running checkpoint %s from %s to %s okens", lastPoint, _tokenId, _newLocked.amount);

            if (_tokenId != 0) {
                console.log("Running globalUpdate %s - bias: %s - slope: %s", lastPoint, lastBias, lastSlope);
                // If last point was in this block, the slope change has been applied already
                // But in such case we have 0 slope(s)
                uint preBias = lastBias - uOldBias;
                uint preSlope = lastSlope - uOldSlope;

                console.log("Running globalUpdate %s - preBias: %s - preSlope: %s", block.timestamp, preBias, preSlope);
                uint baseBias = preBias - ((preSlope * (block.timestamp - lastCheckpoint)) / PRECISSION);

                console.log("Running newSlope %s - baseBias: %s - newBias: %s", uNewSlope, baseBias, uNewBias);

                lastSlope = preSlope + uNewSlope;
                lastBias = baseBias + uNewBias;
            } else {
                uint t_i = block.timestamp; // Initial value of t_i is always larger than the ts of the last point
                lastBias -= ((lastSlope * (t_i - lastCheckpoint)) / PRECISSION);
            }

            _push(_totalCheckpointsBias, SafeCast.toUint208(lastBias));
            _push(_totalCheckpointsSlope, SafeCast.toUint208(lastSlope));

            console.log("New Global Bias %s - New Glognal Slope: %s - Checkpoint: %s", lastBias, lastSlope, clock());

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

        if (_tokenId != 0) {
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

            (, uint lastUserCheckPoint, ) = _userCheckpointsBias[_tokenId].latestCheckpoint();
            _push(_userCheckpointsBias[_tokenId], SafeCast.toUint208(uNewBias));
            _push(_userCheckpointsSlope[_tokenId], SafeCast.toUint208(uNewSlope));

            if (_delegatee[_tokenId] != 0) {
                uint256 delegateeTokenId = _delegatee[_tokenId];
                (, uint ts, uint lastBias) = _delegateCheckpointsBias[delegateeTokenId].latestCheckpoint();
                bool delegationExistedInThePast = ts <= lastUserCheckPoint;

                (, , uint lastSlope) = _delegateCheckpointsSlope[delegateeTokenId].latestCheckpoint();
                uint256 preBias = delegationExistedInThePast ? lastBias - uOldBias : lastBias;
                uint256 preSlope = delegationExistedInThePast ? lastSlope - uOldSlope : lastSlope;
                uint256 lastPoint_ = ts;

                uint256 baseBias = preBias - (preSlope * (lastPoint_ - block.timestamp)) / PRECISSION;

                _push(_delegateCheckpointsBias[delegateeTokenId], SafeCast.toUint208(baseBias + uNewBias));
                _push(_delegateCheckpointsSlope[delegateeTokenId], SafeCast.toUint208(preSlope + uNewSlope));
            }
        }
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
        console.log("Last Slope %s - User Time: %s", lastSlope, _timestamp);
        votes = lastBias - ((lastSlope * (_timestamp - ts)) / PRECISSION);
        if (votes < 0) {
            votes = 0;
        }
        return votes;
    }

    function getPastTotalSupply(uint256 timepoint) external view override returns (uint256) {}

    function delegates(uint256 tokenId) external view override returns (uint256) {
        return _delegatee[tokenId];
    }

    function delegate(uint256 delegator, uint256 delegatee) external override {
        return _delegate(delegator, delegatee);
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
    function _delegate(uint256 _delegator, uint256 delegatee) internal {
        uint256 currentDelegate = _delegatee[_delegator];
        if (currentDelegate == delegatee) return;

        _checkpointDelegator(_delegator, delegatee);

        // emit DelegateChanged(_msgSender(), currentDelegate, delegatee);
    }

    /// @notice Used by `_mint`, `_transferFrom`, `_burn` and `delegate`
    ///         to update delegator voting checkpoints.
    ///         Automatically dedelegates, then updates checkpoint.
    /// @dev This function depends on `_locked` and must be called prior to token state changes.
    ///      If you wish to dedelegate only, use `_delegate(tokenId, 0)` instead.
    /// @param _delegator The delegator to update checkpoints for
    /// @param delegatee The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead).
    function _checkpointDelegator(uint256 _delegator, uint256 delegatee) internal {
        (, uint ts, uint uBias) = _userCheckpointsBias[_delegator].latestCheckpoint();
        (, , uint uSlope) = _userCheckpointsSlope[_delegator].latestCheckpoint();

        console.log("Last Bias %s - Checkpoint: %s - Clock() %s", uBias, ts, clock());
        console.log("Last Slope %s", uSlope);
        uBias -= ((uSlope * (block.timestamp - ts)) / PRECISSION);
        if (uBias < 0) {
            uBias = 0;
        }

        // Dedelegate from delegatee if delegated
        uint256 oldDelegatee = _delegatee[_delegator];
        console.log("Old Delegatee %s - Ubias: %s - uSlope: %s", oldDelegatee, uBias, uSlope);
        if (oldDelegatee != delegatee && oldDelegatee != 0) checkpointDelegatee(oldDelegatee, uBias, uSlope, false);
        // Delegate to new delegator
        checkpointDelegatee(delegatee, uBias, uSlope, true);
        _delegatee[_delegator] = delegatee;
        checkpoint();
    }

    /// @notice Update delegatee's `delegatedBalance` by `balance`.
    ///         Only updates if delegating to a new delegatee.
    /// @dev If used with `balance` == `_locked[_tokenId].amount`, then this is the same as
    ///      delegating or dedelegating from `_tokenId`
    ///      If used with `balance` < `_locked[_tokenId].amount`, then this is used to adjust
    ///      `delegatedBalance` when a user's balance is modified (e.g. `increaseAmount`, `merge` etc).
    ///      If `delegatee` is 0 (i.e. user is not delegating), then do nothing.
    function checkpointDelegatee(uint256 delegateeTokenId, uint256 uNewBias, uint256 uSlope, bool _increase) public {
        // if (delegateeTokenId == 0) return;
        (, uint ts, uint lastBias) = _delegateCheckpointsBias[delegateeTokenId].latestCheckpoint();
        (, , uint lastSlope) = _delegateCheckpointsSlope[delegateeTokenId].latestCheckpoint();
        console.log("ts %s - lastBias: %s - lastSlope: %s", ts, lastSlope, lastBias);

        // TODO: Need to round down this
        uint256 baseBias = lastBias - ((lastSlope / PRECISSION)) * (block.timestamp - ts);

        _push(
            _delegateCheckpointsBias[delegateeTokenId],
            SafeCast.toUint208(_increase ? baseBias + uNewBias : baseBias - uNewBias)
        );
        _push(
            _delegateCheckpointsSlope[delegateeTokenId],
            SafeCast.toUint208(_increase ? lastSlope + uSlope : lastSlope - uSlope)
        );
    }

    function _push(Checkpoints.Trace208 storage store, uint208 value) private returns (uint208, uint208) {
        return store.push(clock(), value);
    }

    // function _supplyAt(uint256 _timestamp) internal view returns (uint256) {
    //     return BalanceLogicLibrary.supplyAt(slopeChanges, _pointHistory, epoch, _timestamp);
    // }

    /// @notice Calculate total voting power at some point in the past
    /// @param _t Time to calculate the total voting power at
    /// @return Total voting power at that time
    function supplyAt(uint256 _t) external view returns (uint256) {
        uint48 clockTime = SafeCast.toUint48(_t);
        console.log("Clock Time %s - lastBiasUp: %s", clockTime);
        (bool exists, uint ts, uint lastBias) = _totalCheckpointsBias.upperLookupRecent(clockTime);
        console.log("Global Bias %s - Checkpoint: %s - Clock() %s", lastBias, ts, clock());
        if (!exists) return 0;
        (, , uint slope) = _totalCheckpointsSlope.upperLookupRecent(clockTime);
        console.log("Global Slo[e] %s - Checkpoint: %s - Clock() %s", slope, ts, clock());
        uint bias = lastBias;
        bias -= ((slope * (clockTime - ts)) / PRECISSION);

        if (bias < 0) {
            bias = 0;
        }

        return bias;
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
        console.log("Clock Time %s - lastBiasUp: %s", clockTime);
        if (!exists) return 0;
        (, , uint lastSlope) = _userCheckpointsSlope[_tokenId].upperLookupRecent(clockTime);
        console.log("Last Bias %s - Checkpoint: %s - Clock() %s", lastBias, ts, clock());
        console.log("Last Slope %s - User Time: %s", lastSlope, _timestamp);
        lastBias -= ((lastSlope * (_timestamp - ts)) / PRECISSION);
        if (lastBias < 0) {
            lastBias = 0;
        }
        return lastBias;
    }
}
