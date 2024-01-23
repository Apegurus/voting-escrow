# Solidity API

## CheckpointSystemStorage

_This contract serves as the storage for checkpoints in the system._

### csStorage

```solidity
struct CheckpointSystemLib.CheckpointSystemStorage csStorage
```

Storage struct for the checkpoint system

### MAX_TIME

```solidity
uint256 MAX_TIME
```

### globalSlopeChanges

```solidity
function globalSlopeChanges(uint256 _timestamp) external view returns (int128)
```

-----------------------------------------------------------------------
Getters
-----------------------------------------------------------------------

### delegateeSlopeChanges

```solidity
function delegateeSlopeChanges(address _delegatee, uint256 _timestamp) external view returns (int128)
```

### toGlobalClock

```solidity
function toGlobalClock(uint256 _timestamp) public pure virtual returns (uint48)
```

-----------------------------------------------------------------------

-----------------------------------------------------------------------

