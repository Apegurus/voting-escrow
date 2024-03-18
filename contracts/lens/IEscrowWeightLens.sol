// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IVotingEscrowV2Upgradeable} from "../interfaces/IVotingEscrowV2Upgradeable.sol";

interface IEscrowWeightLens {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    error DurationsNotDescendingOrder();
    error MismatchedLengths();
    error MultiplierBelowPrecision();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    event MultipliersUpdated(uint256[] durationThresholds, uint256[] multipliers);

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------
    function initialize(
        address _votingEscrowAddress,
        uint256[] memory _durationThresholds,
        uint256[] memory _multipliers
    ) external;

    /// -----------------------------------------------------------------------
    /// Multiplier Management
    /// -----------------------------------------------------------------------
    function MULTIPLIER_PRECISION() external view returns (uint256);
    function durationDaysThresholds(uint256 index) external view returns (uint256);
    function multipliers(uint256 index) external view returns (uint256);
    function setMultipliers(uint256[] memory _durationDaysThresholds, uint256[] memory _multipliers) external;
    function getMultiplierForDaysLocked(uint256 durationDays) external view returns (uint256 multiplier, uint256 tier);

    /// -----------------------------------------------------------------------
    /// Escrow Weight Calculation
    /// -----------------------------------------------------------------------
    function getEscrowWeight(
        address escrowOwner
    ) external view returns (uint256 totalWeight, uint256 maxMultiplier, uint256 maxTier);
    function getEscrowWeightForTokenIds(
        address escrowOwner,
        uint256[] memory tokenIds
    ) external view returns (uint256 totalWeight, uint256 maxMultiplier, uint256 maxTier);

    /// -----------------------------------------------------------------------
    /// Voting Escrow Reference
    /// -----------------------------------------------------------------------
    function votingEscrow() external view returns (IVotingEscrowV2Upgradeable);
}
