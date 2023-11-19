// contracts/Dummy.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @dev This contract enables hardhat to compile the builds for upgradeable deployments
contract OpenZeppelinImports {
    // No implementation required
}
