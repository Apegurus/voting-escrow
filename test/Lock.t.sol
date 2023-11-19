// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {LockFixture} from "./fixtures/LockFixture.t.sol";
import {Lock} from "../contracts/Lock.sol";

contract LockTest is LockFixture, Test {
    event Withdrawal(uint256 amount, uint256 when);

    /// @dev setUp: An optional function invoked before each test case is run.
    function setUp() public {
        deployOneYearLockFixture();
    }

    function test_SetUnlockTime() public {
        assertEq(lock.unlockTime(), unlockTime);
    }

    function test_SetOwner() public {
        assertEq(lock.owner(), owner);
    }

    function test_ReceiveAndStoreFunds() public {
        assertEq(address(lock).balance, lockedAmount);
    }

    function testFail_UnlockTimeNotInFuture() public {
        // vm.expectRevert(); // When `testFail`, this isn't necessary.
        vm.prank(address(owner));
        lock.withdraw();
    }

    function testFail_WithdrawTooSoon() public {
        vm.prank(address(owner));
        lock.withdraw();
    }

    function testFail_WithdrawFromAnotherAccount() public {
        Lock newLock = Lock(lock);
        newLock.withdraw();
    }

    function test_WithdrawAfterUnlockTime() public {
        // Increase block time to unlockTime
        vm.warp(unlockTime);
        vm.prank(address(owner));
        lock.withdraw();
    }

    function test_EmitWithdrawalEvent() public {
        // Increase block time to unlockTime
        vm.warp(unlockTime);
        vm.prank(address(owner));
        // https://book.getfoundry.sh/cheatcodes/expect-emit
        vm.expectEmit(true, true, false, false);
        // vm.expectEmit(address(lock));
        // The event we expect
        emit Withdrawal(address(lock).balance, block.timestamp);
        lock.withdraw();
    }

    function test_TransferFundsToOwner() public {
        uint256 initialBalance = address(owner).balance;
        // Increase block time to unlockTime
        vm.warp(unlockTime);
        // console.log(address(owner), lock.owner());
        vm.prank(address(owner));
        lock.withdraw();
        assertEq(address(owner).balance, initialBalance + lockedAmount);
    }
}
