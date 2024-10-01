// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVotes} from "./IVotes.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import {IVersionable} from "./IVersionable.sol";

/**
 * @title Voting Escrow V2 Interface for Upgrades
 */
interface IVotingEscrowV2 is IVotes, IERC721EnumerableUpgradeable, IVersionable {
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
    error InvalidWeights();
    error LockDurationNotInFuture();
    error LockDurationTooLong();
    error LockExpired();
    error LockNotExpired();
    error LockHoldsValue();
    error LockModifiedDelay();
    error NotPermanentLock();
    error PermanentLock();
    error PermanentLockMismatch();
    error SameNFT();
    error SignatureExpired();
    error ZeroAmount();
    error NotLockOwner();

    function supply() external view returns (uint);

    function token() external view returns (IERC20Upgradeable);

    function totalNftsMinted() external view returns (uint256);

    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);

    function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256);

    function delegates(uint256 tokenId, uint48 timestamp) external view returns (address);

    function lockDetails(uint256 tokenId) external view returns (LockDetails calldata);

    function isApprovedOrOwner(address user, uint tokenId) external view returns (bool);

    function getPastEscrowPoint(
        uint256 _tokenId,
        uint256 _timePoint
    ) external view returns (Checkpoints.Point memory, uint48);

    function getFirstEscrowPoint(uint256 _tokenId) external view returns (Checkpoints.Point memory, uint48);

    function checkpoint() external;

    function increaseAmount(uint256 _tokenId, uint256 _value) external;

    function createLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to,
        bool _permanent
    ) external returns (uint256);

    function createDelegatedLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to,
        address _delegatee,
        bool _permanent
    ) external returns (uint256);

    function split(uint256[] memory _weights, uint256 _tokenId) external;

    function merge(uint256 _from, uint256 _to) external;

    function burn(uint256 _tokenId) external;

    function decimals() external view returns (uint8);
}
