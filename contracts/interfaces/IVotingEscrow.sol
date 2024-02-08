// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {Checkpoints} from "../libraries/Checkpoints.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IVotingEscrow is IERC5805, IERC721Enumerable {
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
    error PermanentLockMismatch();
    error SameNFT();
    error SignatureExpired();
    error ZeroAmount();

    function supply() external view returns (uint);

    function token() external view returns (IERC20);

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

    function createLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to,
        bool _permanent
    ) external returns (uint256);

    function increaseAmount(uint256 _tokenId, uint256 _value) external;
}
