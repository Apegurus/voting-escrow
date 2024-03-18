// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IEscrowWeightLens, IVotingEscrowV2Upgradeable} from "./IEscrowWeightLens.sol";

/**
 * @title Escrow Weight Lens
 * @notice Provides functions to calculate the weight of escrowed tokens based on lock duration
 */
contract EscrowWeightLens is IEscrowWeightLens, Initializable, OwnableUpgradeable {
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /** @notice The Voting Escrow contract interface */
    IVotingEscrowV2Upgradeable public votingEscrow;

    /** @notice Array of duration thresholds for weight calculation */
    uint256[] public durationDaysThresholds;

    /** @notice Array of multipliers corresponding to the duration thresholds */
    uint256[] public multipliers; // Multipliers with precision of 1000 (e.g., 1500 represents 1.5)

    /** @notice Precision of the multipliers */
    uint256 public constant MULTIPLIER_PRECISION = 1000;

    /// -----------------------------------------------------------------------
    /// Events & Errors
    /// -----------------------------------------------------------------------
    // See IEscrowWeightLens.sol for event & error definitions

    /** @notice Constructor that disables initializers */
    constructor() {
        /// @dev prevent initialization of the implementation
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the voting escrow address and multipliers
     * @param _votingEscrowAddress The address of the Voting Escrow contract
     * @param _durationDaysThresholds Array of duration thresholds for weight calculation
     * - MUST be in descending order
     * @param _multipliers Array of multipliers corresponding to the duration thresholds
     * - MUST be gte MULTIPLIER_PRECISION
     */
    function initialize(
        address _votingEscrowAddress,
        uint256[] memory _durationDaysThresholds,
        uint256[] memory _multipliers
    ) public initializer {
        __Ownable_init();
        votingEscrow = IVotingEscrowV2Upgradeable(_votingEscrowAddress);
        _setMultipliers(_durationDaysThresholds, _multipliers);
    }

    /// -----------------------------------------------------------------------
    /// Duration Threshold + Multiplier Management
    /// -----------------------------------------------------------------------
    /**
     * @notice Retrieves the duration thresholds and their corresponding multipliers
     * @return _durationDaysThresholds The array of duration thresholds
     * @return _multipliers The array of multipliers corresponding to the duration thresholds
     */
    function getMultipliers()
        external
        view
        returns (uint256[] memory _durationDaysThresholds, uint256[] memory _multipliers)
    {
        return (durationDaysThresholds, multipliers);
    }

    /**
     * @notice Sets the multipliers for the contract
     * @param _durationDaysThresholds Array of duration thresholds for weight calculation
     * - MUST be in descending order
     * @param _multipliers Array of multipliers corresponding to the duration thresholds
     * @dev Only callable by the owner
     */
    function setMultipliers(
        uint256[] calldata _durationDaysThresholds,
        uint256[] calldata _multipliers
    ) external onlyOwner {
        _setMultipliers(_durationDaysThresholds, _multipliers);
    }

    /**
     * @notice Gets the multiplier for a given number of days locked
     * @param durationDays The number of days for which the tokens are locked
     * @return multiplier The multiplier corresponding to the given number of days locked
     * @return tier The tier corresponding to the given number of days locked
     */
    function getMultiplierForDaysLocked(uint256 durationDays) external view returns (uint256 multiplier, uint256 tier) {
        return _getMultiplierForSecondsLocked(durationDays * 1 days);
    }

    /**
     * @notice Internal function to set the multipliers
     * @param _durationDaysThresholds Array of duration thresholds for weight calculation
     * - MUST be in descending order
     * @param _multipliers Array of multipliers corresponding to the duration thresholds
     * - MUST be gte MULTIPLIER_PRECISION
     */
    function _setMultipliers(uint256[] memory _durationDaysThresholds, uint256[] memory _multipliers) internal {
        if (_durationDaysThresholds.length != _multipliers.length) {
            revert MismatchedLengths();
        }
        for (uint256 i = 1; i < _durationDaysThresholds.length; i++) {
            if (_durationDaysThresholds[i - 1] < _durationDaysThresholds[i]) {
                /// @dev _getMultiplierForSecondsLocked expects descending order
                revert DurationsNotDescendingOrder();
            }
            if (_multipliers[i] < MULTIPLIER_PRECISION) {
                /// @dev multiplier of 1 is the floor
                revert MultiplierBelowPrecision();
            }
        }
        durationDaysThresholds = _durationDaysThresholds;
        multipliers = _multipliers;
        emit MultipliersUpdated(_durationDaysThresholds, _multipliers);
    }

    /**
     * @notice Internal function to get the multiplier for a given duration
     * @param durationSeconds The duration for which to get the multiplier
     * @return multiplier The multiplier corresponding to the given duration
     * @return tier The tier corresponding to the given duration
     */
    function _getMultiplierForSecondsLocked(
        uint256 durationSeconds
    ) internal view returns (uint256 multiplier, uint256 tier) {
        multiplier = MULTIPLIER_PRECISION; // Start with the default multiplier of 1
        // Loop through each threshold to find the appropriate multiplier
        for (uint256 i = 0; i < durationDaysThresholds.length; i++) {
            // Check if the duration in seconds is greater than or equal to the threshold
            // durationDaysThresholds is in descending order, so the first match is the correct one
            if (durationSeconds >= durationDaysThresholds[i] * 1 days) {
                multiplier = multipliers[i];
                /// @dev tier is 1-indexed
                tier = multipliers.length - i;
                break;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Escrow Weight Calculation
    /// -----------------------------------------------------------------------

    /**
     * @notice Calculates the total weight of an owner's escrowed tokens
     * @param escrowOwner The address of the token owner
     * @return totalWeight The total weight of the owner's escrowed tokens
     * @return maxMultiplier The maximum multiplier for the owner's escrowed tokens
     * @return maxTier The tier corresponding to the maximum multiplier
     */
    function getEscrowWeight(
        address escrowOwner
    ) external view returns (uint256 totalWeight, uint256 maxMultiplier, uint256 maxTier) {
        uint256 ownerBalance = votingEscrow.balanceOf(escrowOwner);
        if (ownerBalance == 0) {
            return (0, 0, 0);
        }

        for (uint256 i = 0; i < ownerBalance; i++) {
            uint256 tokenId = votingEscrow.tokenOfOwnerByIndex(escrowOwner, i);
            IVotingEscrowV2Upgradeable.LockDetails memory lock = votingEscrow.lockDetails(tokenId);
            (uint256 weight, uint256 multiplier, uint256 tier) = _calculateWeight(lock);
            totalWeight += weight;
            if (tier > maxTier) {
                maxTier = tier;
                maxMultiplier = multiplier;
            }
        }
    }

    /**
     * @notice Calculates the total weight for a given set of token IDs
     * @param escrowOwner The address of the token owner
     * @param tokenIds An array of token IDs to calculate the weight for
     * @return totalWeight The total weight for the given token IDs
     */
    function getEscrowWeightForTokenIds(
        address escrowOwner,
        uint256[] calldata tokenIds
    ) external view returns (uint256 totalWeight, uint256 maxMultiplier, uint256 maxTier) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (votingEscrow.ownerOf(tokenIds[i]) != escrowOwner) {
                revert IVotingEscrowV2Upgradeable.NotLockOwner();
            }
            IVotingEscrowV2Upgradeable.LockDetails memory lock = votingEscrow.lockDetails(tokenIds[i]);
            (uint256 weight, uint256 multiplier, uint256 tier) = _calculateWeight(lock);
            totalWeight += weight;
            if (tier > maxTier) {
                maxTier = tier;
                maxMultiplier = multiplier;
            }
        }
    }

    /**
     * @notice Internal function to calculate the weight of a given lock
     * @param lock The lock details for which to calculate the weight
     * @return weight The calculated weight of the lock
     */
    function _calculateWeight(
        IVotingEscrowV2Upgradeable.LockDetails memory lock
    ) internal view returns (uint256 weight, uint256 multiplier, uint256 tier) {
        // Check if the current block timestamp is within the lock period of the token.
        // If the current time is before the start time or after the end time of the lock,
        // the token is not considered to be in the lock period, and its weight is zero.
        if (block.timestamp < lock.startTime || block.timestamp > lock.endTime) {
            return (0, 0, 0); // Token is outside the lock period, so its weight is zero.
        }

        // Calculate the remaining duration of the lock in seconds.
        // This is done by subtracting the current block timestamp from the lock's end time.
        uint256 duration = lock.endTime - block.timestamp;
        (multiplier, tier) = _getMultiplierForSecondsLocked(duration);

        // precision allows for fractional multipliers
        weight = (lock.amount * multiplier) / MULTIPLIER_PRECISION;
    }
}
