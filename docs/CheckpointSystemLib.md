# Solidity API

## CheckpointSystemLib

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

### CheckpointSystemStorage

```solidity
struct CheckpointSystemStorage {
  struct Checkpoints.Trace _globalCheckpoints;
  mapping(uint256 => int128) globalSlopeChanges;
  mapping(uint256 => struct Checkpoints.Trace) _lockCheckpoints;
  mapping(address => struct Checkpoints.Trace) _delegateCheckpoints;
  mapping(uint256 => struct Checkpoints.TraceAddress) _escrowDelegateeAddress;
  mapping(address => mapping(uint256 => int128)) delegateeSlopeChanges;
}
```

### clock

```solidity
function clock() public view returns (uint48)
```

Clock used for flagging checkpoints.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | Current timestamp |

### globalClock

```solidity
function globalClock() public view returns (uint48)
```

Clock used for flagging global checkpoints.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint48 | Current timestamp rounded to the nearest clock unit |

### toGlobalClock

```solidity
function toGlobalClock(uint256 _timestamp) internal pure returns (uint48)
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

### checkpoint

```solidity
function checkpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 _escrowId, int128 uOldAmount, int128 uNewAmount, uint256 uOldEndTime, uint256 uNewEndTime) external
```

_Record global and per-escrow data to checkpoints. Used by VotingEscrow system._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage | The CheckpointSystemStorage struct containing all the storage mappings. |
| _escrowId | uint256 | NFT escrow lock ID. No escrow checkpoint if 0 |
| uOldAmount | int128 | Locked amount from last checkpoint |
| uNewAmount | int128 | Locked amount from current checkpoint |
| uOldEndTime | uint256 | Last checkpoint time |
| uNewEndTime | uint256 | Current checkpoint time |

### escrowCheckpoint

```solidity
function escrowCheckpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 _escrowId, struct Checkpoints.Point uNewPoint) public
```

_Internal function to update escrow checkpoint with new point_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _escrowId | uint256 | The ID of the escrow lock |
| uNewPoint | struct Checkpoints.Point | The new point to be updated |

### globalCheckpoint

```solidity
function globalCheckpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_) internal
```

_Internal function to update global checkpoint_

### globalCheckpoint

```solidity
function globalCheckpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 _escrowId, struct Checkpoints.Point uOldPoint, struct Checkpoints.Point uNewPoint) public
```

_Internal function to update global checkpoint with new points_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _escrowId | uint256 | The ID of the escrow lock |
| uOldPoint | struct Checkpoints.Point | The old point to be updated |
| uNewPoint | struct Checkpoints.Point | The new point to be updated |

### getAdjustedVotes

```solidity
function getAdjustedVotes(struct CheckpointSystemLib.CheckpointSystemStorage storage_, address _delegateeAddress, uint48 _timestamp) external view returns (uint256)
```

_Internal function to calculate total voting power at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _delegateeAddress | address | The address of the delegatee |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total voting power at that time |

### getAdjustedVotesCheckpoint

```solidity
function getAdjustedVotesCheckpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_, address _delegateeAddress, uint48 _timestamp) public view returns (struct Checkpoints.Point)
```

_Internal function to get delegated votes checkpoint at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _delegateeAddress | address | The address of the delegatee |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct Checkpoints.Point | Total voting power at that time |

### getEscrowDelegatee

```solidity
function getEscrowDelegatee(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 escrowId) external view returns (address)
```

Public function to get the delegatee of an escrow lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| escrowId | uint256 | The ID of the escrow |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### getEscrowDelegateeAtTime

```solidity
function getEscrowDelegateeAtTime(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 escrowId, uint48 timestamp) public view returns (address)
```

Public function to get the delegatee of an escrow lock

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| escrowId | uint256 | The ID of the escrow lock |
| timestamp | uint48 | The timestamp to get the delegate at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | The address of the delegate |

### delegate

```solidity
function delegate(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 escrowId, address delegatee, uint256 endTime) external
```

_Internal function to record escrow delegation checkpoints. Used by voting system._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| escrowId | uint256 | The ID of the escrow lock |
| delegatee | address | The address of the delegatee |
| endTime | uint256 | The end time of the delegation |

### checkpointDelegator

```solidity
function checkpointDelegator(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 escrowId, address delegatee, uint256 endTime) public
```

_Internal function used by `_delegate`
     to update delegator voting checkpoints.
     Automatically delegates, then updates checkpoint._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| escrowId | uint256 | The ID of the escrow lock lock |
| delegatee | address | The new delegatee for the escrowId. |
| endTime | uint256 | The end time of the delegation |

### checkpointDelegatee

```solidity
function checkpointDelegatee(struct CheckpointSystemLib.CheckpointSystemStorage storage_, address delegateeAddress, struct Checkpoints.Point escrowPoint, uint256 endTime, bool _increase) public
```

_Internal function to update delegatee's `delegatedBalance` by `balance`.
     Only updates if delegating to a new delegatee._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| delegateeAddress | address | The address of the delegatee |
| escrowPoint | struct Checkpoints.Point | The point of the escrow |
| endTime | uint256 | The end time of the delegation |
| _increase | bool | Whether to increase or decrease the balance |

### baseCheckpointDelegatee

```solidity
function baseCheckpointDelegatee(struct CheckpointSystemLib.CheckpointSystemStorage storage_, address delegateeAddress) public returns (struct Checkpoints.Point lastPoint, uint48 lastCheckpoint)
```

_Internal function to update delegatee's checkpoint_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| delegateeAddress | address | The address of the delegatee |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| lastPoint | struct Checkpoints.Point | The last point of the delegatee |
| lastCheckpoint | uint48 | The last checkpoint time of the delegatee |

### getAdjustedGlobalVotes

```solidity
function getAdjustedGlobalVotes(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint48 _timestamp) external view returns (uint256)
```

_Internal function to calculate total voting power at some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Total voting power at that time |

### getAdjustedCheckpoint

```solidity
function getAdjustedCheckpoint(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint48 _timestamp) public view returns (struct Checkpoints.Point)
```

_Internal function to get latest checkpoint of some point in the past_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _timestamp | uint48 | Time to calculate the total voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct Checkpoints.Point | Total voting power at that time |

### getAdjustedNftBias

```solidity
function getAdjustedNftBias(struct CheckpointSystemLib.CheckpointSystemStorage storage_, uint256 _escrowId, uint256 _timestamp) external view returns (uint256)
```

Get the current bias for `_escrowId` at `_timestamp`

_Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
Fetches last escrow point prior to a certain timestamp, then walks forward to timestamp._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| storage_ | struct CheckpointSystemLib.CheckpointSystemStorage |  |
| _escrowId | uint256 | NFT for lock |
| _timestamp | uint256 | Epoch time to return bias power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | NFT bias |

