import { ethers, network } from 'hardhat'
import { getDeployConfig, DeployableNetworks } from './deploy.config'
import { DeployManager } from './DeployManager'
import { logger } from '../../hardhat/utils'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const currentNetwork = network.name as DeployableNetworks
  // Optionally pass in accounts to be able to use them in the deployConfig
  const accounts = await ethers.getSigners()
  // NOTE: For importing deployment params by network
  // const { wNative, adminAddress } = getDeployConfig(currentNetwork, accounts)

  // Optionally pass in signer to deploy contracts
  const deployManager = await DeployManager.create(accounts[0])

  const currentTimestampInSeconds = Math.round(Date.now() / 1000)
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
  const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS

  const lockedAmount = ethers.utils.parseEther('.00001')

  const lockContractName = 'Lock'
  const Lock = await ethers.getContractFactory(lockContractName)
  const lock = await deployManager.deployContractFromFactory(
    Lock,
    [unlockTime, accounts[0].address, { value: lockedAmount }],
    {
      name: lockContractName, // Pass in contract name to log contract
    }
  )
  logger.log(`Lock with 1 ETH deployed to: ${lock.address}`, '🔒')

  const lockUpgradableContractName = 'LockUpgradeable'
  const LockUpgradable = await ethers.getContractFactory(lockUpgradableContractName)
  // TODO: This isn't passing value to the constructor due to how upgradeable contracts work
  const lockUpgradable = await deployManager.deployUpgradeableContract(
    LockUpgradable,
    [unlockTime, accounts[0].address],
    {
      name: lockUpgradableContractName, // Pass in contract name to log contract
    }
  )
  logger.log(`LockUpgradeable to: ${lock.address}`, '🔒')

  await deployManager.verifyContracts()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
