# Foundry

## Resources

* <https://github.com/dabit3/foundry-cheatsheet>
* <https://github.com/crisgarner/awesome-foundry>

## Foundry Cheatcodes

* [Foundry Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes)

## Console Logging

*To run with logs:*

* `forge test -vv` // forge doesn't output logs by default
* <https://book.getfoundry.sh/reference/forge-std/console-log>

## Gas Reports

`forge test --gas-report`  
<https://book.getfoundry.sh/forge/gas-reports>  

**In `foundry.toml.`:**

Add or ignore contracts from gas reports.

1. `gas_reports = ["*"]` (all contracts)
2. `gas_reports = ["MyContract", "MyContractFactory"]`
3. `gas_reports_ignore = ["Example"]`

## New Project Setup

This project is setup is Foundry already, but these are the steps needed to setup this project.

1. [Install Foundry if Needed](https://book.getfoundry.sh/getting-started/installation)
2. Setup [foundry.toml](./foundry.toml) to match hardhat directories.
3. `forge install foundry-rs/forge-std` to install the forge std library.
