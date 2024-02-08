import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'hardhat'
import {
  VotingEscrow,
  VotingEscrowTestHelper__factory,
  VotingEscrowV2Upgradeable,
  VotingEscrowV2Upgradeable__factory,
  VotingEscrow__factory,
} from '../../typechain-types'
import { logger } from '../../hardhat/utils'

export async function deployVotingEscrowFixture(_ethers: typeof ethers, upgradeable = false) {
  const [owner, alice, bob, calvin, proxyAdminEoa] = await _ethers.getSigners()

  const ERC20Mock = await _ethers.getContractFactory('ERC20Mock')
  const mockToken = await ERC20Mock.deploy('100000000000000000000000000000000000', 18, 'ERC20Mock', 'MOCK')

  const EscrowDelegateCheckpoints = await _ethers.getContractFactory('EscrowDelegateCheckpoints')
  const escrowDelegateCheckpoints = await EscrowDelegateCheckpoints.deploy()

  let votingEscrow: VotingEscrow
  // let votingEscrow: VotingEscrow | VotingEscrowV2Upgradeable
  if (!upgradeable) {
    logger.log('Deploying VotingEscrowV2', '🚀')
    const VotingEscrow = (await _ethers.getContractFactory('VotingEscrow', {
      libraries: {
        EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
      },
    })) as VotingEscrow__factory
    votingEscrow = await VotingEscrow.deploy('VotingEscrow', 'veTOKEN', '1.0', mockToken.address)
  } else {
    logger.log('Deploying VotingEscrowV2Upgradeable', '🚀')
    const VotingEscrowV2Upgradeable = (await _ethers.getContractFactory('VotingEscrowV2Upgradeable', {
      libraries: {
        EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
      },
    })) as VotingEscrowV2Upgradeable__factory
    const votingEscrowV2Upgradeable_Implementation = await VotingEscrowV2Upgradeable.deploy()

    const initializerParams = ['Vote Escrow Lynx', 'veLYNX', '1', mockToken.address]
    const initializerData = VotingEscrowV2Upgradeable.interface.encodeFunctionData('initialize', initializerParams)

    const TransparentUpgradeableProxyFactory = await _ethers.getContractFactory('TransparentUpgradeableProxy')
    const transparentProxy = await TransparentUpgradeableProxyFactory.deploy(
      votingEscrowV2Upgradeable_Implementation.address,
      proxyAdminEoa.address,
      initializerData
    )
    votingEscrow = (await _ethers.getContractAt(
      'VotingEscrowV2Upgradeable',
      transparentProxy.address
    )) as unknown as VotingEscrow
  }

  const VotingEscrowTestHelper = (await _ethers.getContractFactory(
    'VotingEscrowTestHelper'
  )) as VotingEscrowTestHelper__factory
  const votingEscrowTestHelper = await VotingEscrowTestHelper.deploy(votingEscrow.address)

  await mockToken.approve(votingEscrow.address, '100000000000000000000000000000000000')
  await mockToken.transfer(alice.address, '1000000000000000000000')
  await mockToken.transfer(bob.address, '1000000000000000000000')
  await mockToken.transfer(calvin.address, '1000000000000000000000')
  await mockToken.transfer(votingEscrowTestHelper.address, '100000000000000000000000000000')
  await mockToken.connect(alice).approve(votingEscrow.address, '100000000000000000000000000000000000')
  await mockToken.connect(bob).approve(votingEscrow.address, '100000000000000000000000000000000000')
  await mockToken.connect(calvin).approve(votingEscrow.address, '100000000000000000000000000000000000')

  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
  const ONE_GWEI = 1_000_000_000

  const duration = ONE_YEAR_IN_SECS
  const lockedAmount = ONE_GWEI
  const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

  const maxTime = await escrowDelegateCheckpoints.MAX_TIME()
  const clockUnit = await escrowDelegateCheckpoints.CLOCK_UNIT()

  return {
    mockToken,
    votingEscrow,
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
