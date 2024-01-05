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

### AlreadyVoted

```solidity
error AlreadyVoted()
```

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

