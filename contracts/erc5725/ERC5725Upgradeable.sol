// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.13;

import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
/// @dev Official ERC-5725 interface
import {IERC5725Upgradeable, IERC165Upgradeable} from "./IERC5725Upgradeable.sol";
import {IERC721Errors} from "../interfaces/IERC721Errors.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ERC5725Upgradeable is Initializable, IERC5725Upgradeable, ERC721EnumerableUpgradeable, IERC721Errors {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev mapping for claimed payouts
    mapping(uint256 => uint256) /*tokenId*/ /*claimed*/ internal _payoutClaimed;

    /// @dev Mapping from token ID to approved tokenId operator
    mapping(uint256 => address) private _tokenIdApprovals;

    /// @dev Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) /* owner */ /*(operator, isApproved)*/ internal _operatorApprovals;

    /// @dev Reserved storage space to allow for layout changes in the future.
    uint256[50] private __gap;

    constructor() {
        /// @dev Disable the initializers for implementation contracts to ensure that the contract is not left uninitialized.
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the given name and symbol.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     */
    function __ERC5725_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init(name_, symbol_);
        /// @dev Currently this call does nothing, but it is left here for future compatibility.
        __ERC721Enumerable_init();
    }

    /**
     * @notice Checks if the tokenId exists and its valid
     * @param tokenId The NFT token id
     */
    modifier validToken(uint256 tokenId) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        _;
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function claim(uint256 tokenId) external virtual override(IERC5725Upgradeable);

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function setClaimApprovalForAll(address operator, bool approved) external override(IERC5725Upgradeable) {
        _setClaimApprovalForAll(operator, approved);
        emit ClaimApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function setClaimApproval(
        address operator,
        bool approved,
        uint256 tokenId
    ) external override(IERC5725Upgradeable) validToken(tokenId) {
        _setClaimApproval(operator, tokenId);
        emit ClaimApproval(msg.sender, operator, tokenId, approved);
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function vestedPayout(uint256 tokenId) public view override(IERC5725Upgradeable) returns (uint256 payout) {
        return vestedPayoutAtTime(tokenId, block.timestamp);
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function vestedPayoutAtTime(
        uint256 tokenId,
        uint256 timestamp
    ) public view virtual override(IERC5725Upgradeable) returns (uint256 payout);

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function vestingPayout(
        uint256 tokenId
    ) public view override(IERC5725Upgradeable) validToken(tokenId) returns (uint256 payout) {
        return _payout(tokenId) - vestedPayout(tokenId);
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function claimablePayout(
        uint256 tokenId
    ) public view virtual override(IERC5725Upgradeable) validToken(tokenId) returns (uint256 payout) {
        return vestedPayout(tokenId) - _payoutClaimed[tokenId];
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function claimedPayout(
        uint256 tokenId
    ) public view override(IERC5725Upgradeable) validToken(tokenId) returns (uint256 payout) {
        return _payoutClaimed[tokenId];
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function vestingPeriod(
        uint256 tokenId
    ) public view override(IERC5725Upgradeable) validToken(tokenId) returns (uint256 vestingStart, uint256 vestingEnd) {
        return (_startTime(tokenId), _endTime(tokenId));
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function payoutToken(
        uint256 tokenId
    ) public view override(IERC5725Upgradeable) validToken(tokenId) returns (address token) {
        return _payoutToken(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * IERC5725Upgradeable interfaceId = 0xbd3a202b
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721EnumerableUpgradeable, IERC165Upgradeable) returns (bool supported) {
        return interfaceId == type(IERC5725Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC5725Upgradeable}.
     */
    function getClaimApproved(uint256 tokenId) public view returns (address operator) {
        return _tokenIdApprovals[tokenId];
    }

    /**
     * @dev Returns true if `owner` has set `operator` to manage all `tokenId`s.
     * @param owner The owner allowing `operator` to manage all `tokenId`s.
     * @param operator The address who is given permission to spend tokens on behalf of the `owner`.
     */
    function isClaimApprovedForAll(address owner, address operator) public view returns (bool isClaimApproved) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Public view which returns true if the operator has permission to claim for `tokenId`
     * @notice To remove permissions, set operator to zero address.
     *
     * @param operator The address that has permission for a `tokenId`.
     * @param tokenId The NFT `tokenId`.
     */
    function isApprovedClaimOrOwner(address operator, uint256 tokenId) public view virtual returns (bool) {
        address owner = _ownerOf(tokenId);
        return (operator == owner || isClaimApprovedForAll(owner, operator) || getClaimApproved(tokenId) == operator);
    }

    /**
     * @dev Internal function to set the operator status for a given owner to manage all `tokenId`s.
     * @notice To remove permissions, set approved to false.
     *
     * @param operator The address who is given permission to spend vested tokens.
     * @param approved The approved status.
     */
    function _setClaimApprovalForAll(address operator, bool approved) internal virtual {
        _operatorApprovals[msg.sender][operator] = approved;
    }

    /**
     * @dev Internal function to set the operator status for a given tokenId.
     * @notice To remove permissions, set operator to zero address.
     *
     * @param operator The address who is given permission to spend vested tokens.
     * @param tokenId The NFT `tokenId`.
     */
    function _setClaimApproval(address operator, uint256 tokenId) internal virtual {
        if (_ownerOf(tokenId) != msg.sender) revert ERC721IncorrectOwner(msg.sender, tokenId, _ownerOf(tokenId));
        _tokenIdApprovals[tokenId] = operator;
    }

    /**
     * @dev See {IERC721-_beforeTokenTransfer}.
     * Clears the approval of a given `tokenId` when the token is transferred or burned.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            uint256 tokenId = firstTokenId + i;
            if (from != address(0) || from != to) {
                delete _tokenIdApprovals[tokenId];
            }
        }
    }

    /**
     * @dev Internal function to get the payout token of a given vesting NFT
     *
     * @param tokenId on which to check the payout token address
     * @return address payout token address
     */
    function _payoutToken(uint256 tokenId) internal view virtual returns (address);

    /**
     * @dev Internal function to get the total payout of a given vesting NFT.
     * @dev This is the total that will be paid out to the NFT owner, including historical tokens.
     *
     * @param tokenId to check
     * @return uint256 the total payout of a given vesting NFT
     */
    function _payout(uint256 tokenId) internal view virtual returns (uint256);

    /**
     * @dev Internal function to get the start time of a given vesting NFT
     *
     * @param tokenId to check
     * @return uint256 the start time in epoch timestamp
     */
    function _startTime(uint256 tokenId) internal view virtual returns (uint256);

    /**
     * @dev Internal function to get the end time of a given vesting NFT
     *
     * @param tokenId to check
     * @return uint256 the end time in epoch timestamp
     */
    function _endTime(uint256 tokenId) internal view virtual returns (uint256);

    /**
     * @dev Checks if an address is authorized to manage the given token ID.
     * Used to verify if an address has the necessary permissions to execute actions on behalf of the token owner.
     *
     * @param owner the owner of the token
     * @param spender the address attempting to act on the token
     * @param tokenId the token ID to check for authorization
     * @return bool true if the spender is authorized, false otherwise
     */

    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }
}
