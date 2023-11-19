// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Import this file to use console.log
// import "hardhat/console.sol";

/* solhint-disable not-rely-on-time */
contract Lock {
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    uint256 public unlockTime;
    address payable public owner;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when the contract is withdrawn
    /// @param amount The amount of wei withdrawn
    /// @param when The timestamp of the block when the withdraw happened
    event Withdrawal(uint256 amount, uint256 when);

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(uint256 _unlockTime, address payable _owner) payable {
        require(block.timestamp < _unlockTime, "Unlock time should be in the future");

        unlockTime = _unlockTime;
        owner = _owner;
    }

    receive() external payable {}

    /// -----------------------------------------------------------------------
    /// Public functions
    /// -----------------------------------------------------------------------

    /// @notice Withdraw all the funds
    function withdraw() public {
        // Uncomment this line to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        require(msg.sender == owner, "You aren't the owner");

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }
}
