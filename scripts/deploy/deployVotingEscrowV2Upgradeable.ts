import { ethers, network } from 'hardhat'
import { getDeployConfig, DeployableNetworks, DeploymentAccounts } from './deploy.config'
import { DeployManager } from './DeployManager'
import { logger } from '../../hardhat/utils'
import { ERC20Mock__factory, VotingEscrowV2Upgradeable__factory } from '../../typechain-types'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const currentNetwork = network.name as DeployableNetworks
  // Optionally pass in accounts to be able to use them in the deployConfig
  const accounts = await ethers.getSigners()
  let accountOverrides: Partial<DeploymentAccounts> = {}
  if (currentNetwork === 'hardhat') {
    accountOverrides = {
      adminAddress: accounts[1].address,
    }
  }
  const {
    wNative,
    accounts: { adminAddress },
    veDetails,
    contractOverrides,
  } = getDeployConfig(currentNetwork, {
    accountOverrides,
    contractOverrides: {},
  })

  // Optionally pass in signer to deploy contracts
  const deployManager = await DeployManager.create({ signer: accounts[0] })

  let lockTokenAddress = contractOverrides.lockToken
  if (!lockTokenAddress) {
    // NOTE: Deploying ERC20Mock
    logger.warn(`No lockToken provided in deploy.config, deploying ERC20Mock...`)
    const lockToken = await deployManager.deployContract<ERC20Mock__factory>('ERC20Mock', [
      '100000000000000000000000000000000000',
      18,
      'ERC20Mock',
      'MOCK',
    ])
    lockTokenAddress = lockToken.address
  }

  const EscrowDelegateCheckpoints = await ethers.getContractFactory('EscrowDelegateCheckpoints')
  const escrowDelegateCheckpoints = await EscrowDelegateCheckpoints.deploy()

  const { implementationThroughProxy: votingEscrowV2Upgradeable, implementation: votingEscrowV2Implementation } =
    await deployManager.deployUpgradeableContract<VotingEscrowV2Upgradeable__factory>(
      'VotingEscrowV2Upgradeable',
      [veDetails.name, veDetails.symbol, veDetails.version, lockTokenAddress],
      { proxyAdminAddress: contractOverrides.proxyAdminAddress },
      {
        libraries: {
          EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
        },
      }
    )
  logger.log(`Deployed VotingEscrowV2Upgradeable...`, '🚀')

  const output = {
    votingEscrowV2Upgradeable: votingEscrowV2Upgradeable.address,
    votingEscrowV2Implementation: (await votingEscrowV2Implementation).address,
  }
  console.dir(output, { depth: 3 })

  await deployManager.verifyContracts()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
