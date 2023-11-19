# Testing Features

This repo is equipped with advanced testing features. See below for more info.

_Some features are apart of gitmodules which may need to be initialized. Run `yarn init:submodules` if you run into issues._

## Unit Testing

1. [hardhat testing](https://hardhat.org/hardhat-runner/docs/guides/test-contracts)
   1. `yarn test`
   2. See [template.spec.ts](./test/template.spec.ts) for a template of how to write tests.
2. [forge testing](https://github.com/foundry-rs/foundry)
   - See [README-foundry.md](./README-foundry.md) for more info.
   - `yarn forge:test`
   - See [Lock.t.sol](./test/forge/Lock.t.sol) for an example of how to write tests with Foundry.
3. [VS-Code Mocha Test Explorer](https://marketplace.visualstudio.com/items?itemName=hbenl.vscode-mocha-test-adapter): Use Mocha Test Explorer to easily choose which tests to run. (Smart Contracts must be manually compiled between updates.)
4. Debug Solidity unit tests with [VS-Code debugger](https://code.visualstudio.com/docs/editor/debugging)
5. [solidity-coverage](https://www.npmjs.com/package/solidity-coverage): Generate a coverage report by running `yarn test:coverage`
6. [hardhat-gas-reporter](https://www.npmjs.com/package/hardhat-gas-reporter): Check the gas costs of running test transactions with `yarn test:gas`
    - _these tests run slower than `yarn test`_
7. [hardhat-contract-sizer](https://www.npmjs.com/package/hardhat-contract-sizer): Check the size of the contracts being developed with `yarn size`

## Security Testing

<!-- TODO: Add slither -->
1. [semgrep smart contract](https://github.com/Decurity/semgrep-smart-contracts) which uses semgrep rules that look for patterns of vulnerabilities in smart contracts based on actual DeFi exploits as well as gas optimization rules that can be used as a part of the CI pipeline.
   - Run `yarn semgrep` to run the semgrep rules locally.
   - There is also a [semgrep GitHub Action](../.github/workflows/semgrep.yml) that runs on pull requests.

## Fork Testing

This repo has support for forking networks and running tests against the forked network. Update [hardhat-fork.config.ts](./hardhat-fork.config.ts) with the network you want to fork and run `yarn test:fork` to run tests against the forked network with the tests in [test-fork](./test-fork).

### Tenderly TX Simulations

TX Simulations are a form of fork testing and are valuable to test against mainnet forked networks. This repo has support for sending TX data to the simulator API for debugging and simulation.

- See [tenderly.ts](./hardhat/utils/tenderly.ts) for more info.
- See [simulateTxs script](./scripts/simulate/simulateTxs.ts) for an example of how to send TX data to the simulator API.

<!-- - // TODO: https://www.npmjs.com/package/@tenderly/hardhat-tenderly -->
- [Tenderly Simulation API](https://docs.tenderly.co/simulations-and-forks/simulation-api): This repo has support for sending TX data to the simulator API for debugging and simulation.
