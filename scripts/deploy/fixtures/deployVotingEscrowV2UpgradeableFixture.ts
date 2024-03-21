// test/fixtures/deployVotingEscrowV2UpgradeableFixture.ts
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployManager } from '../DeployManager'
import { logger } from '../../../hardhat/utils'
import { getDeployConfig, DeployableNetworks, FixtureOverrides } from '../deploy.config'
import {
  ERC20Mock,
  ERC20Mock__factory,
  EscrowDelegateCheckpoints__factory,
  VotingEscrowV2Upgradeable,
  VotingEscrowV2Upgradeable__factory,
} from '../../../typechain-types'

/**
 * @typedef {Object} DeployVotingEscrowV2UpgradeableFixtureParams
 * @property {HardhatRuntimeEnvironment} hre - The Hardhat runtime environment.
 * @property {DeployManager} deployManager - The deployment manager instance.
 *
 * @warning The deployment script only checks the contract overrides for the lock token.
 * Regardless of the lock token configuration, it will always deploy the EscrowDelegateCheckpoints
 * and VotingEscrowV2Upgradeable contracts. To conditionally prevent these deployments,
 * additional checks must be implemented externally.
 *
 * This fixture is responsible for deploying the VotingEscrowV2Upgradeable contract and its dependencies.
 * It uses the configuration specified in `deploy.config.ts` to determine if a new ERC20Mock token should be deployed
 * or if an existing one should be used. It also deploys the EscrowDelegateCheckpoints library and links it to
 * the VotingEscrowV2Upgradeable contract. The fixture returns the deployed contract instances and their addresses.
 */
export async function deployVotingEscrowV2UpgradeableFixture(
  hre: HardhatRuntimeEnvironment,
  deployManager: DeployManager,
  overrides: FixtureOverrides = {}
) {
  const currentNetwork = hre.network.name as DeployableNetworks
  // Hooks into the global deploy configuration defined by network
  const { contractOverrides, veDetails } = getDeployConfig(currentNetwork, overrides)

  let lockTokenAddress = contractOverrides.lockToken
  let lockToken: ERC20Mock
  if (!lockTokenAddress) {
    logger.warn(`No lockToken provided in deploy.config, deploying ERC20Mock...`)
    lockToken = await deployManager.deployContract<ERC20Mock__factory>('ERC20Mock', [
      '100000000000000000000000000000000000',
      18,
      'ERC20Mock',
      'MOCK',
    ])
    lockTokenAddress = lockToken.address
  } else {
    logger.log(`Lock token address provided, using existing ERC20 Token ${lockTokenAddress}...`, '⚙️')
    lockToken = (await hre.ethers.getContractAt('ERC20Mock', lockTokenAddress)) as ERC20Mock
  }

  let votingEscrowV2UpgradeableAddress = contractOverrides.votingEscrowV2Upgradeable
  let votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable
  let votingEscrowV2Implementation: string = 'not set'
  if (!votingEscrowV2UpgradeableAddress) {
    logger.warn(`VoteEscrowV2Upgradeable address not provided, deploying new VotingEscrowV2Upgradeable...`)
    const escrowDelegateCheckpoints = await deployManager.deployContract<EscrowDelegateCheckpoints__factory>(
      'EscrowDelegateCheckpoints',
      []
    )

    const { implementationThroughProxy, implementation } =
      await deployManager.deployUpgradeableContract<VotingEscrowV2Upgradeable__factory>(
        'VotingEscrowV2Upgradeable',
        [veDetails.name, veDetails.symbol, veDetails.version, lockTokenAddress],
        {},
        {
          libraries: {
            EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
          },
        }
      )
    logger.log(`Deployed VotingEscrowV2Upgradeable...`, '🚀')
    votingEscrowV2Upgradeable = implementationThroughProxy
    votingEscrowV2Implementation = implementation.address
  } else {
    votingEscrowV2Upgradeable = (await hre.ethers.getContractAt(
      'VotingEscrowV2Upgradeable',
      votingEscrowV2UpgradeableAddress
    )) as VotingEscrowV2Upgradeable
    logger.log(
      `VoteEscrowV2Upgradeable address provided, using existing VotingEscrowV2Upgradeable ${votingEscrowV2UpgradeableAddress}...`,
      '⚙️'
    )
  }

  return {
    contractOutput: {
      votingEscrowV2Upgradeable,
      lockToken,
    },
    addressOutput: {
      votingEscrowV2Upgradeable: votingEscrowV2Upgradeable.address,
      votingEscrowV2Implementation: votingEscrowV2Implementation,
      lockToken: lockToken.address,
    },
  }
}
