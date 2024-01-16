# Solidity API

## VotingEscrow

_This contract is used for locking tokens and voting.

- tokenIds always have a delegatee, with the owner being the default (see createLock)
- On transfers, delegation is reset. (See _update)
-_

### token

```solidity
contract IERC20 token
```

The token being locked

### supply

```solidity
int128 supply
```

Total locked supply

### DELEGATION_TYPEHASH

```solidity
bytes32 DELEGATION_TYPEHASH
```

The EIP-712 typehash for the delegation struct used by the contract

### nonces

```solidity
mapping(address => uint256) nonces
```

A record of states for signing / validating signatures

### constructor

```solidity
constructor(string _name, string _symbol, string version, contract IERC20 mainToken) public
```

_Initializes the contract by setting a `name`, `symbol`, `version` and `mainToken`._

### checkAuthorized

```solidity
modifier checkAuthorized(uint256 _tokenId)
```

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool supported)
```

_See {IERC165-supportsInterface}._

### _update

```solidity
function _update(address to, uint256 tokenId, address auth) internal virtual returns (address)
```

_See {ERC721-_update}. Adjusts votes when tokens are transferred.
Emits a {IVotes-DelegateVotesChanged} event._

### lockDetails

```solidity
mapping(uint256 => struct IVotingEscrow.LockDetails) lockDetails
```

maps the vesting data with tokenIds

### totalNftsMinted

```solidity
uint256 totalNftsMinted
```

tracker of current NFT id

### _createLock

```solidity
function _createLock(int128 value, uint256 duration, address to, address delegatee, bool permanent) internal virtual returns (uint256)
```

Creates a new vesting NFT and mints it

_Token amount should be approved to be transferred by this contract before executing create_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | int128 | The total assets to be locked over time |
| duration | uint256 | Duration in seconds of the lock |
| to | address | The receiver of the lock |
| delegatee | address |  |
| permanent | bool |  |

### createLock

```solidity
function createLock(int128 _value, uint256 _lockDuration, bool _permanent) external returns (uint256)
```

Creates a lock for the sender

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _value | int128 | The total assets to be locked over time |
| _lockDuration | uint256 | Duration in seconds of the lock |
| _permanent | bool | Whether the lock is permanent or not |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The id of the newly created token |

### createLockFor

```solidity
function createLockFor(int128 _value, uint256 _lockDuration, address _to, bool _permanent) external returns (uint256)
```

Creates a lock for a specified address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _value | int128 | The total assets to be locked over time |
| _lockDuration | uint256 | Duration in seconds of the lock |
| _to | address | The receiver of the lock |
| _permanent | bool | Whether the lock is permanent or not |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The id of the newly created token |

### createDelegatedLockFor

```solidity
function createDelegatedLockFor(int128 _value, uint256 _lockDuration, address _to, address _delegatee, bool _permanent) external returns (uint256)
```

Creates a lock for a specified address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _value | int128 | The total assets to be locked over time |
| _lockDuration | uint256 | Duration in seconds of the lock |
| _to | address | The receiver of the lock |
| _delegatee | address | The receiver of the lock |
| _permanent | bool | Whether the lock is permanent or not |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The id of the newly created token |

### globalCheckpoint

```solidity
function globalCheckpoint() external
```

Updates the global checkpoint

### checkpointDelegatee

```solidity
function checkpointDelegatee(address _delegateeAddress) external
```

Updates the checkpoint for a delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _delegateeAddress | address | The address of the delegatee |

### _updateLock

```solidity
function _updateLock(uint256 _tokenId, int128 _increasedValue, uint256 _unlockTime, struct IVotingEscrow.LockDetails _oldLocked, bool isPermanent) internal
```

Deposit & update lock tokens for a user

_The supply is increased by the _value amount_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | NFT that holds lock |
| _increasedValue | int128 | Amount to deposit |
| _unlockTime | uint256 | New time when to unlock the tokens, or 0 if unchanged |
| _oldLocked | struct IVotingEscrow.LockDetails | Previous locked amount / timestamp |
| isPermanent | bool |  |

### _checkpointLock

```solidity
function _checkpointLock(uint256 _tokenId, struct IVotingEscrow.LockDetails _oldLocked, struct IVotingEscrow.LockDetails _newLocked) internal
```

Record global and per-user data to checkpoints. Used by VotingEscrow system.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | NFT token ID. No user checkpoint if 0 |
| _oldLocked | struct IVotingEscrow.LockDetails | Previous locked amount / end lock time for the user |
| _newLocked | struct IVotingEscrow.LockDetails | New locked amount / end lock time for the user |

### increaseAmount

```solidity
function increaseAmount(uint256 _tokenId, uint256 _value) external
```

Deposit `_value` tokens for `_tokenId` and add to the lock

_Anyone (even a smart contract) can deposit for someone else, but
     cannot extend their locktime and deposit for a brand new user_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | lock NFT |
| _value | uint256 | Amount to add to user's lock |

### increaseUnlockTime

```solidity
function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration, bool _permanent) external
```

Increases the unlock time of a lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The id of the token to increase the unlock time for |
| _lockDuration | uint256 | The new duration of the lock |
| _permanent | bool | Whether the lock is permanent or not |

### unlockPermanent

```solidity
function unlockPermanent(uint256 _tokenId) external
```

Unlocks a permanent lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The id of the token to unlock |

### _claim

```solidity
function _claim(uint256 _tokenId) internal
```

Claims the payout for a token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The id of the token to claim the payout for |

### claim

```solidity
function claim(uint256 _tokenId) external
```

Claims the payout for a token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The id of the token to claim the payout for |

### merge

```solidity
function merge(uint256 _from, uint256 _to) external
```

Merges two tokens together

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | uint256 | The id of the token to merge from |
| _to | uint256 | The id of the token to merge to |

### split

```solidity
function split(uint256[] _weights, uint256 _tokenId) external
```

Splits a token into multiple tokens

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _weights | uint256[] | The percentages to split the token into |
| _tokenId | uint256 | The id of the token to split |

### balanceOfNFT

```solidity
function balanceOfNFT(uint256 _tokenId) public view returns (uint256)
```

### balanceOfNFTAt

```solidity
function balanceOfNFTAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256)
```

### totalSupply

```solidity
function totalSupply() public view returns (uint256)
```

_See {IERC721Enumerable-totalSupply}._

### getVotes

```solidity
function getVotes(address account) external view returns (uint256)
```

Gets the votes for a delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The address of the delegatee |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of votes the delegatee has |

### getPastVotes

```solidity
function getPastVotes(address account, uint256 timepoint) external view returns (uint256)
```

Gets the past votes for a delegatee at a specific time point

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The address of the delegatee |
| timepoint | uint256 | The time point to get the votes at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of votes the delegatee had at the time point |

### getPastTotalSupply

```solidity
function getPastTotalSupply(uint256 _timePoint) external view returns (uint256)
```

Gets the total supply at a specific time point

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _timePoint | uint256 | The time point to get the total supply at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The total supply at the time point |

### delegate

```solidity
function delegate(address delegatee) external
```

Delegates votes to a delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegatee | address | The account to delegate votes to |

### delegates

```solidity
function delegates(address account) external view returns (address)
```

Gets the delegate of a delegatee

_This function implements IVotes interface.
 An account can have multiple delegates in this contract. If multiple
 different delegates are found, this function returns address(1) to
 indicate that there is not a single unique delegate._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The delegatee to get the delegate of |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The delegate of the delegatee, or address(1) if multiple different delegates are found |

### delegate

```solidity
function delegate(uint256 _tokenId, address delegatee) external
```

Delegates votes from a specific lock to a delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The ID of the lock token delegating the votes |
| delegatee | address | The address to which the votes are being delegated |

### getLockDelegatee

```solidity
function getLockDelegatee(uint256 tokenId) external view returns (address)
```

Gets the delegatee of a given lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the lock token |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegatee for the specified token |

### getAccountDelegates

```solidity
function getAccountDelegates(address account) external view returns (address[])
```

Gets all delegates of a delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The delegatee to get the delegates of |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address[] | An array of all delegates of the delegatee |

### getLockDelegateeAtTime

```solidity
function getLockDelegateeAtTime(uint256 tokenId, uint48 timestamp) external view returns (address)
```

Public function to get the delegatee of a lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token |
| timestamp | uint48 | The timestamp to get the delegate at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### delegateBySig

```solidity
function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external
```

Delegates votes by signature

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegatee | address | The delegatee to delegate votes to |
| nonce | uint256 | The nonce for the signature |
| expiry | uint256 | The expiry time for the signature |
| v | uint8 | The recovery byte of the signature |
| r | bytes32 | Half of the ECDSA signature pair |
| s | bytes32 | Half of the ECDSA signature pair |

### _delegate

```solidity
function _delegate(address delegator, address delegatee) internal
```

Delegates votes from an owner to an delegatee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegator | address | The owner of the tokenId delegating votes |
| delegatee | address | The account to delegate votes to |

### ERC6372InconsistentClock

```solidity
error ERC6372InconsistentClock()
```

_The clock was incorrectly modified._

### clock

```solidity
function clock() public view virtual returns (uint48)
```

Clock used for flagging checkpoints.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | Current timestamp |

### CLOCK_MODE

```solidity
function CLOCK_MODE() public view virtual returns (string)
```

Machine-readable description of the clock as specified in EIP-6372.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | The clock mode |

### vestedPayoutAtTime

```solidity
function vestedPayoutAtTime(uint256 tokenId, uint256 timestamp) public view returns (uint256 payout)
```

_See {ERC5725}._

### _payoutToken

```solidity
function _payoutToken(uint256) internal view returns (address)
```

_See {ERC5725}._

### _payout

```solidity
function _payout(uint256 tokenId) internal view returns (uint256)
```

_See {ERC5725}._

### _startTime

```solidity
function _startTime(uint256 tokenId) internal view returns (uint256)
```

_See {ERC5725}._

### _endTime

```solidity
function _endTime(uint256 tokenId) internal view returns (uint256)
```

_See {ERC5725}._

