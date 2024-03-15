import { ethers, network } from 'hardhat'
import {
  ERC20Mock__factory,
  VotingEscrowV2Upgradeable,
  VotingEscrowV2Upgradeable__factory,
} from '../../../typechain-types'
import { DeployManager } from '../DeployManager'
import { logger } from '../../../hardhat/utils'
import { DeployableNetworks, FixtureOverrides, getDeployConfig } from '../deploy.config'

/**
 *
 * @param _ethers
 * @param deployManager
 * @param overrides
 * @returns
 */
export async function deployVotingEscrowV2UpgradeableFixture(
  _ethers: typeof ethers,
  deployManager: DeployManager,
  overrides: FixtureOverrides = {}
) {
  const currentNetwork = network.name as DeployableNetworks
  const {
    accounts: { adminAddress },
    veDetails,
    contractOverrides,
  } = getDeployConfig(currentNetwork, overrides)

  let lockTokenAddress = contractOverrides.lockToken
  if (!lockTokenAddress) {
    logger.warn(`No lockToken provided in deploy.config, deploying ERC20Mock...`)
    const lockToken = await deployManager.deployContract<ERC20Mock__factory>('ERC20Mock', [
      '100000000000000000000000000000000000',
      18,
      'ERC20Mock',
      'MOCK',
    ])
    lockTokenAddress = lockToken.address
  }

  let votingEscrowV2Address = contractOverrides.votingEscrowV2
  let votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable
  let votingEscrowV2Implementation: string = 'not set'
  if (!votingEscrowV2Address) {
    logger.log(
      `deployEscrowDelegateLensFixture: votingEscrowV2Address not provided, deploying new VotingEscrowV2Upgradeable`,
      '🚀'
    )
    const EscrowDelegateCheckpoints = await _ethers.getContractFactory('EscrowDelegateCheckpoints')
    const escrowDelegateCheckpoints = await EscrowDelegateCheckpoints.deploy()

    const { implementationThroughProxy, implementation } =
      await deployManager.deployUpgradeableContract<VotingEscrowV2Upgradeable__factory>(
        'VotingEscrowV2Upgradeable',
        [veDetails.name, veDetails.symbol, veDetails.version, lockTokenAddress],
        { proxyAdminAddress: contractOverrides.proxyAdminAddress },
        { libraries: { EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address } }
      )
    logger.log(`Deployed VotingEscrowV2Upgradeable...`, '🚀')
    votingEscrowV2Upgradeable = implementationThroughProxy
    votingEscrowV2Implementation = implementation.address
  } else {
    votingEscrowV2Upgradeable = await ethers.getContractAt('VotingEscrowV2Upgradeable', votingEscrowV2Address)
  }

  return {
    addresses: {
      votingEscrowV2Upgradeable: votingEscrowV2Upgradeable.address,
      votingEscrowV2Implementation: votingEscrowV2Implementation,
    },
    contracts: {
      votingEscrowV2Upgradeable: votingEscrowV2Upgradeable,
    },
  }
}
