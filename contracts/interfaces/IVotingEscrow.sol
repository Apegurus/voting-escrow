// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

interface IVotingEscrow is IERC5805 {
    struct LockDetails {
        uint256 amount; /// @dev amount of tokens locked
        uint256 startTime; /// @dev when locking started
        uint256 endTime; /// @dev when locking ends
        bool isPermanent; /// @dev if its a permanent lock
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SupplyUpdated(uint256 oldSupply, uint256 newSupply);
    /// @notice Lock events
    event LockCreated(uint256 indexed tokenId, address indexed to, uint256 value, uint256 unlockTime, bool isPermanent);
    event LockUpdated(uint256 indexed tokenId, uint256 value, uint256 unlockTime, bool isPermanent);
    event LockMerged(
        uint256 indexed fromTokenId,
        uint256 indexed toTokenId,
        uint256 totalValue,
        uint256 unlockTime,
        bool isPermanent
    );
    event LockSplit(uint256[] splitWeights, uint256 indexed _tokenId);
    event LockDurationExtended(uint256 indexed tokenId, uint256 newUnlockTime, bool isPermanent);
    event LockAmountIncreased(uint256 indexed tokenId, uint256 value);
    event UnlockPermanent(uint256 indexed tokenId, address indexed sender, uint256 unlockTime);
    /// @notice Delegate events
    event LockDelegateChanged(
        uint256 indexed tokenId,
        address indexed delegator,
        address fromDelegate,
        address indexed toDelegate
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

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
