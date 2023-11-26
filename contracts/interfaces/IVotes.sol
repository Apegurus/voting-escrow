// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";

/// Modified IVotes interface for tokenId based voting
interface IVotes is IERC6372 {
    /**
     * @dev The signature used has expired.
     */
    error VotesExpiredSignature(uint256 expiry);

    /**
     * @dev Emitted when an account changes their delegate.
     */
    event DelegateChanged(address indexed delegator, uint256 indexed fromDelegate, uint256 indexed toDelegate);

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of voting units.
     */
    event DelegateVotesChanged(uint256 indexed delegate, uint256 previousVotes, uint256 newVotes);

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     */
    function getPastVotes(uint256 tokenId, uint256 timepoint) external view returns (uint256);

    /**
     * @dev Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     */
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);

    /**
     * @dev Returns the delegate that `account` has chosen.
     */
    function delegates(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(uint256 delegator, uint256 delegatee) external;

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function delegateBySig(uint256 delegator, uint256 delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
