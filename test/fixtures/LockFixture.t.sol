// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Lock} from "../../contracts/Lock.sol";
import {console} from "forge-std/console.sol";

contract LockFixture {
    Lock public lock;
    uint256 public unlockTime;
    uint256 public lockedAmount;
    address public owner;
    address public otherAccount;

    function deployOneYearLockFixture() public returns (Lock) {
        uint256 ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
        uint256 ONE_GWEI = 1_000_000_000;

        lockedAmount = ONE_GWEI;
        unlockTime = block.timestamp + ONE_YEAR_IN_SECS;
        owner = msg.sender;

        lock = new Lock(unlockTime, payable(owner));
        address payable lockAddress = payable(address(lock));
        lockAddress.transfer(lockedAmount);

        return lock;
    }

    function deployConfigurableLockFixture(uint256 _lockedAmount, uint256 _unlockTimeInSeconds) public returns (Lock) {
        lockedAmount = _lockedAmount;
        unlockTime = block.timestamp + _unlockTimeInSeconds;
        owner = msg.sender;
        lock = new Lock(unlockTime, payable(owner));
        address payable lockAddress = payable(address(lock));
        lockAddress.transfer(lockedAmount);

        return lock;
    }
}
