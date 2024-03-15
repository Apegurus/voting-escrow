import { ethers, network } from 'hardhat'
import { logger } from '../../../hardhat/utils'
import { DeployManager } from '../DeployManager'
import { DeployableNetworks, FixtureOverrides, getDeployConfig } from '../deploy.config'
import { deployVotingEscrowV2UpgradeableFixture } from './deployVotingEscrowV2UpgradeableFixture'
import { EscrowWeightLens, EscrowWeightLens__factory, VotingEscrowV2Upgradeable } from '../../../typechain-types'

export async function deployEscrowWeightLensFixture(
  _ethers: typeof ethers,
  deployManager: DeployManager,
  overrides: FixtureOverrides = {}
) {
  const currentNetwork = network.name as DeployableNetworks
  const {
    accounts: { adminAddress },
    veDetails,
    escrowWeightLens: escrowWeightLensConfig,
    contractOverrides,
  } = getDeployConfig(currentNetwork, overrides)

  let votingEscrowV2UpgradeableAddress = contractOverrides.votingEscrowV2
  let votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable
  if (!votingEscrowV2UpgradeableAddress) {
    const votingEscrowOutput = await deployVotingEscrowV2UpgradeableFixture(_ethers, deployManager, overrides)
    votingEscrowV2UpgradeableAddress = votingEscrowOutput.addresses.votingEscrowV2Upgradeable
    votingEscrowV2Upgradeable = votingEscrowOutput.contracts.votingEscrowV2Upgradeable
  } else {
    votingEscrowV2Upgradeable = await _ethers.getContractAt(
      'VotingEscrowV2Upgradeable',
      votingEscrowV2UpgradeableAddress
    )
  }

  let escrowWeightLensAddress = contractOverrides.escrowWeightLens
  let escrowWeightLens: EscrowWeightLens
  let escrowWeightLensImplementation: string = 'not set'
  if (!escrowWeightLensAddress) {
    logger.log(`deployEscrowWeightLens: escrowWeightLensAddress not provided, deploying new EscrowWeightLens`, '🚀')

    const { implementationThroughProxy, implementation } =
      await deployManager.deployUpgradeableContract<EscrowWeightLens__factory>(
        'EscrowWeightLens',
        [
          votingEscrowV2UpgradeableAddress,
          escrowWeightLensConfig.durationDaysThresholds,
          escrowWeightLensConfig.multipliers,
        ],
        { proxyAdminAddress: contractOverrides.proxyAdminAddress }
      )
    logger.log(`Deployed EscrowWeightLens...`, '🚀')
    escrowWeightLens = implementationThroughProxy
    escrowWeightLensImplementation = implementation.address
  } else {
    escrowWeightLens = await ethers.getContractAt('EscrowWeightLens', votingEscrowV2UpgradeableAddress)
  }

  return {
    addresses: {
      escrowWeightLens: escrowWeightLens.address,
      escrowWeightLensImplementation,
    },
    contracts: {
      escrowWeightLens,
      votingEscrowV2Upgradeable,
    },
  }
}
