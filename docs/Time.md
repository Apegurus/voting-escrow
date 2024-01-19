# Solidity API

## Time

Adapted from OpenZeppelin's Time library: v5.0.0 for solc 0.8.19

_This library provides helpers for manipulating time-related objects.

It uses the following types:
- `uint48` for timepoints
- `uint32` for durations

While the library doesn't provide specific types for timepoints and duration, it does provide:
- a `Delay` type to represent duration that can be programmed to change value automatically at a given point
- additional helper functions_

### timestamp

```solidity
function timestamp() internal view returns (uint48)
```

_Get the block timestamp as a Timepoint._

### blockNumber

```solidity
function blockNumber() internal view returns (uint48)
```

_Get the block number as a Timepoint._

