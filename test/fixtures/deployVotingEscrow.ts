import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'hardhat'
import { VotingEscrowTestHelper__factory, VotingEscrowV2Upgradeable__factory } from '../../typechain-types'
import { logger } from '../../hardhat/utils'

export async function deployVotingEscrowFixture(_ethers: typeof ethers) {
  const [owner, alice, bob, calvin, proxyAdminEoa] = await _ethers.getSigners()

  const ERC20Mock = await _ethers.getContractFactory('ERC20Mock')
  const mockToken = await ERC20Mock.deploy('100000000000000000000000000000000000', 18, 'ERC20Mock', 'MOCK')

  const EscrowDelegateCheckpoints = await _ethers.getContractFactory('EscrowDelegateCheckpoints')
  const escrowDelegateCheckpoints = await EscrowDelegateCheckpoints.deploy()
  // TransparentUpgradeableProxy Factory
  const TransparentUpgradeableProxyFactory = await _ethers.getContractFactory('TransparentUpgradeableProxy')

  logger.log('Deploying VeArtProxyUpgradeable', '🚀')
  const VeArtProxyUpgradeable = await _ethers.getContractFactory('VeArtProxyUpgradeable')
  const veArtProxyUpgradeable_Implementation = await VeArtProxyUpgradeable.deploy()
  const artTransparentProxy = await TransparentUpgradeableProxyFactory.deploy(
    veArtProxyUpgradeable_Implementation.address,
    proxyAdminEoa.address,
    '0x'
  )
  const veArtProxyUpgradeable = await _ethers.getContractAt('VeArtProxyUpgradeable', artTransparentProxy.address)

  logger.log('Deploying VotingEscrowV2Upgradeable', '🚀')
  const VotingEscrowV2Upgradeable = (await _ethers.getContractFactory('VotingEscrowV2Upgradeable', {
    libraries: {
      EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
    },
  })) as VotingEscrowV2Upgradeable__factory
  const votingEscrowV2Upgradeable_Implementation = await VotingEscrowV2Upgradeable.deploy()

  const initializerParams = ['Vote Escrow Lynx', 'veLYNX', '1', mockToken.address, veArtProxyUpgradeable.address]
  const initializerData = VotingEscrowV2Upgradeable.interface.encodeFunctionData('initialize', initializerParams)

  const transparentProxy = await TransparentUpgradeableProxyFactory.deploy(
    votingEscrowV2Upgradeable_Implementation.address,
    proxyAdminEoa.address,
    initializerData
  )
  const votingEscrowV2Upgradeable = await _ethers.getContractAt('VotingEscrowV2Upgradeable', transparentProxy.address)

  const VotingEscrowTestHelper = (await _ethers.getContractFactory(
    'VotingEscrowTestHelper'
  )) as VotingEscrowTestHelper__factory
  const votingEscrowTestHelper = await VotingEscrowTestHelper.deploy(votingEscrowV2Upgradeable.address)

  await mockToken.approve(votingEscrowV2Upgradeable.address, '100000000000000000000000000000000000')
  await mockToken.transfer(alice.address, '1000000000000000000000')
  await mockToken.transfer(bob.address, '1000000000000000000000')
  await mockToken.transfer(calvin.address, '1000000000000000000000')
  await mockToken.transfer(votingEscrowTestHelper.address, '100000000000000000000000000000')
  await mockToken.connect(alice).approve(votingEscrowV2Upgradeable.address, '100000000000000000000000000000000000')
  await mockToken.connect(bob).approve(votingEscrowV2Upgradeable.address, '100000000000000000000000000000000000')
  await mockToken.connect(calvin).approve(votingEscrowV2Upgradeable.address, '100000000000000000000000000000000000')

  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
  const ONE_GWEI = 1_000_000_000

  const duration = ONE_YEAR_IN_SECS
  const lockedAmount = ONE_GWEI
  const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

  const maxTime = await escrowDelegateCheckpoints.MAX_TIME()
  const clockUnit = await escrowDelegateCheckpoints.CLOCK_UNIT()

  return {
    mockToken,
    votingEscrow: votingEscrowV2Upgradeable, // backward compatibility
    votingEscrowV2Upgradeable,
    veArtProxyUpgradeable,
    votingEscrowTestHelper,
    unlockTime,
    lockedAmount,
    maxTime,
    clockUnit,
    duration,
    owner,
    alice,
    bob,
    calvin,
  }
}
