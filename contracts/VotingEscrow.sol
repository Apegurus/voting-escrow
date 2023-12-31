// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/ERC721Votes.sol)

pragma solidity ^0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC5725} from "./erc5725/ERC5725.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {SafeCastLibrary} from "./libraries/SafeCastLibrary.sol";
import {CheckPointSystem} from "./systems/CheckPointSystem.sol";
import "hardhat/console.sol";

/**
 * @dev Extension of ERC721 to support voting and delegation as implemented by {Votes}
 *
 * Tokens do not count as votes until they are delegated, because votes must be tracked which incurs an additional cost
 * on every transfer. Token holders can either delegate to a trusted representative who will decide how to make use of
 * the votes in governance decisions, or they can delegate to themselves to be their own representative.
 */
contract VotingEscrow is ERC5725, IVotingEscrow, CheckPointSystem, EIP712 {
    using SafeERC20 for IERC20;
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;
    IERC20 public token;
    // Total locked supply
    int128 public supply;

    constructor(
        string memory name,
        string memory symbol,
        string memory version,
        IERC20 mainToken
    ) ERC721(name, symbol) EIP712(name, version) {
        token = mainToken;
    }

    /**
     * @dev See {ERC721-_update}. Adjusts votes when tokens are transferred.
     *
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        if (to != previousOwner) _delegate(tokenId, to, lockDetails[tokenId].endTime);

        return previousOwner;
    }

    /**
     *
     * ERC-5725 and token-locking logic
     */

    mapping(uint256 => LockDetails) public lockDetails; /// @dev maps the vesting data with tokenIds

    /// @dev tracker of current NFT id
    uint256 private _tokenIdTracker = 1;

    /**
     * @notice Creates a new vesting NFT and mints it
     * @dev Token amount should be approved to be transferred by this contract before executing create
     * @param value The total assets to be locked over time
     * @param duration Duration in seconds of the lock
     * @param to The receiver of the lock
     */
    function _createLock(int128 value, uint256 duration, address to) internal virtual returns (uint256) {
        /// TODO: Where do we normalize this
        uint256 unlockTime = toGlobalClock(block.timestamp + duration); // Locktime is rounded down to global clock (days)
        if (value == 0) revert ZeroAmount();
        if (unlockTime <= block.timestamp) revert LockDurationNotInFuture();
        if (unlockTime > block.timestamp + _MAXTIME.toUint256()) revert LockDurationTooLong();

        uint256 newTokenId = _tokenIdTracker;

        console.log("End time s%", unlockTime);

        _tokenIdTracker++;
        _mint(to, newTokenId);
        lockDetails[newTokenId].startTime = block.timestamp;
        _depositFor(newTokenId, value, unlockTime, lockDetails[newTokenId]);
        _delegate(newTokenId, to, unlockTime);
        return newTokenId;
    }

    ///
    function createLock(int128 _value, uint256 _lockDuration) external nonReentrant returns (uint256) {
        return _createLock(_value, _lockDuration, _msgSender());
    }

    ///
    function createLockFor(int128 _value, uint256 _lockDuration, address _to) external nonReentrant returns (uint256) {
        return _createLock(_value, _lockDuration, _to);
    }

    function globalCheckpoint() external nonReentrant {
        return _globalCheckpoint(0, 0, 0, 0, 0);
    }

    function checkpointDelegatee(address _delegateeAddress) external nonReentrant {
        _baseCheckpointDelegatee(_delegateeAddress);
    }

    /// @notice Deposit and lock tokens for a user
    /// @param _tokenId NFT that holds lock
    /// @param _value Amount to deposit
    /// @param _unlockTime New time when to unlock the tokens, or 0 if unchanged
    /// @param _oldLocked Previous locked amount / timestamp
    function _depositFor(uint256 _tokenId, int128 _value, uint256 _unlockTime, LockDetails memory _oldLocked) internal {
        int128 supplyBefore = supply;
        supply = supplyBefore + _value;

        // Set newLocked to _oldLocked without mangling memory
        LockDetails memory newLocked;
        (newLocked.amount, newLocked.startTime, newLocked.endTime) = (
            _oldLocked.amount,
            _oldLocked.startTime,
            _oldLocked.endTime
        );

        // Adding to existing lock, or if a lock is expired - creating a new one
        newLocked.amount += _value;
        if (_unlockTime != 0) {
            newLocked.endTime = _unlockTime;
        }
        lockDetails[_tokenId] = newLocked;

        // Possibilities:
        // Both _oldLocked.end could be current or expired (>/< block.timestamp)
        // or if the lock is a permanent lock, then _oldLocked.end == 0
        // value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // newLocked.end > block.timestamp (always)
        _checkpointLock(_tokenId, _oldLocked, newLocked);

        address from = _msgSender();
        if (_value != 0) {
            token.safeTransferFrom(from, address(this), _value.toUint256());
        }

        // emit Deposit(from, _tokenId, _depositType, _value, newLocked.end, block.timestamp);
        // emit Supply(supplyBefore, supplyBefore + _value);
    }

    /// @notice Record global and per-user data to checkpoints. Used by VotingEscrow system.
    /// @param _tokenId NFT token ID. No user checkpoint if 0
    /// @param _oldLocked Pevious locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpointLock(
        uint256 _tokenId,
        IVotingEscrow.LockDetails memory _oldLocked,
        IVotingEscrow.LockDetails memory _newLocked
    ) internal {
        _checkpoint(_tokenId, _oldLocked.amount, _newLocked.amount, _oldLocked.endTime, _newLocked.endTime);
    }

    function delegate(uint256 delegator, address delegatee) external {
        // TODO: Can only delegate if approved or owner
        _delegate(delegator, delegatee, lockDetails[delegator].endTime);
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    ///      Fetches last user point prior to a certain timestamp, then walks forward to timestamp.
    /// @param _tokenId NFT for lock
    /// @param _timestamp Epoch time to return voting power at
    /// @return balance ser voting power
    function balanceOfLockAt(uint256 _tokenId, uint256 _timestamp) external view returns (int128 balance) {
        if (lockDetails[_tokenId].endTime < _timestamp) return 0;
        int128 slope = (lockDetails[_tokenId].amount * _PRECISSION) / _MAXTIME;
        balance = (slope * (lockDetails[_tokenId].endTime - _timestamp).toInt128()) / _PRECISSION;
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

        _depositFor(_tokenId, _value.toInt128(), 0, oldLocked);
    }

    function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external nonReentrant {
        _checkAuthorized(ownerOf(_tokenId), _msgSender(), _tokenId);
        IVotingEscrow.LockDetails memory oldLocked = lockDetails[_tokenId];
        if (oldLocked.isPermanent) revert PermanentLock();
        uint256 unlockTime = toGlobalClock(block.timestamp + _lockDuration); // Locktime is rounded down to global clock (days)

        if (oldLocked.endTime <= block.timestamp) revert LockExpired();
        if (oldLocked.amount <= 0) revert NoLockFound();
        if (unlockTime <= oldLocked.endTime) revert LockDurationNotInFuture();
        if (unlockTime > block.timestamp + _MAXTIME.toUint256()) revert LockDurationTooLong();

        _depositFor(_tokenId, 0, unlockTime, oldLocked);

        // emit MetadataUpdate(_tokenId);
    }

    function _claim(uint256 _tokenId) internal validToken(_tokenId) nonReentrant {
        _checkAuthorized(ownerOf(_tokenId), _msgSender(), _tokenId);
        // if (voted[_tokenId]) revert AlreadyVoted();

        IVotingEscrow.LockDetails memory oldLocked = lockDetails[_tokenId];
        if (oldLocked.isPermanent) revert PermanentLock();

        uint256 amountClaimed = claimablePayout(_tokenId);
        require(amountClaimed > 0, "ERC5725: No pending payout");

        // Burn the NFT
        _burn(_tokenId);
        lockDetails[_tokenId] = IVotingEscrow.LockDetails(0, 0, 0, false);
        supply -= amountClaimed.toInt128();

        _checkpointLock(_tokenId, oldLocked, lockDetails[_tokenId]);

        emit PayoutClaimed(_tokenId, msg.sender, amountClaimed);

        _payoutClaimed[_tokenId] += amountClaimed;
        IERC20(_payoutToken(_tokenId)).safeTransfer(msg.sender, amountClaimed);

        // emit Withdraw(sender, _tokenId, value, block.timestamp);
        // emit Supply(supplyBefore, supplyBefore - value);
    }

    function claim(uint256 _tokenId) external override(ERC5725) {
        _claim(_tokenId);
    }

    function withdraw(uint256 _tokenId) external {
        _claim(_tokenId);
    }

    function merge(uint256 _from, uint256 _to) external nonReentrant {
        address sender = _msgSender();
        // if (voted[_from]) revert AlreadyVoted();
        if (_from == _to) revert SameNFT();

        _checkAuthorized(ownerOf(_from), sender, _from);
        _checkAuthorized(ownerOf(_to), sender, _to);

        IVotingEscrow.LockDetails memory oldLockedTo = lockDetails[_to];
        if (oldLockedTo.endTime <= block.timestamp && !oldLockedTo.isPermanent) revert LockExpired();

        IVotingEscrow.LockDetails memory oldLockedFrom = lockDetails[_from];
        if (oldLockedFrom.isPermanent) revert PermanentLock();
        uint256 end = oldLockedFrom.endTime >= oldLockedTo.endTime ? oldLockedFrom.endTime : oldLockedTo.endTime;

        _burn(_from);
        lockDetails[_from] = LockDetails(0, 0, 0, false);
        _checkpointLock(_from, oldLockedFrom, lockDetails[_from]);

        LockDetails memory newLockedTo;
        newLockedTo.amount = oldLockedTo.amount + oldLockedFrom.amount;
        newLockedTo.isPermanent = oldLockedTo.isPermanent;
        if (newLockedTo.isPermanent) {
            permanentLockBalance += oldLockedFrom.amount.toUint256();
        } else {
            newLockedTo.endTime = end;
        }

        // TODO: Consider depositFor here (might save a few lines of code)
        _checkpointLock(_to, oldLockedTo, newLockedTo);
        lockDetails[_to] = newLockedTo;

        // emit Merge(
        //     sender,
        //     _from,
        //     _to,
        //     oldLockedFrom.amount.toUint256(),
        //     oldLockedTo.amount.toUint256(),
        //     newLockedTo.amount.toUint256(),
        //     newLockedTo.end,
        //     block.timestamp
        // );
        // emit MetadataUpdate(_to);
    }

    /**
     * @notice split NFT into multiple
     * @param amounts   % of split
     * @param _tokenId  NFTs ID
     */
    function split(uint[] memory amounts, uint _tokenId) external nonReentrant {
        // check permission and vote
        // require(attachments[_tokenId] == 0 && !voted[_tokenId], "attached");
        address sender = _msgSender();
        address owner = _ownerOf(_tokenId);
        if (owner == address(0)) revert SplitNoOwner();
        // if (voted[_from]) revert AlreadyVoted();

        _checkAuthorized(owner, sender, _tokenId);
        LockDetails memory locked = lockDetails[_tokenId];

        uint end = locked.endTime;
        uint value = uint(int256(locked.amount));
        require(value > 0); // dev: need non-zero value

        // reset supply, _deposit_for increase it
        supply = supply - value.toInt128();

        uint i;
        uint totalWeight = 0;
        uint amountLen = amounts.length;
        for (i = 0; i < amountLen; i++) {
            totalWeight += amounts[i];
        }

        // remove old data
        lockDetails[_tokenId] = LockDetails(0, 0, 0, false);
        _checkpointLock(_tokenId, locked, lockDetails[_tokenId]);
        _burn(_tokenId);

        if (locked.endTime <= block.timestamp && !locked.isPermanent) revert LockExpired();
        uint duration = end - block.timestamp;

        // mint
        uint _value = 0;
        for (i = 0; i < amountLen; i++) {
            // _tokenId = _tokenIdTracker;
            // _tokenIdTracker++;
            // _mint(owner, _tokenId);
            // _depositFor(_tokenId, _value.toInt128(), unlock_time, lockDetails[_tokenId]);

            _value = (value * amounts[i]) / totalWeight;
            _createLock(_value.toInt128(), duration, owner);
        }
    }

    /*///////////////////////////////////////////////////////////////
                           GAUGE VOTING STORAGE
    //////////////////////////////////////////////////////////////*/

    // function _balanceOfNFTAt(uint256 _tokenId, uint256 _t) internal view returns (uint256) {
    //     return BalanceLogicLibrary.balanceOfNFTAt(userPointEpoch, _userPointHistory, _tokenId, _t);
    // }

    // function _supplyAt(uint256 _timestamp) internal view returns (uint256) {
    //     return BalanceLogicLibrary.supplyAt(slopeChanges, _pointHistory, 0, _timestamp);
    // }

    // function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
    //     // if (ownershipChange[_tokenId] == block.number) return 0;
    //     return _balanceOfNFTAt(_tokenId, block.timestamp);
    // }

    // function balanceOfNFTAt(uint256 _tokenId, uint256 _t) external view returns (uint256) {
    //     return _balanceOfNFTAt(_tokenId, _t);
    // }

    // function totalSupply() external view returns (uint256) {
    //     return _supplyAt(block.timestamp);
    // }

    // function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
    //     return _supplyAt(_timestamp);
    // }

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC5805}.
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Clock used for flagging checkpoints.
     */
    function clock() public view override(CheckPointSystem, IERC6372) returns (uint48) {
        return super.clock();
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view override(CheckPointSystem, IERC6372) returns (string memory) {
        return super.CLOCK_MODE();
    }

    function getVotes(address deelegateeAddress) external view returns (uint256) {
        return _getAdjustedVotesCheckpoint(deelegateeAddress, SafeCast.toUint48(block.timestamp)).bias.toUint256();
    }

    /// @notice Retrieves historical voting balance for a token id at a given timestamp.
    /// @dev If a checkpoint does not exist prior to the timestamp, this will return 0.
    ///      The user must also own the token at the time in order to receive a voting balance.
    /// @param _deelegateeAddress .
    /// @param _timestamp .
    /// @return votes Total voting balance including delegations at a given timestamp.
    function getPastVotes(address _deelegateeAddress, uint256 _timestamp) external view returns (uint256) {
        return _getAdjustedVotesCheckpoint(_deelegateeAddress, SafeCast.toUint48(_timestamp)).bias.toUint256();
    }

    function getPastTotalSupply(uint256 timepoint) external view override returns (uint256) {
        return _getAdjustedCheckpoint(SafeCast.toUint48(timepoint)).bias.toUint256();
    }

    function delegate(address account) external override {
        uint balance = balanceOf(account);
        for (uint i = 0; i < balance; i++) {
            uint tokenId = tokenByIndex(i);
            _delegate(tokenId, account, lockDetails[tokenId].endTime);
        }
    }

    function delegates(address delegatee) external view override returns (address) {}

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {}

    /*///////////////////////////////////////////////////////////////
                           @dev See {IERC5725}.
    //////////////////////////////////////////////////////////////*/

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
    function _payoutToken(uint256 tokenId) internal view override returns (address) {
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

    /**
     *
     * ALL THE GOVERNANCE SHIT
     */

    /**
     * @dev Returns the balance of `account`.
     *
     * WARNING: Overriding this function will likely result in incorrect vote tracking.
     */
    function _getVotingUnits(address account) internal view virtual returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev See {ERC721-_increaseBalance}. We need that to account tokens that were minted in batch.
     */
    function _increaseBalance(address account, uint128 amount) internal virtual override {
        super._increaseBalance(account, amount);
        // _transferVotingUnits(address(0), account, amount);
    }
}
