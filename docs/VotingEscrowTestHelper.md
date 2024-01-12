# Solidity API

## VotingEscrowTestHelper

### votingEscrow

```solidity
contract VotingEscrow votingEscrow
```

### constructor

```solidity
constructor(address _votingEscrow) public
```

### createManyLocks

```solidity
function createManyLocks(int128[] _value, uint256[] _lockDuration, address[] _to, address[] _delegtatee, bool[] _permanent) public
```

### balanceOfLockAt

```solidity
function balanceOfLockAt(uint256 _tokenId, uint256 _timestamp) external view returns (int128 balance)
```

Get the current voting power for `_tokenId`

_Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
     Fetches last user point prior to the CLOCK_UNIT before the timestamp_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenId | uint256 | NFT for lock |
| _timestamp | uint256 | Epoch time to return voting power at |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| balance | int128 | ser voting power |

