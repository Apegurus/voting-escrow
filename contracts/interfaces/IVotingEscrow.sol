// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721, IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IVotes} from "./IVotes.sol";

interface IVotingEscrow {
    struct LockDetails {
        uint256 amount; /// @dev amount of tokens locked
        uint128 startTime; /// @dev when locking started
        uint128 endTime; /// @dev when locking ends
        bool isPermanent;
        // TODO: Permanent lock?
    }

    struct UserPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
        uint256 permanent;
    }

    struct GlobalPoint {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
        uint256 permanentLockBalance;
    }

    /// @notice A checkpoint for recorded delegated voting weights at a certain timestamp
    struct Checkpoint {
        uint256 fromTimestamp;
        address owner;
        uint256 delegatedBalance;
        uint256 delegatee;
    }

    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME
    }

    /// @notice Total count of epochs witnessed since contract creation
    // function epoch() external view returns (uint256);

    /// @notice Aggregate permanent locked balances
    // function permanentLockBalance() external view returns (uint256);
}
