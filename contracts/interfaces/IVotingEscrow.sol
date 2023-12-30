// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

interface IVotingEscrow is IERC5805 {
    struct LockDetails {
        int128 amount; /// @dev amount of tokens locked
        uint256 startTime; /// @dev when locking started
        uint256 endTime; /// @dev when locking ends
        bool isPermanent;
        // TODO: Permanent lock?
    }
}
