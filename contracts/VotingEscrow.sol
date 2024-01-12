// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/ERC721Votes.sol)

pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC5725} from "./erc5725/ERC5725.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {SafeCastLibrary} from "./libraries/SafeCastLibrary.sol";
import {EscrowDelegateCheckpoints} from "./systems/EscrowDelegateCheckpoints.sol";
import {EscrowDelegateStorage} from "./systems/EscrowDelegateStorage.sol";

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
    IERC20 public token;
    /// @notice Total locked supply
    int128 public supply;

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /**
     * @dev Initializes the contract by setting a `name`, `symbol`, `version` and `mainToken`.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory version,
        IERC20 mainToken
    ) ERC721(_name, _symbol) EIP712(_name, version) {
        token = mainToken;
    }

    /**
     * @dev See {ERC721-_update}. Adjusts votes when tokens are transferred.
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);
        // NOTE: Resets the delegation on transfer
        if (to != previousOwner) edStore.delegate(tokenId, to, lockDetails[tokenId].endTime);

        return previousOwner;
    }

    /**
     * ERC-5725 and token-locking logic
     */

    /// @notice maps the vesting data with tokenIds
    mapping(uint256 => LockDetails) public lockDetails;

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
        int128 value,
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
            /// TODO: Where do we normalize this
            unlockTime = toGlobalClock(block.timestamp + duration); // Locktime is rounded down to global clock (days)
            if (unlockTime <= block.timestamp) revert LockDurationNotInFuture();
            if (unlockTime > block.timestamp + MAX_TIME) revert LockDurationTooLong();
        }

        _mint(to, newTokenId);
        lockDetails[newTokenId].startTime = block.timestamp;
        _updateLock(newTokenId, value, unlockTime, lockDetails[newTokenId], permanent);
        edStore.delegate(newTokenId, delegatee, unlockTime);
        emit LockCreated(newTokenId, delegatee, value, unlockTime, permanent);
        return newTokenId;
    }

    /**
     * @notice Creates a lock for the sender
     * @param _value The total assets to be locked over time
     * @param _lockDuration Duration in seconds of the lock
     * @param _permanent Whether the lock is permanent or not
     * @return The id of the newly created token
     */
    function createLock(int128 _value, uint256 _lockDuration, bool _permanent) external nonReentrant returns (uint256) {
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
        int128 _value,
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
        int128 _value,
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
    function globalCheckpoint() external nonReentrant {
        return edStore.globalCheckpoint();
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
    /// @param _value Amount to deposit
    /// @param _unlockTime New time when to unlock the tokens, or 0 if unchanged
    /// @param _oldLocked Previous locked amount / timestamp
    function _updateLock(
        uint256 _tokenId,
        int128 _value,
        uint256 _unlockTime,
        LockDetails memory _oldLocked,
        bool isPermanent
    ) internal {
        supply += _value;

        // Set newLocked to _oldLocked without mangling memory
        LockDetails memory newLocked;
        (newLocked.amount, newLocked.startTime, newLocked.endTime, newLocked.isPermanent) = (
            _oldLocked.amount,
            _oldLocked.startTime,
            _oldLocked.endTime,
            _oldLocked.isPermanent
        );

        // Adding to existing lock, or if a lock is expired - creating a new one
        newLocked.amount += _value;
        if (_unlockTime != 0 && !isPermanent) {
            newLocked.endTime = _unlockTime;
        }
        if (isPermanent) {
            newLocked.endTime = 0;
            newLocked.isPermanent = true;
        }
        lockDetails[_tokenId] = newLocked;
        emit LockUpdated(_tokenId, _value, _unlockTime, isPermanent);

        // Possibilities:
        // Both _oldLocked.end could be current or expired (>/< block.timestamp)
        // or if the lock is a permanent lock, then _oldLocked.end == 0
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // newLocked.end > block.timestamp (always)
        _checkpointLock(_tokenId, _oldLocked, newLocked);

        if (_value != 0) {
            token.safeTransferFrom(_msgSender(), address(this), _value.toUint256());
        }
        // TODO: emit or remove?
        // emit Deposit(from, _tokenId, _depositType, _value, newLocked.end, block.timestamp);
        // emit Supply(supplyBefore, supplyBefore + _value);
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
        edStore.checkpoint(_tokenId, _oldLocked.amount, _newLocked.amount, _oldLocked.endTime, _newLocked.endTime);
    }

    /**
     * @notice Delegates votes to a specified address
     * @param delegator The id of the token delegating the votes
     * @param delegatee The address receiving the votes
     */
    function delegate(uint256 delegator, address delegatee) external {
        // TODO: Can only delegate if approved or owner
        edStore.delegate(delegator, delegatee, lockDetails[delegator].endTime);
    }

    /// @notice Deposit `_value` tokens for `_tokenId` and add to the lock
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    ///      cannot extend their locktime and deposit for a brand new user
    /// @param _tokenId lock NFT
    /// @param _value Amount to add to user's lock
    function increaseAmount(uint256 _tokenId, uint256 _value) external nonReentrant {
        if (_value == 0) revert ZeroAmount();

        IVotingEscrow.LockDetails memory oldLocked = lockDetails[_tokenId];
        if (oldLocked.amount <= 0) revert NoLockFound();
        if (oldLocked.endTime <= block.timestamp && !oldLocked.isPermanent) revert LockExpired();

        _updateLock(_tokenId, _value.toInt128(), 0, oldLocked, oldLocked.isPermanent);
    }

    /**
     * @notice Increases the unlock time of a lock
     * @param _tokenId The id of the token to increase the unlock time for
     * @param _lockDuration The new duration of the lock
     * @param _permanent Whether the lock is permanent or not
     */
    function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration, bool _permanent) external nonReentrant {
        _checkAuthorized(ownerOf(_tokenId), _msgSender(), _tokenId);
        LockDetails memory oldLocked = lockDetails[_tokenId];
        // TODO: revert or remove?
        // if (oldLocked.isPermanent) revert PermanentLock();

        uint256 unlockTime;
        if (!_permanent) {
            /// TODO: Where do we normalize this
            unlockTime = toGlobalClock(block.timestamp + _lockDuration);
            // Locktime is rounded down to global clock (days)
            if (oldLocked.endTime <= block.timestamp) revert LockExpired();
            if (unlockTime <= oldLocked.endTime) revert LockDurationNotInFuture();
            if (unlockTime > block.timestamp + MAX_TIME) revert LockDurationTooLong();
        }

        _updateLock(_tokenId, 0, unlockTime, oldLocked, _permanent);
        emit LockDurationExtended(_tokenId, unlockTime);
    }

    /**
     * @notice Unlocks a permanent lock
     * @param _tokenId The id of the token to unlock
     */
    function unlockPermanent(uint256 _tokenId) external nonReentrant {
        address sender = _msgSender();
        _checkAuthorized(ownerOf(_tokenId), sender, _tokenId);
        // TODO: revert or remove?
        // if (voted[_tokenId]) revert AlreadyVoted();
        LockDetails memory newLocked = lockDetails[_tokenId];
        if (!newLocked.isPermanent) revert NotPermanentLock();

        // Set the end time to the maximum possible time
        newLocked.endTime = toGlobalClock(block.timestamp + MAX_TIME);
        // Set the lock to not be permanent
        newLocked.isPermanent = false;

        // Update the lock details
        _checkpointLock(_tokenId, lockDetails[_tokenId], newLocked);
        lockDetails[_tokenId] = newLocked;

        emit UnlockPermanent(_tokenId, sender, newLocked.endTime);
        // TODO: emit or remove?
        // emit MetadataUpdate(_tokenId);
    }

    /**
     * @notice Claims the payout for a token
     * @param _tokenId The id of the token to claim the payout for
     */
    function _claim(uint256 _tokenId) internal validToken(_tokenId) nonReentrant {
        _checkAuthorized(ownerOf(_tokenId), _msgSender(), _tokenId);
        // TODO: revert or remove?
        // if (voted[_tokenId]) revert AlreadyVoted();

        IVotingEscrow.LockDetails memory oldLocked = lockDetails[_tokenId];
        if (oldLocked.isPermanent) revert PermanentLock();

        uint256 amountClaimed = claimablePayout(_tokenId);
        if (amountClaimed == 0) revert LockNotExpired();

        // Burn the NFT
        _burn(_tokenId);
        // Reset the lock details
        lockDetails[_tokenId] = IVotingEscrow.LockDetails(0, 0, 0, false);
        // Update the total supply
        supply -= amountClaimed.toInt128();

        // Update the lock details
        _checkpointLock(_tokenId, oldLocked, lockDetails[_tokenId]);

        /// @notice ERC-5725 event
        emit PayoutClaimed(_tokenId, msg.sender, amountClaimed);

        // Update the total amount claimed
        _payoutClaimed[_tokenId] += amountClaimed;
        // Transfer the claimed amount to the sender
        IERC20(_payoutToken(_tokenId)).safeTransfer(msg.sender, amountClaimed);
        // TOOD: emit or remove?
        // emit Withdraw(sender, _tokenId, value, block.timestamp);
        // emit Supply(supplyBefore, supplyBefore - value);
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
    function merge(uint256 _from, uint256 _to) external nonReentrant {
        // TODO: revert or remove?
        // if (voted[_from]) revert AlreadyVoted();
        if (_from == _to) revert SameNFT();

        // Check that the sender is authorized to merge the tokens
        _checkAuthorized(ownerOf(_from), _msgSender(), _from);
        _checkAuthorized(ownerOf(_to), _msgSender(), _to);

        IVotingEscrow.LockDetails memory oldLockedTo = lockDetails[_to];
        if (oldLockedTo.endTime <= block.timestamp && !oldLockedTo.isPermanent) revert LockExpired();

        IVotingEscrow.LockDetails memory oldLockedFrom = lockDetails[_from];
        if (oldLockedFrom.isPermanent) revert PermanentLock();
        // Calculate the new end time
        uint256 end = oldLockedFrom.endTime >= oldLockedTo.endTime ? oldLockedFrom.endTime : oldLockedTo.endTime;

        // Burn the token being merged from
        _burn(_from);
        // Reset the lock details
        lockDetails[_from] = LockDetails(0, 0, 0, false);
        // Update the lock details
        _checkpointLock(_from, oldLockedFrom, lockDetails[_from]);

        // Calculate the new lock details
        LockDetails memory newLockedTo;
        newLockedTo.amount = oldLockedTo.amount + oldLockedFrom.amount;
        // @audit newLockedTo.isPermanent = oldLockedTo.isPermanent;
        newLockedTo.isPermanent = oldLockedTo.isPermanent;
        if (!newLockedTo.isPermanent) {
            newLockedTo.endTime = end;
        }

        // TODO: Consider depositFor here (might save a few lines of code)
        // Update the lock details
        _checkpointLock(_to, oldLockedTo, newLockedTo);
        lockDetails[_to] = newLockedTo;
        emit LockMerged(_from, _to, newLockedTo.amount.toUint256(), end, newLockedTo.isPermanent);
    }

    /**
     * @notice Splits a token into multiple tokens
     * @param _weights The percentages to split the token into
     * @param _tokenId The id of the token to split
     */
    function split(uint256[] memory _weights, uint256 _tokenId) external nonReentrant {
        // check permission and vote
        // TODO: revert or remove?
        // require(attachments[_tokenId] == 0 && !voted[_tokenId], "attached");
        address owner = _ownerOf(_tokenId);
        // Check that the sender is authorized to split the token
        _checkAuthorized(owner, _msgSender(), _tokenId);
        // TODO: revert or remove?
        // if (voted[_from]) revert AlreadyVoted();

        LockDetails memory locked = lockDetails[_tokenId];
        uint256 endTime = locked.endTime;
        uint256 value = uint(int256(locked.amount));
        uint256 currentTime = block.timestamp;

        if (endTime <= currentTime && !locked.isPermanent) revert LockExpired();
        if (value == 0) revert ZeroAmount();

        // reset supply, _deposit_for increase it
        supply -= value.toInt128();

        uint256 i;
        uint256 totalWeight = 0;
        uint256 weightsLen = _weights.length;
        for (i = 0; i < weightsLen; i++) {
            totalWeight += _weights[i];
        }

        // remove old data
        lockDetails[_tokenId] = LockDetails(0, 0, 0, false);
        _checkpointLock(_tokenId, locked, lockDetails[_tokenId]);
        _burn(_tokenId);
        /// @dev Duration would be zero for permanent locks
        uint256 duration = 0;
        if (endTime > currentTime) duration = endTime - currentTime;

        // mint
        uint256 _value = 0;
        for (i = 0; i < weightsLen; i++) {
            _value = (value * _weights[i]) / totalWeight;
            // TODO: Revist this and decide if ownerr is delegatee or past delegatee should be used
            _createLock(_value.toInt128(), duration, owner, owner, locked.isPermanent);
        }
        emit LockSplit(_weights, _tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                           GAUGE REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
        // TODO: return or remove?
        // if (ownershipChange[_tokenId] == block.number) return 0;
        return edStore.getAdjustedNftBias(_tokenId, block.timestamp);
    }

    function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256) {
        return edStore.getAdjustedNftBias(_tokenId, _timestamp);
    }

    function totalSupply() public view override returns (uint256) {
        return edStore.getAdjustedGlobalVotes(block.timestamp.toUint48());
    }

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC5805}.
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the votes for a delegatee
     * @param delegateeAddress The address of the delegatee
     * @return The number of votes the delegatee has
     */
    function getVotes(address delegateeAddress) external view returns (uint256) {
        return edStore.getAdjustedVotes(delegateeAddress, block.timestamp.toUint48());
    }

    /**
     * @notice Gets the past votes for a delegatee at a specific time point
     * @param _delegateeAddress The address of the delegatee
     * @param _timePoint The time point to get the votes at
     * @return The number of votes the delegatee had at the time point
     */
    function getPastVotes(address _delegateeAddress, uint256 _timePoint) external view returns (uint256) {
        return edStore.getAdjustedVotes(_delegateeAddress, _timePoint.toUint48());
    }

    /**
     * @notice Gets the total supply at a specific time point
     * @param _timePoint The time point to get the total supply at
     * @return The total supply at the time point
     */
    function getPastTotalSupply(uint256 _timePoint) external view override returns (uint256) {
        return edStore.getAdjustedGlobalVotes(_timePoint.toUint48());
    }

    /**
     * @notice Delegates votes to a delegatee
     * @param delegatee The account to delegate votes to
     */
    function delegate(address delegatee) external override {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @notice Delegates votes from an owner to an delegatee
     * @param delegator The owner of the tokenId delegating votes
     * @param delegatee The account to delegate votes to
     *
     *
     */
    function _delegate(address delegator, address delegatee) internal nonReentrant {
        uint256 balance = balanceOf(delegator);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(delegator, i);
            edStore.delegate(tokenId, delegatee, lockDetails[tokenId].endTime);
        }
    }

    /**
     * @notice Public function to get the delegatee of an escrow lock
     * @param tokenId The ID of the token
     * @param timestamp The timestamp to get the delegate at
     * @return The address of the delegate
     */
    function getEscrowDelegateeAtTime(uint256 tokenId, uint48 timestamp) external view returns (address) {
        return edStore.getEscrowDelegateeAtTime(tokenId, timestamp);
    }

    /**
     * @notice Gets the delegate of a delegatee
     * @dev This function is merely a placeholder for ERC5801 compatibility
     *  an account can have multiple delegates in this contract.
     * @param delegatee The delegatee to get the delegate of
     * @return The delegate of the delegatee
     */
    function delegates(address delegatee) external view returns (address) {
        // FIXME: delegates is not fully implemented
        // TODO: A single address can be delegated to from multiple escrow locks
        uint256 tokenId = tokenOfOwnerByIndex(delegatee, 0);
        return edStore.getEscrowDelegatee(tokenId);
    }

    /**
     * @notice Gets all delegates of a delegatee
     * @param owner The delegatee to get the delegates of
     * @return An array of all delegates of the delegatee
     */
    function getAccountDelegates(address owner) external view returns (address[] memory) {
        uint256 balance = balanceOf(owner);
        address[] memory allDelegates = new address[](balance);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            allDelegates[i] = edStore.getEscrowDelegatee(tokenId);
        }
        return allDelegates;
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
    ) external override {
        if (delegatee == msg.sender || delegatee != address(0)) revert InvalidDelegatee();

        bytes32 domainSeparator = _domainSeparatorV4();
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ECDSA.recover(digest, v, r, s);
        if (signatory == address(0)) revert InvalidSignature();
        if (nonce != nonces[signatory]++) revert InvalidNonce();
        if (block.timestamp > expiry) revert SignatureExpired();
        return _delegate(signatory, delegatee);
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
    function clock() public view virtual override returns (uint48) {
        return Time.timestamp();
    }

    /**
     * @notice Machine-readable description of the clock as specified in EIP-6372.
     * @return The clock mode
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
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
        return address(token);
    }

    /**
     * @dev See {ERC5725}.
     */
    function _payout(uint256 tokenId) internal view override returns (uint256) {
        return lockDetails[tokenId].amount.toUint256();
    }

    /**
     * @dev See {ERC5725}.
     */
    function _startTime(uint256 tokenId) internal view override returns (uint256) {
        return lockDetails[tokenId].startTime;
    }

    /**
     * @dev See {ERC5725}.
     */
    function _endTime(uint256 tokenId) internal view override returns (uint256) {
        return lockDetails[tokenId].endTime;
    }
}
