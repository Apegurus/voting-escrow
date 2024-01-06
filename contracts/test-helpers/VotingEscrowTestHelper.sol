// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {VotingEscrow} from "../VotingEscrow.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";

contract VotingEscrowTestHelper {
    VotingEscrow public votingEscrow;
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;

    constructor(address _votingEscrow) {
        votingEscrow = VotingEscrow(_votingEscrow);
        votingEscrow.token().approve(address(votingEscrow), type(uint256).max);
    }

    function createManyLocks(
        int128[] memory _value,
        uint256[] memory _lockDuration,
        address[] memory _to,
        bool[] memory _permanent
    ) public {
        for (uint256 i = 0; i < _value.length; i++) {
            votingEscrow.createLockFor(_value[i], _lockDuration[i], _to[i], _permanent[i]);
        }
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    ///      Fetches last user point prior to the CLOCK_UNIT before the timestamp
    /// @param _tokenId NFT for lock
    /// @param _timestamp Epoch time to return voting power at
    /// @return balance ser voting power
    function balanceOfLockAt(uint256 _tokenId, uint256 _timestamp) external view returns (int128 balance) {
        (int128 amount, , uint256 endTime, bool isPermanent) = votingEscrow.lockDetails(_tokenId);
        if (isPermanent) return amount;
        if (endTime < _timestamp) return 0;
        int128 slope = (amount * votingEscrow.PRECISION()) / votingEscrow.MAX_TIME();
        balance = (slope * (endTime - _timestamp).toInt128()) / votingEscrow.PRECISION();
    }
}
