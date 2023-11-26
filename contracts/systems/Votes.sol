// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/utils/Votes.sol)
pragma solidity ^0.8.20;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {IVotes} from "../interfaces/IVotes.sol";

/**
 * @dev This is a base abstract contract that tracks voting units, which are a measure of voting power that can be
 * transferred, and provides a system of vote delegation, where an tokenId can delegate its voting units to a sort of
 * "representative" that will pool delegated voting units from different tokenIds and can then use it to vote in
 * decisions. In fact, voting units _must_ be delegated in order to count as actual votes, and an tokenId has to
 * delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
 *
 * The full history of delegate votes is tracked on-chain so that governance protocols can consider votes as distributed
 * at a particular block number to protect against flash loans and double voting. The opt-in delegate system makes the
 * cost of this history tracking optional.
 *
 * When using this module the derived contract must implement {_getVotingUnits} (for example, make it return
 * {ERC721-balanceOf}), and can use {_transferVotingUnits} to track a change in the distribution of those units (in the
 * previous example, it would be included in {ERC721-_update}).
 */
abstract contract Votes is Context, EIP712, Nonces, IVotes {
    using Checkpoints for Checkpoints.Trace208;

    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(uint256 tokenId => uint256) private _delegatee;

    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsBias;
    mapping(uint256 delegatee => Checkpoints.Trace208) private _delegateCheckpointsSlope;

    Checkpoints.Trace208 private _totalCheckpointsBias;
    Checkpoints.Trace208 private _totalCheckpointsSlope;

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

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(uint256 tokenId) public view virtual returns (uint256) {
        return _delegateCheckpointsBias[tokenId].latest();
    }

    /**
     * @dev Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastVotes(uint256 tokenId, uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return _delegateCheckpointsBias[tokenId].upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    /**
     * @dev Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastTotalSupply(uint256 timepoint) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return _totalCheckpointsBias.upperLookupRecent(SafeCast.toUint48(timepoint));
    }

    /**
     * @dev Returns the current total supply of votes.
     */
    function _getTotalSupply() internal view virtual returns (uint256) {
        return _totalCheckpointsBias.latest();
    }

    /**
     * @dev Returns the delegate that `account` has chosen.
     */
    function delegates(uint256 account) public view virtual returns (uint256) {
        return _delegatee[account];
    }

    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(uint256 delegator, uint256 delegatee) public virtual {
        _delegate(delegator, delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function delegateBySig(
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        // TODO: Dig into this one
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        _useCheckedNonce(signer, nonce);
        _delegate(delegator, delegatee);
    }

    /**
     * @dev Delegate all of `account`'s voting units to `delegatee`.
     *
     * Emits events {IVotes-DelegateChanged} and {IVotes-DelegateVotesChanged}.
     */
    function _delegate(uint256 delegator, uint256 delegatee) internal virtual {
        uint256 oldDelegate = delegates(delegator);
        _delegatee[delegator] = delegatee;

        emit DelegateChanged(_msgSender(), oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, _getVotingUnits(delegator));
    }

    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     */
    function _transferVotingUnits(uint256 from, uint256 to, uint256 amount) internal virtual {
        if (from == 0) {
            _push(_totalCheckpointsBias, _add, SafeCast.toUint208(amount));
        }
        if (to == 0) {
            _push(_totalCheckpointsBias, _subtract, SafeCast.toUint208(amount));
        }
        _moveDelegateVotes(delegates(from), delegates(to), amount);
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     */
    function _moveDelegateVotes(uint256 from, uint256 to, uint256 amount) private {
        if (from != to && amount > 0) {
            if (from != 0) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpointsBias[from],
                    _subtract,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(from, oldValue, newValue);
            }
            if (to != 0) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpointsBias[to],
                    _add,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(to, oldValue, newValue);
            }
        }
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function _numCheckpoints(uint256 tokenId) internal view virtual returns (uint32) {
        return SafeCast.toUint32(_delegateCheckpointsBias[tokenId].length());
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function _checkpoints(
        uint256 tokenId,
        uint32 pos
    ) internal view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _delegateCheckpointsBias[tokenId].at(pos);
    }

    function _push(
        Checkpoints.Trace208 storage store,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    ) private returns (uint208, uint208) {
        return store.push(clock(), op(store.latest(), delta));
    }

    function _add(uint208 a, uint208 b) private pure returns (uint208) {
        return a + b;
    }

    function _subtract(uint208 a, uint208 b) private pure returns (uint208) {
        return a - b;
    }

    /**
     * @dev Must return the voting units held by an account.
     */
    function _getVotingUnits(uint256) internal view virtual returns (uint256);
}
