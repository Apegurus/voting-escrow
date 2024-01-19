# Voting Escrow V2 w/ Delegation

[![lint & test](https://github.com/Apegurus/voting-escrow/actions/workflows/lint-test.yml/badge.svg)](https://github.com/Apegurus/voting-escrow/actions/workflows/lint-test.yml)
[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](./docs/)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

Voting Escrow based off of the popular Curve Voting Escrow contract. Lock protocol tokens for a period of time and receive voting power in return. Voting Escrow V2 adds delegation to the mix, which isn't available in the original contract, among other improvements and standards.

**V2 Additions**

- [ERC-5725](https://eips.ethereum.org/EIPS/eip-5725) Transferrable Vesting NFT: Voting Escrow V2 is ERC-5725 compliant which allows these tokens to be easily integrated into NFT marketplaces and other platforms.
- [ERC-6372](https://eips.ethereum.org/EIPS/eip-6372): Contract Clock

## Deployment and Verification

This project uses special tasks, adapted from Balancer protocol, to deploy and verify contracts which provides methods for saving custom outputs and easily verifying contracts as well as compartmentalizing different types of deployments.

### Configuration

- Copy [.env.example](./.env.example) and rename to `.env`
  - Provide the necessary `env` variables before deployment/verification
  - `_MNEMONIC` for deployments
  - `_API_KEY` for verifications
- [hardhat.config.ts](./hardhat.config.ts): Can be configured with additional networks if needed
  - [hardhat/types.ts](./hardhat/types.ts): Holds network typings which can be updated with more networks.
- Configure Deployment Variables for each network in [deploy.config.ts](./scripts/deploy/deploy.config.ts).
- Ensure Etherscan API Keys are configured in [hardhat.config.ts](./hardhat.config.ts) under `etherscan`.

## Deployment & Verification

1. Create a deployment script in [scripts/deploy](./scripts/deploy/). (Use [deployLock](./scripts/deploy/deployLock.ts) as a template.)
2. Use [DeployManager](./scripts/deploy/DeployManager.ts) to deploy contracts to easily deploy, verify and save the output to the [deployments](./deployments/) directory.
3. Run a deployment with `npx hardhat run ./scripts/deploy/deployLock.ts --network <network>`
4. Etherscan-like API key should be stored in [hardhat.config.ts](./hardhat.config.ts) under `etherscan` and the [DeployManager](./scripts/deploy/DeployManager.ts) can use that to verify contracts after deployment.

## Linting

This project uses Prettier, an opinionated code formatter, to keep code styles consistent. This project has additional plugins for Solidity support as well.

- `yarn lint`: Check Solidity files & TS/JS files
- `yarn lint:fix`: Fix Solidity files & TS/JS files

### Linting Solidity Code

- [prettier.config.js](./prettier.config.js): Provide config settings for Solidity under `overrides`.
- [.solhint.json](./.solhint.json): Provide config settings for `solhint`.  

- `yarn lint:sol`: Check Solidity files
- `yarn lint:sol:fix`: Fix Solidity files

## Build/Publish as NPM Package

1. Currently this repo uses `tsc` to build files to `dist/`.
2. Files are cherry picked in [package.json](./package.json) under `files` as there are a lot of support files included in this repo.

_Consider including only what is needed._

```json
  "files": [
    "dist/index.js",
    "dist/index.d.ts",
    "dist/src/**/*",
    "dist/typechain-types/**/*",
    // "dist/artifacts/**/*"
  ],
```

## Gotchas

1. Put single quotes around globs in `package.json`:
   - `"lint:ts": "prettier --check './{scripts,tasks,src,hardhat,test}/**/*.ts'"`
