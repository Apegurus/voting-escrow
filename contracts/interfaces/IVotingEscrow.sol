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

    error AlreadyVoted();
    error AmountTooBig();
    error ERC721ReceiverRejectedTokens();
    error ERC721TransferToNonERC721ReceiverImplementer();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidSignatureS();
    error InvalidManagedNFTId();
    error LockDurationNotInFuture();
    error LockDurationTooLong();
    error LockExpired();
    error LockNotExpired();
    error NoLockFound();
    error NonExistentToken();
    error NotApprovedOrOwner();
    error NotDistributor();
    error NotEmergencyCouncilOrGovernor();
    error NotGovernor();
    error NotGovernorOrManager();
    error NotManagedNFT();
    error NotManagedOrNormalNFT();
    error NotLockedNFT();
    error NotNormalNFT();
    error NotPermanentLock();
    error NotOwner();
    error NotTeam();
    error NotVoter();
    error OwnershipChange();
    error PermanentLock();
    error SameAddress();
    error SameNFT();
    error SameState();
    error SplitNoOwner();
    error SplitNotAllowed();
    error SignatureExpired();
    error TooManyTokenIDs();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroBalance();
}
