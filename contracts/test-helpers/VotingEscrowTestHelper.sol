// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VotingEscrow} from "../VotingEscrow.sol";

contract VotingEscrowTestHelper {
    VotingEscrow public votingescrow;

    constructor(address _votingEscrow) {
        votingescrow = VotingEscrow(_votingEscrow);
        votingescrow.token().approve(address(votingescrow), type(uint256).max);
    }

    function createManyLocks(
        int128[] memory _value,
        uint256[] memory _lockDuration,
        address[] memory _to,
        bool[] memory _permanent
    ) public {
        for (uint256 i = 0; i < _value.length; i++) {
            votingescrow.createLockFor(_value[i], _lockDuration[i], _to[i], _permanent[i]);
        }
    }
}
