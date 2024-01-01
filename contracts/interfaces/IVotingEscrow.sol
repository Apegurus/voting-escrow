// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

interface IVotingEscrow is IERC5805 {
    struct LockDetails {
        int128 amount; /// @dev amount of tokens locked
        uint256 startTime; /// @dev when locking started
        uint256 endTime; /// @dev when locking ends
        bool isPermanent; /// @dev if its a permanent lock
    }

    error AlreadyVoted();
    error InvalidNonce();
    error InvalidDelegatee();
    error InvalidSignature();
    error InvalidSignatureS();
    error LockDurationNotInFuture();
    error LockDurationTooLong();
    error LockExpired();
    error LockNotExpired();
    error NoLockFound();
    error NotPermanentLock();
    error PermanentLock();
    error SameNFT();
    error SignatureExpired();
    error ZeroAmount();
}
