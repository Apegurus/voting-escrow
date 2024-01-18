// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {VotingEscrow} from "../VotingEscrow.sol";
import {EscrowDelegateCheckpoints} from "../libraries/EscrowDelegateCheckpoints.sol";
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
        uint256[] memory _value,
        uint256[] memory _lockDuration,
        address[] memory _to,
        address[] memory _delegatee,
        bool[] memory _permanent
    ) public {
        for (uint256 i = 0; i < _value.length; i++) {
            votingEscrow.createDelegatedLockFor(_value[i], _lockDuration[i], _to[i], _delegatee[i], _permanent[i]);
        }
    }

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    ///      Fetches last user point prior to the CLOCK_UNIT before the timestamp
    /// @param _tokenId NFT for lock
    /// @param _timestamp Epoch time to return voting power at
    /// @return balance ser voting power
    function balanceOfLockAt(uint256 _tokenId, uint256 _timestamp) external view returns (uint256 balance) {
        (uint256 amount, uint256 startTime, uint256 endTime, bool isPermanent) = votingEscrow.lockDetails(_tokenId);
        if (isPermanent) return amount;
        if (startTime > _timestamp) return 0;
        if (endTime < _timestamp) return 0;
        int128 slope = amount.toInt128() / EscrowDelegateCheckpoints.MAX_TIME;
        balance = (slope * ((endTime).toInt128() - (_timestamp).toInt128())).toUint256();
    }
}
