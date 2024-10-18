// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVersionable {
    function VERSION() external view returns (string memory);
}
