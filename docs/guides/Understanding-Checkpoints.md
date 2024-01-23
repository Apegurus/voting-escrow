# Understanding Checkpoints

- [Understanding Checkpoints](#understanding-checkpoints)
  - [Checkpoint Functions](#checkpoint-functions)
  - [`Trace` vs `TraceAddress`](#trace-vs-traceaddress)
    - [Trace](#trace)
    - [TraceAddress](#traceaddress)
    - [Key Differences](#key-differences)

## Checkpoint Functions

Below is a table summarizing the various lookup functions available in the `Checkpoints` library for both `Trace` and `TraceAddress` structures:

| Function Name         | Structure     | Description                                                                                                                | Parameters                | Returns                                                            |
|-----------------------|---------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------|--------------------------------------------------------------------|
| `push`                | Trace         | Stores a new checkpoint or updates the last one if the key is the same.                                                    | `uint48 key`, `Point value` | `Point previousValue`, `Point newValue`                            |
| `lowerLookup`         | Trace         | Finds the oldest checkpoint with a key greater or equal to the search key.                                                 | `uint48 key`               | `Point value`                                                      |
| `upperLookup`         | Trace         | Finds the most recent checkpoint with a key lower or equal to the search key.                                              | `uint48 key`               | `bool exists`, `uint48 key`, `Point value`                         |
| `upperLookupRecent`   | Trace         | Optimized version of `upperLookup` for finding recent checkpoints.                                                         | `uint48 key`               | `bool exists`, `uint48 key`, `Point value`                         |
| `latest`              | Trace         | Retrieves the most recent checkpoint value or zero if there are no checkpoints.                                            | None                       | `Point value`                                                      |
| `latestCheckpoint`    | Trace         | Checks if there is a checkpoint and retrieves the key and value of the most recent checkpoint.                             | None                       | `bool exists`, `uint48 key`, `Point value`                         |
| `length`              | Trace         | Returns the number of checkpoints.                                                                                         | None                       | `uint256 length`                                                   |
| `at`                  | Trace         | Retrieves the checkpoint at a given position.                                                                              | `uint48 pos`               | `Checkpoint value`                                                 |
| `push`                | TraceAddress  | Stores a new checkpoint or updates the last one if the key is the same for addresses.                                      | `uint48 key`, `address value` | `address previousValue`, `address newValue`                      |
| `lowerLookup`         | TraceAddress  | Finds the oldest checkpoint with a key greater or equal to the search key for addresses.                                   | `uint48 key`               | `address value`                                                    |
| `upperLookup`         | TraceAddress  | Finds the most recent checkpoint with a key lower or equal to the search key for addresses.                                | `uint48 key`               | `address value`                                                    |
| `upperLookupRecent`   | TraceAddress  | Optimized version of `upperLookup` for finding recent checkpoints for addresses.                                           | `uint48 key`               | `address value`                                                    |
| `latest`              | TraceAddress  | Retrieves the most recent checkpoint address or zero if there are no checkpoints.                                          | None                       | `address value`                                                    |
| `latestCheckpoint`    | TraceAddress  | Checks if there is a checkpoint and retrieves the key and value of the most recent checkpoint for addresses.               | None                       | `bool exists`, `uint48 key`, `address value`                      |
| `length`              | TraceAddress  | Returns the number of checkpoints for addresses.                                                                           | None                       | `uint256 length`                                                   |
| `at`                  | TraceAddress  | Retrieves the checkpoint at a given position for addresses.                                                                | `uint48 pos`               | `CheckpointAddress value`                                          |

The `Trace` structure checkpoints are used for numerical values represented by the `Point` struct, which includes `bias`, `slope`, and `permanent`. The `TraceAddress` structure checkpoints are specifically for storing address values. Each function is designed to interact with the checkpoint data in a way that is efficient for different use cases, such as retrieving the most recent data, searching for past data, or simply updating the checkpoint information.

## `Trace` vs `TraceAddress`

Both `Trace` and `TraceAddress` are struct types defined in the `Checkpoints` library, and they are used to manage a series of checkpoints. However, they are designed to handle different types of data:

### Trace

The `Trace` struct is used for checkpointing numerical values that change over time. It contains an array of `Checkpoint` structs. Each `Checkpoint` struct consists of a `uint48` key (typically representing a timestamp or block number) and a `Point` value. The `Point` struct is a composite of three `int128` values:

- `bias`: Represents the current value of a user's voting power or another numerical quantity at the checkpoint.
- `slope`: Indicates the rate of change of the `bias` over time.
- `permanent`: Represents a permanent value that doesn't decay over time (unlike `bias`, which can change based on `slope`).

The `Trace` struct is typically used in scenarios where you need to track and manage numerical values that are subject to change, such as voting power in a governance system.

### TraceAddress

The `TraceAddress` struct is similar to `Trace` but is specialized for checkpointing `address` values that change over time. It contains an array of `CheckpointAddress` structs. Each `CheckpointAddress` struct consists of a `uint48` key (again, typically a timestamp or block number) and an `address` value.

The `TraceAddress` struct is used in situations where you need to keep a history of addresses associated with a particular key, such as tracking the delegation of voting rights to different addresses over time.

### Key Differences

- **Data Type**: `Trace` is for numerical data (represented by `Point`), while `TraceAddress` is for Ethereum addresses.
- **Value Structure**: `Trace` uses the `Point` struct to store numerical data, including `bias`, `slope`, and `permanent`. `TraceAddress` simply stores an `address`.
- **Use Case**: `Trace` is useful for tracking values that change over time with a certain rate (like voting power), and `TraceAddress` is useful for tracking the history of address values tied to certain keys (like delegate addresses).

Both structures provide similar functionalities for checkpointing, such as inserting new checkpoints, updating existing ones, and retrieving past values. The choice between `Trace` and `TraceAddress` depends on whether you need to checkpoint numerical data or address data.
