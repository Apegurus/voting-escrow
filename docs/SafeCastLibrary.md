# Solidity API

## SafeCastLibrary

Safely convert unsigned and signed integers without overflow / underflow

### SafeCastOverflow

```solidity
error SafeCastOverflow()
```

### SafeCastUnderflow

```solidity
error SafeCastUnderflow()
```

### toInt128

```solidity
function toInt128(uint256 value) internal pure returns (int128)
```

_Safely convert uint256 to int128_

### toUint48

```solidity
function toUint48(uint256 value) internal pure returns (uint48)
```

_Returns the downcasted uint48 from uint256, reverting on
overflow (when the input is greater than largest uint48).

Counterpart to Solidity's `uint48` operator.

Requirements:

- input must fit into 48 bits_

### toUint256

```solidity
function toUint256(int128 value) internal pure returns (uint256)
```

_Safely convert int128 to uint256_

## SafeCastLibrary

Safely convert unsigned and signed integers without overflow / underflow

### SafeCastOverflow

```solidity
error SafeCastOverflow()
```

### SafeCastUnderflow

```solidity
error SafeCastUnderflow()
```

### toInt128

```solidity
function toInt128(uint256 value) internal pure returns (int128)
```

_Safely convert uint256 to int128_

### toUint48

```solidity
function toUint48(uint256 value) internal pure returns (uint48)
```

_Returns the downcasted uint48 from uint256, reverting on
overflow (when the input is greater than largest uint48).

Counterpart to Solidity's `uint48` operator.

Requirements:

- input must fit into 48 bits_

### toUint256

```solidity
function toUint256(int128 value) internal pure returns (uint256)
```

_Safely convert int128 to uint256_

### toUint256

```solidity
function toUint256(uint128 value) internal pure returns (uint256)
```

_Safely convert uint128 to uint256_

### toInt128

```solidity
function toInt128(int256 value) internal pure returns (int128 downcasted)
```

_Returns the downcasted int128 from int256, reverting on overflow
(when the input is less than smallest int128 or greater than largest int128)._

### toInt256

```solidity
function toInt256(uint256 value) internal pure returns (int256)
```

_Converts an unsigned uint256 into a signed int256._

