# Solidity API

## Checkpoints

_This library defines the `Trace*` struct, for checkpointing values as they change at different points in
time, and later looking up past values by block number. See {Votes} as an example.

To create a history of checkpoints define a variable type `Checkpoints.Trace*` in your contract, and store a new
checkpoint for the current transaction block using the {push} function._

### Trace

```solidity
struct Trace {
  struct Checkpoints.Checkpoint[] _checkpoints;
}
```

### Point

```solidity
struct Point {
  int128 bias;
  int128 slope;
  int128 permanent;
}
```

### Checkpoint

```solidity
struct Checkpoint {
  uint48 _key;
  struct Checkpoints.Point _value;
}
```

### CheckpointUnorderedInsertions

```solidity
error CheckpointUnorderedInsertions()
```

_A value was attempted to be inserted on a past checkpoint._

### push

```solidity
function push(struct Checkpoints.Trace self, uint48 key, struct Checkpoints.Point value) internal returns (struct Checkpoints.Point, struct Checkpoints.Point)
```

_Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.

Returns previous value and new value.

IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
library._

### lowerLookup

```solidity
function lowerLookup(struct Checkpoints.Trace self, uint48 key) internal view returns (struct Checkpoints.Point)
```

_Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
there is none._

### upperLookup

```solidity
function upperLookup(struct Checkpoints.Trace self, uint48 key) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none._

### upperLookupRecent

```solidity
function upperLookupRecent(struct Checkpoints.Trace self, uint48 key) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none.

NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
keys)._

### latest

```solidity
function latest(struct Checkpoints.Trace self) internal view returns (struct Checkpoints.Point)
```

_Returns the value in the most recent checkpoint, or zero if there are no checkpoints._

### latestCheckpoint

```solidity
function latestCheckpoint(struct Checkpoints.Trace self) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
in the most recent checkpoint._

### length

```solidity
function length(struct Checkpoints.Trace self) internal view returns (uint256)
```

_Returns the number of checkpoint._

### at

```solidity
function at(struct Checkpoints.Trace self, uint48 pos) internal view returns (struct Checkpoints.Checkpoint)
```

_Returns checkpoint at given position._

### blankPoint

```solidity
function blankPoint() internal pure returns (struct Checkpoints.Point)
```

### TraceAddress

```solidity
struct TraceAddress {
  struct Checkpoints.CheckpointAddress[] _checkpoints;
}
```

### CheckpointAddress

```solidity
struct CheckpointAddress {
  uint48 _key;
  address _value;
}
```

### push

```solidity
function push(struct Checkpoints.TraceAddress self, uint48 key, address value) internal returns (address, address)
```

_Pushes a (`key`, `value`) pair into a TraceAddress so that it is stored as the checkpoint.

Returns previous value and new value.

IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
library._

### lowerLookup

```solidity
function lowerLookup(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
there is none._

### upperLookup

```solidity
function upperLookup(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none._

### upperLookupRecent

```solidity
function upperLookupRecent(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none.

NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
keys)._

### latest

```solidity
function latest(struct Checkpoints.TraceAddress self) internal view returns (address)
```

_Returns the value in the most recent checkpoint, or zero if there are no checkpoints._

### latestCheckpoint

```solidity
function latestCheckpoint(struct Checkpoints.TraceAddress self) internal view returns (bool exists, uint48 _key, address _value)
```

_Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
in the most recent checkpoint._

### length

```solidity
function length(struct Checkpoints.TraceAddress self) internal view returns (uint256)
```

_Returns the number of checkpoint._

### at

```solidity
function at(struct Checkpoints.TraceAddress self, uint48 pos) internal view returns (struct Checkpoints.CheckpointAddress)
```

_Returns checkpoint at given position._

## Checkpoints

_This library defines the `Trace*` struct, for checkpointing values as they change at different points in
time, and later looking up past values by block number. See {Votes} as an example.

To create a history of checkpoints define a variable type `Checkpoints.Trace*` in your contract, and store a new
checkpoint for the current transaction block using the {push} function._

### Trace

-----------------------------------------------------------------------
Trace functions
-----------------------------------------------------------------------

```solidity
struct Trace {
  struct Checkpoints.Checkpoint[] _checkpoints;
}
```

### Point

```solidity
struct Point {
  int128 bias;
  int128 slope;
  int128 permanent;
}
```

### Checkpoint

```solidity
struct Checkpoint {
  uint48 _key;
  struct Checkpoints.Point _value;
}
```

### CheckpointUnorderedInsertions

```solidity
error CheckpointUnorderedInsertions()
```

_A value was attempted to be inserted on a past checkpoint._

### push

```solidity
function push(struct Checkpoints.Trace self, uint48 key, struct Checkpoints.Point value) internal returns (struct Checkpoints.Point, struct Checkpoints.Point)
```

_Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.

Returns previous value and new value.

IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
library._

### lowerLookup

```solidity
function lowerLookup(struct Checkpoints.Trace self, uint48 key) internal view returns (struct Checkpoints.Point)
```

_Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
there is none._

### upperLookup

```solidity
function upperLookup(struct Checkpoints.Trace self, uint48 key) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none._

### upperLookupRecent

```solidity
function upperLookupRecent(struct Checkpoints.Trace self, uint48 key) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none.

NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
keys)._

