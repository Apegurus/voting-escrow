# Solidity API

## IERC721Errors

This update is included in openzeppelin/contracts@5.x, but not in openzeppelin/contracts@4.x
Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.

_Standard ERC-721 Errors_

### ERC721InvalidOwner

```solidity
error ERC721InvalidOwner(address owner)
```

_Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
Used in balance queries._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| owner | address | Address of the current owner of a token. |

### ERC721NonexistentToken

```solidity
error ERC721NonexistentToken(uint256 tokenId)
```

_Indicates a `tokenId` whose `owner` is the zero address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | Identifier number of a token. |

### ERC721IncorrectOwner

```solidity
error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner)
```

_Indicates an error related to the ownership over a particular token. Used in transfers._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | Address whose tokens are being transferred. |
| tokenId | uint256 | Identifier number of a token. |
| owner | address | Address of the current owner of a token. |

### ERC721InvalidSender

```solidity
error ERC721InvalidSender(address sender)
```

_Indicates a failure with the token `sender`. Used in transfers._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| sender | address | Address whose tokens are being transferred. |

### ERC721InvalidReceiver

```solidity
error ERC721InvalidReceiver(address receiver)
```

_Indicates a failure with the token `receiver`. Used in transfers._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | Address to which tokens are being transferred. |

### ERC721InsufficientApproval

```solidity
error ERC721InsufficientApproval(address operator, uint256 tokenId)
```

_Indicates a failure with the `operator`’s approval. Used in transfers._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| operator | address | Address that may be allowed to operate on tokens without being their owner. |
| tokenId | uint256 | Identifier number of a token. |

### ERC721InvalidApprover

```solidity
error ERC721InvalidApprover(address approver)
```

_Indicates a failure with the `approver` of a token to be approved. Used in approvals._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| approver | address | Address initiating an approval operation. |

### ERC721InvalidOperator

```solidity
error ERC721InvalidOperator(address operator)
```

_Indicates a failure with the `operator` to be approved. Used in approvals._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| operator | address | Address that may be allowed to operate on tokens without being their owner. |

