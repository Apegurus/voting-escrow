# Solidity API

## Lock

### unlockTime

```solidity
uint256 unlockTime
```

-----------------------------------------------------------------------
Storage variables
-----------------------------------------------------------------------

### owner

```solidity
address payable owner
```

### Withdrawal

```solidity
event Withdrawal(uint256 amount, uint256 when)
```

Emitted when the contract is withdrawn

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | The amount of wei withdrawn |
| when | uint256 | The timestamp of the block when the withdraw happened |

### constructor

```solidity
constructor(uint256 _unlockTime, address payable _owner) public payable
```

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------

### receive

```solidity
receive() external payable
```

### withdraw

```solidity
function withdraw() public
```

Withdraw all the funds