### latest

```solidity
function latest(struct Checkpoints.Trace self) internal view returns (struct Checkpoints.Point)
```

_Returns the value in the most recent checkpoint, or zero if there are no checkpoints._

### latestCheckpoint

```solidity
function latestCheckpoint(struct Checkpoints.Trace self) internal view returns (bool exists, uint48 _key, struct Checkpoints.Point _value)
```

_Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
in the most recent checkpoint._

### length

```solidity
function length(struct Checkpoints.Trace self) internal view returns (uint256)
```

_Returns the number of checkpoint._

### at

```solidity
function at(struct Checkpoints.Trace self, uint48 pos) internal view returns (struct Checkpoints.Checkpoint)
```

_Returns checkpoint at given position._

### blankPoint

```solidity
function blankPoint() internal pure returns (struct Checkpoints.Point)
```

### TraceAddress

-----------------------------------------------------------------------
TraceAddress functions
-----------------------------------------------------------------------

```solidity
struct TraceAddress {
  struct Checkpoints.CheckpointAddress[] _checkpoints;
}
```

### CheckpointAddress

```solidity
struct CheckpointAddress {
  uint48 _key;
  address _value;
}
```

### push

```solidity
function push(struct Checkpoints.TraceAddress self, uint48 key, address value) internal returns (address, address)
```

_Pushes a (`key`, `value`) pair into a TraceAddress so that it is stored as the checkpoint.

Returns previous value and new value.

IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
library._

### lowerLookup

```solidity
function lowerLookup(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
there is none._

### upperLookup

```solidity
function upperLookup(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none._

### upperLookupRecent

```solidity
function upperLookupRecent(struct Checkpoints.TraceAddress self, uint48 key) internal view returns (address)
```

_Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
if there is none.

NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
keys)._

### latest

```solidity
function latest(struct Checkpoints.TraceAddress self) internal view returns (address)
```

_Returns the value in the most recent checkpoint, or zero if there are no checkpoints._

### latestCheckpoint

```solidity
function latestCheckpoint(struct Checkpoints.TraceAddress self) internal view returns (bool exists, uint48 _key, address _value)
```

_Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
in the most recent checkpoint._

### length

```solidity
function length(struct Checkpoints.TraceAddress self) internal view returns (uint256)
```

_Returns the number of checkpoint._

### at

```solidity
function at(struct Checkpoints.TraceAddress self, uint48 pos) internal view returns (struct Checkpoints.CheckpointAddress)
```

_Returns checkpoint at given position._

