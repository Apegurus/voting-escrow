# Solidity API

## IVotingEscrow

### LockDetails

```solidity
struct LockDetails {
  int128 amount;
  uint256 startTime;
  uint256 endTime;
  bool isPermanent;
}
```

### SupplyUpdated

```solidity
event SupplyUpdated(int128 oldSupply, int128 newSupply)
```

-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------

### LockCreated

```solidity
event LockCreated(uint256 tokenId, address to, int128 value, uint256 unlockTime, bool isPermanent)
```

Lock events

### LockUpdated

```solidity
event LockUpdated(uint256 tokenId, int128 value, uint256 unlockTime, bool isPermanent)
```

### LockMerged

```solidity
event LockMerged(uint256 fromTokenId, uint256 toTokenId, uint256 totalValue, uint256 unlockTime, bool isPermanent)
```

### LockSplit

```solidity
event LockSplit(uint256[] splitWeights, uint256 _tokenId)
```

### LockDurationExtended

```solidity
event LockDurationExtended(uint256 tokenId, uint256 newUnlockTime, bool isPermanent)
```

### LockAmountIncreased

```solidity
event LockAmountIncreased(uint256 tokenId, uint256 value)
```

### UnlockPermanent

```solidity
event UnlockPermanent(uint256 tokenId, address sender, uint256 unlockTime)
```

### LockDelegateChanged

```solidity
event LockDelegateChanged(uint256 tokenId, address delegator, address fromDelegate, address toDelegate)
```

Delegate events

### AlreadyVoted

```solidity
error AlreadyVoted()
```

-----------------------------------------------------------------------
Errors
-----------------------------------------------------------------------

### InvalidNonce

```solidity
error InvalidNonce()
```

### InvalidDelegatee

```solidity
error InvalidDelegatee()
```

### InvalidSignature

```solidity
error InvalidSignature()
```

### InvalidSignatureS

```solidity
error InvalidSignatureS()
```

### LockDurationNotInFuture

```solidity
error LockDurationNotInFuture()
```

### LockDurationTooLong

```solidity
error LockDurationTooLong()
```

### LockExpired

```solidity
error LockExpired()
```

### LockNotExpired

```solidity
error LockNotExpired()
```

### NoLockFound

```solidity
error NoLockFound()
```

### NotPermanentLock

```solidity
error NotPermanentLock()
```

### PermanentLock

```solidity
error PermanentLock()
```

### SameNFT

```solidity
error SameNFT()
```

### SignatureExpired

```solidity
error SignatureExpired()
```

### ZeroAmount

```solidity
error ZeroAmount()
```

