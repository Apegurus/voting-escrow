// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721Enumerable, IERC165} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC5725} from "./erc5725/ERC5725.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
/// @dev Importing IERC5805, IERC6372, and IVotes directly to add override defectives
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {SafeCastLibrary} from "./libraries/SafeCastLibrary.sol";
import {Time} from "./libraries/Time.sol";

import {EscrowDelegateCheckpoints, Checkpoints} from "./libraries/EscrowDelegateCheckpoints.sol";
import {EscrowDelegateStorage} from "./libraries/EscrowDelegateStorage.sol";

/**
 * @title VotingEscrow
 * @dev This contract is used for locking tokens and voting.
 *
 * - tokenIds always have a delegatee, with the owner being the default (see createLock)
 * - On transfers, delegation is reset. (See _update)
 * -
 */
contract VotingEscrow is EscrowDelegateStorage, ERC5725, ReentrancyGuard, IVotingEscrow, EIP712 {
    using SafeERC20 for IERC20;
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;
    using EscrowDelegateCheckpoints for EscrowDelegateCheckpoints.EscrowDelegateStore;

    /// @notice The token being locked
    IERC20 public _token;
    /// @notice Total locked supply
    uint256 public supply;

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /// @dev OpenZeppelin v5 IVotes error
    error VotesExpiredSignature(uint256 expiry);

    /**
     * @dev Initializes the contract by setting a `name`, `symbol`, `version` and `mainToken`.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory version,
        IERC20 mainToken
    ) ERC721(_name, _symbol) EIP712(_name, version) {
        _token = mainToken;
    }

    modifier checkAuthorized(uint256 _tokenId) {
        address owner = _ownerOf(_tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        address sender = _msgSender();
        if (!_isAuthorized(owner, sender, _tokenId)) {
            revert ERC721InsufficientApproval(sender, _tokenId);
        }
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC5725, IERC165) returns (bool supported) {
        return interfaceId == type(IVotingEscrow).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-_beforeTokenTransfer}.
     * Clears the approval of a given `tokenId` when the token is transferred or burned.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            uint256 tokenId = firstTokenId + i;
            if (from != to) {
                /// @dev Sets delegatee to new owner on transfers
                (address oldDelegatee, address newDelegatee) = edStore.delegate(
                    tokenId,
                    to,
                    _lockDetails[tokenId].endTime
                );
                emit DelegateChanged(to, oldDelegatee, newDelegatee);
                emit LockDelegateChanged(tokenId, to, oldDelegatee, newDelegatee);
            }
        }
    }

    /**
     * ERC-5725 and token-locking logic
     */

    /// @notice maps the vesting data with tokenIds
    mapping(uint256 => LockDetails) public _lockDetails;

    /// @notice tracker of current NFT id
    uint256 public totalNftsMinted = 0;

    /**
     * @notice Creates a new vesting NFT and mints it
     * @dev Token amount should be approved to be transferred by this contract before executing create
     * @param value The total assets to be locked over time
     * @param duration Duration in seconds of the lock
     * @param to The receiver of the lock
     */
    function _createLock(
        uint256 value,
        uint256 duration,
        address to,
        address delegatee,
        bool permanent
    ) internal virtual returns (uint256) {
        if (value == 0) revert ZeroAmount();
        uint256 unlockTime;
        totalNftsMinted++;
        uint256 newTokenId = totalNftsMinted;
        if (!permanent) {
            unlockTime = toGlobalClock(block.timestamp + duration); // Locktime is rounded down to global clock (days)
            if (unlockTime <= block.timestamp) revert LockDurationNotInFuture();
            if (unlockTime > block.timestamp + MAX_TIME) revert LockDurationTooLong();
        }

        _mint(to, newTokenId);
        _lockDetails[newTokenId].startTime = block.timestamp;
        /// @dev Checkpoint created in _updateLock
        _updateLock(newTokenId, value, unlockTime, _lockDetails[newTokenId], permanent);
        edStore.delegate(newTokenId, delegatee, unlockTime);
        emit LockCreated(newTokenId, delegatee, value, unlockTime, permanent);
        emit DelegateChanged(to, address(0), delegatee);
        emit LockDelegateChanged(newTokenId, to, address(0), delegatee);
        return newTokenId;
    }

    /**
     * @notice Creates a lock for the sender
     * @param _value The total assets to be locked over time
     * @param _lockDuration Duration in seconds of the lock
     * @param _permanent Whether the lock is permanent or not
     * @return The id of the newly created token
     */
    function createLock(
        uint256 _value,
        uint256 _lockDuration,
        bool _permanent
    ) external nonReentrant returns (uint256) {
        return _createLock(_value, _lockDuration, _msgSender(), _msgSender(), _permanent);
    }

    /**
     * @notice Creates a lock for a specified address
     * @param _value The total assets to be locked over time
     * @param _lockDuration Duration in seconds of the lock
     * @param _to The receiver of the lock
     * @param _permanent Whether the lock is permanent or not
     * @return The id of the newly created token
     */
    function createLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to,
        bool _permanent
    ) external nonReentrant returns (uint256) {
        return _createLock(_value, _lockDuration, _to, _to, _permanent);
    }

    /**
     * @notice Creates a lock for a specified address
     * @param _value The total assets to be locked over time
     * @param _lockDuration Duration in seconds of the lock
     * @param _to The receiver of the lock
     * @param _delegatee The receiver of the lock
     * @param _permanent Whether the lock is permanent or not
     * @return The id of the newly created token
     */
    function createDelegatedLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to,
        address _delegatee,
        bool _permanent
    ) external nonReentrant returns (uint256) {
        return _createLock(_value, _lockDuration, _to, _delegatee, _permanent);
    }

    /**
     * @notice Updates the global checkpoint
     */
    function globalCheckpoint() public nonReentrant {
        return edStore.globalCheckpoint();
    }

    function checkpoint() external override {
        globalCheckpoint();
    }

    /**
     * @notice Updates the checkpoint for a delegatee
     * @param _delegateeAddress The address of the delegatee
     */
    function checkpointDelegatee(address _delegateeAddress) external nonReentrant {
        edStore.baseCheckpointDelegatee(_delegateeAddress);
    }

    /// @notice Deposit & update lock tokens for a user
    /// @dev The supply is increased by the _value amount
    /// @param _tokenId NFT that holds lock
    /// @param _increasedValue Amount to deposit
    /// @param _unlockTime New time when to unlock the tokens, or 0 if unchanged
    /// @param _oldLocked Previous locked amount / timestamp
    function _updateLock(
        uint256 _tokenId,
        uint256 _increasedValue,
        uint256 _unlockTime,
        LockDetails memory _oldLocked,
        bool isPermanent
    ) internal {
        uint256 supplyBefore = supply;
        supply += _increasedValue;

        // Set newLocked to _oldLocked without mangling memory
        LockDetails memory newLocked;
        (newLocked.amount, newLocked.startTime, newLocked.endTime, newLocked.isPermanent) = (
            _oldLocked.amount,
            _oldLocked.startTime,
            _oldLocked.endTime,
            _oldLocked.isPermanent
        );

        // Adding to existing lock, or if a lock is expired - creating a new one
        newLocked.amount += _increasedValue;
        if (_unlockTime != 0 && !isPermanent) {
            newLocked.endTime = _unlockTime;
        }
        if (isPermanent) {
            newLocked.endTime = 0;
            newLocked.isPermanent = true;
        }
        _lockDetails[_tokenId] = newLocked;
        emit LockUpdated(_tokenId, _increasedValue, _unlockTime, isPermanent);

        // Possibilities:
        // Both _oldLocked.end could be current or expired (>/< block.timestamp)
        // or if the lock is a permanent lock, then _oldLocked.end == 0
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // newLocked.end > block.timestamp (always)
        _checkpointLock(_tokenId, _oldLocked, newLocked);

        if (_increasedValue != 0) {
            _token.safeTransferFrom(_msgSender(), address(this), _increasedValue);
        }

        emit SupplyUpdated(supply, supplyBefore + _increasedValue);
    }

    /// @notice Record global and per-user data to checkpoints. Used by VotingEscrow system.
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param _oldLocked Previous locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpointLock(
        uint256 _tokenId,
        IVotingEscrow.LockDetails memory _oldLocked,
        IVotingEscrow.LockDetails memory _newLocked
    ) internal {
        edStore.checkpoint(
            _tokenId,
            _oldLocked.amount.toInt128(),
            _newLocked.amount.toInt128(),
            _oldLocked.endTime,
            _newLocked.endTime
        );
    }

    /// @notice Deposit `_value` tokens for `_tokenId` and add to the lock
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    ///      cannot extend their locktime and deposit for a brand new user
    /// @param _tokenId lock NFT
    /// @param _value Amount to add to user's lock
    function increaseAmount(uint256 _tokenId, uint256 _value) external nonReentrant {
        if (_value == 0) revert ZeroAmount();

        IVotingEscrow.LockDetails memory oldLocked = _lockDetails[_tokenId];
        if (oldLocked.amount <= 0) revert NoLockFound();
        if (oldLocked.endTime <= block.timestamp && !oldLocked.isPermanent) revert LockExpired();

        _updateLock(_tokenId, _value, 0, oldLocked, oldLocked.isPermanent);
    }

    /**
     * @notice Increases the unlock time of a lock
     * @param _tokenId The id of the token to increase the unlock time for
     * @param _lockDuration The new duration of the lock
     * @param _permanent Whether the lock is permanent or not
     */
    function increaseUnlockTime(
        uint256 _tokenId,
        uint256 _lockDuration,
        bool _permanent
    ) external nonReentrant checkAuthorized(_tokenId) {
        LockDetails memory oldLocked = _lockDetails[_tokenId];
        if (oldLocked.isPermanent) revert PermanentLock();

        uint256 unlockTime;
        if (!_permanent) {
            unlockTime = toGlobalClock(block.timestamp + _lockDuration);
            // Locktime is rounded down to global clock (days)
            if (oldLocked.endTime <= block.timestamp) revert LockExpired();
            if (unlockTime <= oldLocked.endTime) revert LockDurationNotInFuture();
            if (unlockTime > block.timestamp + MAX_TIME) revert LockDurationTooLong();
        }

        _updateLock(_tokenId, 0, unlockTime, oldLocked, _permanent);
        emit LockDurationExtended(_tokenId, unlockTime, _permanent);
    }

    /**
     * @notice Unlocks a permanent lock
     * @param _tokenId The id of the token to unlock
     */
    function unlockPermanent(uint256 _tokenId) external nonReentrant checkAuthorized(_tokenId) {
        LockDetails memory newLocked = _lockDetails[_tokenId];
        if (!newLocked.isPermanent) revert NotPermanentLock();

        // Set the end time to the maximum possible time
        newLocked.endTime = toGlobalClock(block.timestamp + MAX_TIME);
        // Set the lock to not be permanent
        newLocked.isPermanent = false;

        // Update the lock details
        _checkpointLock(_tokenId, _lockDetails[_tokenId], newLocked);
        _lockDetails[_tokenId] = newLocked;

        emit UnlockPermanent(_tokenId, _msgSender(), newLocked.endTime);
    }

    /**
     * @notice Claims the payout for a token
     * @param _tokenId The id of the token to claim the payout for
     */
    function _claim(uint256 _tokenId) internal validToken(_tokenId) nonReentrant checkAuthorized(_tokenId) {
        IVotingEscrow.LockDetails memory oldLocked = _lockDetails[_tokenId];
        if (oldLocked.isPermanent) revert PermanentLock();

        uint256 amountClaimed = claimablePayout(_tokenId);
        if (amountClaimed == 0) revert LockNotExpired();

        // Burn the NFT
        _burn(_tokenId);
        // Reset the lock details
        _lockDetails[_tokenId] = IVotingEscrow.LockDetails(0, 0, 0, false);
        // Update the total supply
        uint256 supplyBefore = supply;
        supply -= amountClaimed;

        // Update the lock details
        _checkpointLock(_tokenId, oldLocked, _lockDetails[_tokenId]);

        /// @notice ERC-5725 event
        emit PayoutClaimed(_tokenId, msg.sender, amountClaimed);

        // IERC5725 - Update the total amount claimed
        _payoutClaimed[_tokenId] += amountClaimed;
        // Transfer the claimed amount to the sender
        IERC20(_payoutToken(_tokenId)).safeTransfer(msg.sender, amountClaimed);

        emit SupplyUpdated(supplyBefore, supply);
    }

    /**
     * @notice Claims the payout for a token
     * @param _tokenId The id of the token to claim the payout for
     */
    function claim(uint256 _tokenId) external override(ERC5725) {
        _claim(_tokenId);
    }

    /**
     * @notice Merges two tokens together
     * @param _from The id of the token to merge from
     * @param _to The id of the token to merge to
     */
    function merge(uint256 _from, uint256 _to) external nonReentrant checkAuthorized(_from) checkAuthorized(_to) {
        if (_from == _to) revert SameNFT();

        IVotingEscrow.LockDetails memory oldLockedTo = _lockDetails[_to];
        if (oldLockedTo.endTime <= block.timestamp && !oldLockedTo.isPermanent) revert LockExpired();

        IVotingEscrow.LockDetails memory oldLockedFrom = _lockDetails[_from];
        if (oldLockedFrom.isPermanent != oldLockedTo.isPermanent) revert PermanentLockMismatch();
        // Calculate the new end time
        uint256 end = oldLockedFrom.endTime >= oldLockedTo.endTime ? oldLockedFrom.endTime : oldLockedTo.endTime;

        // Burn the token being merged from
        _burn(_from);
        // Reset the lock details
        _lockDetails[_from] = LockDetails(0, 0, 0, false);
        // Update the lock details
        _checkpointLock(_from, oldLockedFrom, _lockDetails[_from]);

        // Calculate the new lock details
        LockDetails memory newLockedTo;
        newLockedTo.amount = oldLockedTo.amount + oldLockedFrom.amount;
        newLockedTo.isPermanent = oldLockedTo.isPermanent;
        if (!newLockedTo.isPermanent) {
            newLockedTo.endTime = end;
        }

        // Update the lock details
        _checkpointLock(_to, oldLockedTo, newLockedTo);
        _lockDetails[_to] = newLockedTo;
        emit LockMerged(_from, _to, newLockedTo.amount, end, newLockedTo.isPermanent);
    }

    /**
     * @notice Splits a token into multiple tokens
     * @param _weights The percentages to split the token into
     * @param _tokenId The id of the token to split
     */
    function split(uint256[] memory _weights, uint256 _tokenId) external nonReentrant checkAuthorized(_tokenId) {
        LockDetails memory locked = _lockDetails[_tokenId];
        uint256 currentTime = block.timestamp;
        /// @dev Pulling directly from locked struct to avoid stack-too-deep
        if (locked.endTime <= currentTime && !locked.isPermanent) revert LockExpired();
        if (locked.amount == 0) revert ZeroAmount();

        // reset supply, _deposit_for increase it
        supply -= uint256(int256(locked.amount));
        // Capture owner for split
        address owner = _ownerOf(_tokenId);
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            totalWeight += _weights[i];
        }

        // remove old data
        _lockDetails[_tokenId] = LockDetails(0, 0, 0, false);
        _checkpointLock(_tokenId, locked, _lockDetails[_tokenId]);
        _burn(_tokenId);

        uint256 duration = locked.isPermanent
            ? 0
            : locked.endTime > currentTime
                ? locked.endTime - currentTime
                : 0;

        for (uint256 i = 0; i < _weights.length; i++) {
            uint256 value = (uint256(int256(locked.amount)) * _weights[i]) / totalWeight;
            _createLock(value, duration, owner, owner, locked.isPermanent);
        }
        emit LockSplit(_weights, _tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                           GAUGE REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
        return edStore.getAdjustedEscrowBias(_tokenId, block.timestamp);
    }

    function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return edStore.getAdjustedEscrowBias(_tokenId, _timestamp);
    }

    function getPastEscrowPoint(
        uint256 _tokenId,
        uint256 _timestamp
    ) external view override returns (Checkpoints.Point memory, uint48) {
        return edStore.getAdjustedEscrow(_tokenId, _timestamp);
    }

    function getFirstEscrowPoint(uint256 _tokenId) external view override returns (Checkpoints.Point memory, uint48) {
        return edStore.getFirstEscrowPoint(_tokenId);
    }

    function totalSupply() public view override(ERC721Enumerable, IERC721Enumerable) returns (uint256) {
        return edStore.getAdjustedGlobalVotes(block.timestamp.toUint48());
    }

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC5805}.
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the votes for a delegatee
     * @param account The address of the delegatee
     * @return The number of votes the delegatee has
     */
    function getVotes(address account) external view override(IVotes) returns (uint256) {
        return edStore.getAdjustedVotes(account, block.timestamp.toUint48());
    }

    /**
     * @notice Gets the past votes for a delegatee at a specific time point
     * @param account The address of the delegatee
     * @param timepoint The time point to get the votes at
     * @return The number of votes the delegatee had at the time point
     */
    function getPastVotes(address account, uint256 timepoint) external view override(IVotes) returns (uint256) {
        return edStore.getAdjustedVotes(account, timepoint.toUint48());
    }

    /**
     * @notice Gets the total supply at a specific time point
     * @param _timePoint The time point to get the total supply at
     * @return The total supply at the time point
     */
    function getPastTotalSupply(uint256 _timePoint) external view override(IVotes) returns (uint256) {
        return edStore.getAdjustedGlobalVotes(_timePoint.toUint48());
    }

    /**
     * @notice Delegates votes to a delegatee
     * @param delegatee The account to delegate votes to
     */
    function delegate(address delegatee) external override(IVotes) {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @notice Gets the delegate of a delegatee
     * @dev This function implements IVotes interface.
     *  An account can have multiple delegates in this contract. If multiple
     *  different delegates are found, this function returns address(1) to
     *  indicate that there is not a single unique delegate.
     * @param account The delegatee to get the delegate of
     * @return The delegate of the delegatee, or address(1) if multiple different delegates are found
     */
    function delegates(address account) external view override(IVotes) returns (address) {
        address delegatee = address(0);
        uint256 balance = balanceOf(account);
        /// @dev out-of-gas protection
        uint256 runs = 50 > balance ? balance : 50;
        for (uint256 i = 0; i < runs; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(account, i);
            address currentDelegatee = edStore.getEscrowDelegatee(tokenId);
            /// @dev Hacky way to check if the delegatee is the same for all locks
            if (delegatee == address(0)) {
                delegatee = currentDelegatee;
            } else if (delegatee != currentDelegatee) {
                return address(1);
            }
        }
        return delegatee;
    }

    /**
     * @notice Delegates votes from a specific lock to a delegatee
     * @param _tokenId The ID of the lock token delegating the votes
     * @param delegatee The address to which the votes are being delegated
     */
    function delegate(uint256 _tokenId, address delegatee) external checkAuthorized(_tokenId) {
        (address fromDelegatee, address toDelegatee) = edStore.delegate(
            _tokenId,
            delegatee,
            _lockDetails[_tokenId].endTime
        );
        emit LockDelegateChanged(_tokenId, _msgSender(), fromDelegatee, toDelegatee);
    }

    /**
     * @notice Gets the delegatee of a given lock
     * @param tokenId The ID of the lock token
     * @return The address of the delegatee for the specified token
     */
    function getLockDelegatee(uint256 tokenId) external view returns (address) {
        return edStore.getEscrowDelegatee(tokenId);
    }

    /**
     * @notice Gets all delegates of a delegatee
     * @param account The delegatee to get the delegates of
     * @return An array of all delegates of the delegatee
     */
    function getAccountDelegates(address account) external view returns (address[] memory) {
        uint256 balance = balanceOf(account);
        address[] memory allDelegates = new address[](balance);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(account, i);
            allDelegates[i] = edStore.getEscrowDelegatee(tokenId);
        }
        return allDelegates;
    }

    /**
     * @notice Public function to get the delegatee of a lock
     * @param tokenId The ID of the token
     * @param timestamp The timestamp to get the delegate at
     * @return The address of the delegate
     */
    function delegates(uint256 tokenId, uint48 timestamp) external view returns (address) {
        return edStore.getEscrowDelegateeAtTime(tokenId, timestamp);
    }

    /**
     * @notice Delegates votes by signature
     * @param delegatee The delegatee to delegate votes to
     * @param nonce The nonce for the signature
     * @param expiry The expiry time for the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override(IVotes) {
        if (delegatee == msg.sender || delegatee == address(0)) revert InvalidDelegatee();

        bytes32 domainSeparator = _domainSeparatorV4();
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ECDSA.recover(digest, v, r, s);
        if (signatory == address(0)) revert InvalidSignature();
        if (nonce != nonces[signatory]++) revert InvalidNonce();
        if (block.timestamp > expiry) revert VotesExpiredSignature(expiry);
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Delegates votes from an owner to an delegatee
     * @param delegator The owner of the tokenId delegating votes
     * @param delegatee The account to delegate votes to
     */
    function _delegate(address delegator, address delegatee) internal nonReentrant {
        uint256 balance = balanceOf(delegator);
        address fromDelegate = address(0);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(delegator, i);
            (address oldDelegate, address newDelegate) = edStore.delegate(
                tokenId,
                delegatee,
                _lockDetails[tokenId].endTime
            );
            emit LockDelegateChanged(tokenId, delegator, oldDelegate, newDelegate);
            /// @dev Hacky way to check if the delegatee is the same for all locks
            if (fromDelegate == address(0)) {
                fromDelegate = oldDelegate;
            } else if (fromDelegate != address(1)) {
                if (fromDelegate != oldDelegate) {
                    fromDelegate = address(1);
                }
            }
        }
        emit DelegateChanged(delegator, fromDelegate, delegatee);
    }

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC6372}.
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The clock was incorrectly modified.
     */
    error ERC6372InconsistentClock();

    /**
     * @notice Clock used for flagging checkpoints.
     * @return Current timestamp
     */
    function clock() public view virtual override(IERC6372) returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @notice Machine-readable description of the clock as specified in EIP-6372.
     * @return The clock mode
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override(IERC6372) returns (string memory) {
        // Check that the clock was not modified
        if (clock() != Time.timestamp()) {
            revert ERC6372InconsistentClock();
        }
        return "mode=timestamp";
    }

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC5725}.
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ERC5725}.
     */
    function vestedPayoutAtTime(
        uint256 tokenId,
        uint256 timestamp
    ) public view override(ERC5725) validToken(tokenId) returns (uint256 payout) {
        if (timestamp >= _endTime(tokenId)) {
            return _payout(tokenId);
        }
        return 0;
    }

    /**
     * @dev See {ERC5725}.
     */
    function _payoutToken(uint256 /*tokenId*/) internal view override returns (address) {
        return address(_token);
    }

    /**
     * @dev See {ERC5725}.
     */
    function _payout(uint256 tokenId) internal view override returns (uint256) {
        return _lockDetails[tokenId].amount;
    }

    /**
     * @dev See {ERC5725}.
     */
    function _startTime(uint256 tokenId) internal view override returns (uint256) {
        return _lockDetails[tokenId].startTime;
    }

    /**
     * @dev See {ERC5725}.
     */
    function _endTime(uint256 tokenId) internal view override returns (uint256) {
        return _lockDetails[tokenId].endTime;
    }

    function token() external view returns (IERC20) {
        return _token;
    }

    function lockDetails(uint256 _tokenId) external view returns (LockDetails memory) {
        return _lockDetails[_tokenId];
    }

    function isApprovedOrOwner(address user, uint tokenId) external view returns (bool) {
        return _isAuthorized(ownerOf(tokenId), user, tokenId);
    }
}
