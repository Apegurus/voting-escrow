import hre, { ethers, network } from 'hardhat'
import { getDeployConfig, DeployableNetworks } from './deploy.config'
import { DeployManager } from './DeployManager'
import { convertAddressesToExplorerLinksByNetwork, logger } from '../../hardhat/utils'
import { deployVotingEscrowV2UpgradeableFixture } from './fixtures/deployVotingEscrowV2UpgradeableFixture'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const currentNetwork = network.name as DeployableNetworks
  // Optionally pass in accounts to be able to use them in the deployConfig
  const accounts = await ethers.getSigners()

  // Optionally pass in signer to deploy contracts
  const deployManager = await DeployManager.create({ signer: accounts[0] })

  const { addressOutput } = await deployVotingEscrowV2UpgradeableFixture(hre, deployManager)

  const output = convertAddressesToExplorerLinksByNetwork(
    {
      votingEscrowV2Upgradeable: addressOutput.votingEscrowV2Upgradeable,
      votingEscrowV2Implementation: addressOutput.votingEscrowV2Upgradeable,
      lockToken: addressOutput.lockToken,
    },
    currentNetwork,
    true
  )
  console.dir(output, { depth: 3 })

  await deployManager.verifyContracts()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
