# Hardhat w/ Foundry Template - _by [DeFiFoFum](https://github.com/defifofum)_ <img src="https://avatars.githubusercontent.com/u/78645267?v=4" alt="DeFiFoFum Avatar" width="25px">
<!-- 
  FIXME: Update `DeFiFoFum/hardhat-template` based on current repo 
  1. Find All (CMD/CTRL + SHIFT + F)
  2. Search for: DeFiFoFum/hardhat-template
  3. Replace with <user>/<your-repo>
  -->
[![lint & test](https://github.com/DeFiFoFum/hardhat-template/actions/workflows/lint-test.yml/badge.svg)](https://github.com/DeFiFoFum/hardhat-template/actions/workflows/lint-test.yml)
[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](./docs/)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

Solidity Smart Contract development template using modern Web3 frameworks/tools including Hardhat, Typechain and more.

## Features

_**For testing features see [README-testing.md](./README-testing.md)**_

- [Foundry Smart Contract Development ToolChain](https://book.getfoundry.sh/)
  - See [README-foundry.md](./README-foundry.md) for more info.
- Contract Support
  - [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/): Trusted smart contract standards
  - [Openzeppelin Contracts Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable): Upgradeable smart contract support
- Typescript
  - [Typechain](https://www.npmjs.com/package/typechain): Generate smart contract typings for Ethers during
- Docs
  - [Hardhat Docgen](https://www.npmjs.com/package/hardhat-docgen): Generate a static documentation site from NatSpec comments automatically on compilation with Hardhat.
compilation.
- Linting
  - [Prettier](https://prettier.io/): Most popular opinionated code formatter.
    - [Prettier Config](https://prettier.io/docs/en/configuration.html)
  - [Prettier Solidity plugin](https://www.npmjs.com/package/prettier-plugin-solidity): A Prettier plugin for automatically formatting your Solidity code.
  - [Solhint](https://www.npmjs.com/package/solhint): Open source project for linting Solidity code. This project provides both Security and Style Guide validations.
    - [solhint.config.ts](./solhint.config.js) is full featured and support Solidity style guide recommendations.
  - [Hardhat Contract Sizer](https://www.npmjs.com/package/hardhat-contract-sizer)
- [Build/Publish as NPM Package](#buildpublish-as-npm-package): This repo is setup to build important files into a publishable NPM package. (See below for more info)

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
