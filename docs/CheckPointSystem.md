# Solidity API

## CheckPointSystem

_This contract is used to manage checkpoints in the system._

### MAX_TIME

```solidity
int128 MAX_TIME
```

Maximum time for a checkpoint

### PRECISION

```solidity
int128 PRECISION
```

Precision of calculations

### CLOCK_UNIT

```solidity
uint48 CLOCK_UNIT
```

Unit of time for the clock

### globalSlopeChanges

```solidity
mapping(uint256 => int128) globalSlopeChanges
```

Mapping of global slope changes

### delegateeSlopeChanges

```solidity
mapping(address => mapping(uint256 => int128)) delegateeSlopeChanges
```

Delegatee slope changes

### ERC6372InconsistentClock

```solidity
error ERC6372InconsistentClock()
```

_The clock was incorrectly modified._

### ERC5805FutureLookup

```solidity
error ERC5805FutureLookup(uint256 timepoint, uint48 clock)
```

_Lookup to future votes is not available._

### clock

```solidity
function clock() public view virtual returns (uint48)
```

Clock used for flagging checkpoints.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | Current timestamp |

### globalClock

```solidity
function globalClock() public view virtual returns (uint48)
```

Clock used for flagging global checkpoints.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | Current timestamp rounded to the nearest clock unit |

### toGlobalClock

```solidity
function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48)
```

Converts a timestamp to a global clock value.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _timestamp | uint256 | The timestamp to convert |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | The converted global clock value |

### CLOCK_MODE

```solidity
function CLOCK_MODE() public view virtual returns (string)
```

Machine-readable description of the clock as specified in EIP-6372.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | The clock mode |

### _checkpoint

```solidity
function _checkpoint(uint256 _tokenId, int128 uOldAmount, int128 uNewAmount, uint256 uOldEndTime, uint256 uNewEndTime) internal
```

_Record global and per-user data to checkpoints. Used by VotingEscrow system._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | NFT token ID. No user checkpoint if 0 |
| uOldAmount | int128 | Locked amount from last checkpoint |
| uNewAmount | int128 | Locked amount from current checkpoint |
| uOldEndTime | uint256 | Last checkpoint time |
| uNewEndTime | uint256 | Current checkpoint time |

### _userCheckpoint

```solidity
function _userCheckpoint(uint256 _tokenId, struct Checkpoints.Point uNewPoint) internal
```

_Internal function to update user checkpoint with new point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The ID of the token |
| uNewPoint | struct Checkpoints.Point | The new point to be updated |

### _globalCheckpoint

```solidity
function _globalCheckpoint() internal
```

_Internal function to update global checkpoint_

### _globalCheckpoint

```solidity
function _globalCheckpoint(uint256 _tokenId, struct Checkpoints.Point uOldPoint, struct Checkpoints.Point uNewPoint) internal
```

_Internal function to update global checkpoint with new points_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | The ID of the token |
| uOldPoint | struct Checkpoints.Point | The old point to be updated |
| uNewPoint | struct Checkpoints.Point | The new point to be updated |

### _getAdjustedVotes

```solidity
function _getAdjustedVotes(address _delegateeAddress, uint48 _timestamp) internal view returns (uint256)
```

_Internal function to calculate total voting power at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _delegateeAddress | address | The address of the delegatee |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total voting power at that time |

### _getAdjustedVotesCheckpoint

```solidity
function _getAdjustedVotesCheckpoint(address _delegateeAddress, uint48 _timestamp) internal view returns (struct Checkpoints.Point)
```

_Internal function to get delegated votes checkpoint at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _delegateeAddress | address | The address of the delegatee |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct Checkpoints.Point | Total voting power at that time |

### delegates

```solidity
function delegates(uint256 tokenId) public view returns (address)
```

Public function to get the delegate of a token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### delegates

```solidity
function delegates(uint256 tokenId, uint48 timestamp) external view returns (address)
```

Public function to get the delegate of a token at a specific timestamp

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token |
| timestamp | uint48 | The timestamp to get the delegate at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### _delegates

```solidity
function _delegates(uint256 tokenId, uint48 timestamp) internal view returns (address)
```

_Internal function to get the delegate of a token at a specific timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token |
| timestamp | uint48 | The timestamp to get the delegate at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### _delegate

```solidity
function _delegate(uint256 _delegator, address delegatee, uint256 endTime) internal
```

_Internal function to record user delegation checkpoints. Used by voting system._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _delegator | uint256 | The ID of the delegator |
| delegatee | address | The address of the delegatee |
| endTime | uint256 | The end time of the delegation |

### _checkpointDelegator

```solidity
function _checkpointDelegator(uint256 _delegator, address delegatee, uint256 endTime) internal
```

_Internal function used by `_delegate`
     to update delegator voting checkpoints.
     Automatically delegates, then updates checkpoint._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _delegator | uint256 | The delegator to update checkpoints for |
| delegatee | address | The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead). |
| endTime | uint256 | The end time of the delegation |

### _checkpointDelegatee

```solidity
function _checkpointDelegatee(address delegateeAddress, struct Checkpoints.Point userPoint, uint256 endTime, bool _increase) internal
```

_Internal function to update delegatee's `delegatedBalance` by `balance`.
     Only updates if delegating to a new delegatee._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegateeAddress | address | The address of the delegatee |
| userPoint | struct Checkpoints.Point | The point of the user |
| endTime | uint256 | The end time of the delegation |
| _increase | bool | Whether to increase or decrease the balance |

### _baseCheckpointDelegatee

```solidity
function _baseCheckpointDelegatee(address delegateeAddress) internal returns (struct Checkpoints.Point lastPoint, uint48 lastCheckpoint)
```

_Internal function to update delegatee's checkpoint_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| delegateeAddress | address | The address of the delegatee |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| lastPoint | struct Checkpoints.Point | The last point of the delegatee |
| lastCheckpoint | uint48 | The last checkpoint time of the delegatee |

### _getAdjustedGlobalVotes

```solidity
function _getAdjustedGlobalVotes(uint48 _timestamp) internal view returns (uint256)
```

_Internal function to calculate total voting power at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total voting power at that time |

### _getAdjustedCheckpoint

```solidity
function _getAdjustedCheckpoint(uint48 _timestamp) internal view returns (struct Checkpoints.Point)
```

_Internal function to get latest checkpoint of some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct Checkpoints.Point | Total voting power at that time |

### _getAdjustedNftBias

```solidity
function _getAdjustedNftBias(uint256 _tokenId, uint256 _timestamp) internal view returns (uint256)
```

Get the current bias for `_tokenId` at `_timestamp`

_Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
Fetches last user point prior to a certain timestamp, then walks forward to timestamp._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | NFT for lock |
| _timestamp | uint256 | Epoch time to return bias power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | NFT bias |

