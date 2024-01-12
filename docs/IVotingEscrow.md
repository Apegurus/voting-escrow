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
event LockDurationExtended(uint256 tokenId, uint256 newUnlockTime)
```

### LockAmountIncreased

```solidity
event LockAmountIncreased(uint256 tokenId, uint256 value)
```

### UnlockPermanent

```solidity
event UnlockPermanent(uint256 tokenId, address sender, uint256 unlockTime)
```

### LockCheckpoint

```solidity
event LockCheckpoint(uint256 tokenId, int128 oldBalance, int128 newBalance)
```

Checkpoint events

### GlobalCheckpoint

```solidity
event GlobalCheckpoint(int128 oldSupply, int128 newSupply)
```

### DelegateCheckpoint

```solidity
event DelegateCheckpoint(address delegatee, uint256 oldVotes, uint256 newVotes)
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
event LockDurationExtended(uint256 tokenId, uint256 newUnlockTime)
```

### LockAmountIncreased

```solidity
event LockAmountIncreased(uint256 tokenId, uint256 value)
```

### UnlockPermanent

```solidity
event UnlockPermanent(uint256 tokenId, address sender, uint256 unlockTime)
```

### LockCheckpoint

```solidity
event LockCheckpoint(uint256 tokenId, int128 oldBalance, int128 newBalance)
```

Checkpoint events

### GlobalCheckpoint

```solidity
event GlobalCheckpoint(int128 oldSupply, int128 newSupply)
```

### DelegateCheckpoint

```solidity
event DelegateCheckpoint(address delegatee, uint256 oldVotes, uint256 newVotes)
```

Delegate events

### DelegateChanged

```solidity
event DelegateChanged(uint256 tokenId, address fromDelegate, address toDelegate)
```

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

