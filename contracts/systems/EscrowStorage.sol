// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// TODO:
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
// import {VotingEscrow} from "../VotingEscrow.sol";
import {Votes} from "./Votes.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract EscrowStorage {
    using SafeCast for int256;
    uint256 internal constant EPOCH_DURATION = 1 weeks;

    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAXTIME = 4 * 365 * 86400;

    mapping(uint256 => int128) public slopeChanges;
    mapping(uint256 => IVotingEscrow.GlobalPoint) internal _pointHistory; // epoch -> unsigned global point

    mapping(uint256 => IVotingEscrow.UserPoint[1000000000]) internal _userPointHistory;
    mapping(uint256 => uint256) public userPointEpoch;

    mapping(address => IVotingEscrow.UserPoint[1000000000]) internal _delegatedPointHistory;
    mapping(uint256 => uint256) public delegatedPointEpoch;
    mapping(uint256 tokenId => address) private _delegatee;

    uint256 public permanentLockBalance;
    uint256 public epoch;

    /// @notice Record global and per-user data to checkpoints. Used by VotingEscrow system.
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param _oldLocked Pevious locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpoint(
        uint256 _tokenId,
        IVotingEscrow.LockDetails memory _oldLocked,
        IVotingEscrow.LockDetails memory _newLocked)
        internal {
        IVotingEscrow.UserPoint memory uOld;
        IVotingEscrow.UserPoint memory uNew;
        int128 oldDslope = 0;
        int128 newDslope = 0;
        uint256 _epoch = epoch;

        if (_tokenId != 0) {
            uNew.permanent = _newLocked.isPermanent ? _newLocked.amount : 0;
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (_oldLocked.endTime > block.timestamp && _oldLocked.amount > 0) {
                uOld.slope = int256(_oldLocked.amount / MAXTIME).toInt128();
                uOld.bias = uOld.slope * int256(_oldLocked.endTime - block.timestamp).toInt128();
            }
            if (_newLocked.endTime > block.timestamp && _newLocked.amount > 0) {
                uNew.slope = int256(_newLocked.amount / MAXTIME).toInt128();
                uNew.bias = uNew.slope * int256(_newLocked.endTime - block.timestamp).toInt128();
            }

            // Read values of scheduled changes in the slope
            // _oldLocked.endTime can be in the past and in the future
            // _newLocked.endTime can ONLY by in the FUTURE unless everything expired: than zeros
            oldDslope = slopeChanges[_oldLocked.endTime];
            if (_newLocked.endTime != 0) {
                if (_newLocked.endTime == _oldLocked.endTime) {
                    newDslope = oldDslope;
                } else {
                    newDslope = slopeChanges[_newLocked.endTime];
                }
            }
        }

        IVotingEscrow.GlobalPoint memory lastPoint = IVotingEscrow.GlobalPoint({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number,
            permanentLockBalance: 0
        });
        if (_epoch > 0) {
            lastPoint = _pointHistory[_epoch];
        }
        IVotingEscrow.GlobalPoint memory initialLastPoint = IVotingEscrow.GlobalPoint({
            bias: lastPoint.bias,
            slope: lastPoint.slope,
            ts: lastPoint.ts,
            blk: lastPoint.blk,
            permanentLockBalance: lastPoint.permanentLockBalance
        });
        // If last point is already recorded in this block, slope=0
        // But that's ok b/c we know the block in such case

        // Go over weeks to fill history and calculate what the current point is
        {
            uint256 lastCheckpoint = lastPoint.ts;
            // initialLastPoint is used for extrapolation to calculate block number
            // (approximately, for *At methods) and save them
            // as we cannot figure that out exactly from inside the contract
            uint256 blockSlope = 0; // dblock/dt
            if (block.timestamp > lastPoint.ts) {
                blockSlope = (1 ether * (block.number - lastPoint.blk)) / (block.timestamp - lastPoint.ts);
            }
            uint256 t_i = (lastCheckpoint / EPOCH_DURATION) * EPOCH_DURATION;
            for (uint256 i = 0; i < 255; ++i) {
                // Hopefully it won't happen that this won't get used in 5 years!
                // If it does, users will be able to withdraw but vote weight will be broken
                t_i += EPOCH_DURATION; // Initial value of t_i is always larger than the ts of the last point
                int128 d_slope = 0;
                if (t_i > block.timestamp) {
                    t_i = block.timestamp;
                } else {
                    d_slope = slopeChanges[t_i];
                }
                lastPoint.bias -= lastPoint.slope * int256(t_i - lastCheckpoint).toInt128();
                lastPoint.slope += d_slope;
                if (lastPoint.bias < 0) {
                    // This can happen
                    lastPoint.bias = 0;
                }
                if (lastPoint.slope < 0) {
                    // This cannot happen - just in case
                    lastPoint.slope = 0;
                }
                lastCheckpoint = t_i;
                lastPoint.ts = t_i;
                lastPoint.blk = initialLastPoint.blk + (blockSlope * (t_i - initialLastPoint.ts)) / 1 ether;
                _epoch += 1;
                if (t_i == block.timestamp) {
                    lastPoint.blk = block.number;
                    break;
                } else {
                    _pointHistory[_epoch] = lastPoint;
                }
            }
        }

        if (_tokenId != 0) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            lastPoint.slope += (uNew.slope - uOld.slope);
            lastPoint.bias += (uNew.bias - uOld.bias);
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            lastPoint.permanentLockBalance = permanentLockBalance;
        }

        // If timestamp of last global point is the same, overwrite the last global point
        // Else record the new global point into history
        // Exclude epoch 0 (note: _epoch is always >= 1, see above)
        // Two possible outcomes:
        // Missing global checkpoints in prior weeks. In this case, _epoch = epoch + x, where x > 1
        // No missing global checkpoints, but timestamp != block.timestamp. Create new checkpoint.
        // No missing global checkpoints, but timestamp == block.timestamp. Overwrite last checkpoint.
        if (_epoch != 1 && _pointHistory[_epoch - 1].ts == block.timestamp) {
            // _epoch = epoch + 1, so we do not increment epoch
            _pointHistory[_epoch - 1] = lastPoint;
        } else {
            // more than one global point may have been written, so we update epoch
            epoch = _epoch;
            _pointHistory[_epoch] = lastPoint;
        }

        if (_tokenId != 0) {
            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [_newLocked.endTime]
            // and add old_user_slope to [_oldLocked.endTime]
            if (_oldLocked.endTime > block.timestamp) {
                // oldDslope was <something> - uOld.slope, so we cancel that
                oldDslope += uOld.slope;
                if (_newLocked.endTime == _oldLocked.endTime) {
                    oldDslope -= uNew.slope; // It was a new deposit, not extension
                }
                slopeChanges[_oldLocked.endTime] = oldDslope;
            }

            if (_newLocked.endTime > block.timestamp) {
                // update slope if new lock is greater than old lock and is not permanent or if old lock is permanent
                if ((_newLocked.endTime > _oldLocked.endTime)) {
                    newDslope -= uNew.slope; // old slope disappeared at this point
                    slopeChanges[_newLocked.endTime] = newDslope;
                }
                // else: we recorded it already in oldDslope
            }
            // If timestamp of last user point is the same, overwrite the last user point
            // Else record the new user point into history
            // Exclude epoch 0
            uNew.ts = block.timestamp;
            uNew.blk = block.number;
            uint256 userEpoch = userPointEpoch[_tokenId];
            if (userEpoch != 0 && _userPointHistory[_tokenId][userEpoch].ts == block.timestamp) {
                _userPointHistory[_tokenId][userEpoch] = uNew;
            } else {
                userPointEpoch[_tokenId] = ++userEpoch;
                _userPointHistory[_tokenId][userEpoch] = uNew;
            }
            if (_delegatee[_tokenId] != address(0)) {
                uint256 delegatedEpoch = delegatedPointEpoch[_tokenId];
                address delegateeAddress = _delegatee[_tokenId];
                int128 preBias = _delegatedPointHistory[delegateeAddress][delegatedEpoch].bias - uOld.bias;
                int128 preSlope = _delegatedPointHistory[delegateeAddress][delegatedEpoch].slope - uOld.slope;
                uint256 lastPoint_ = _delegatedPointHistory[delegateeAddress][delegatedEpoch].ts;
                
                int128 baseBias = preBias - (preSlope * int256(lastPoint_ - block.timestamp).toInt128());
                
                _delegatedPointHistory[delegateeAddress][delegatedEpoch].slope = preSlope + uNew.slope;
                _delegatedPointHistory[delegateeAddress][delegatedEpoch].bias = baseBias + uNew.bias;
                _delegatedPointHistory[delegateeAddress][delegatedEpoch].ts = block.timestamp;
                _delegatedPointHistory[delegateeAddress][delegatedEpoch].blk = block.number;
            }
        }
    }
}
