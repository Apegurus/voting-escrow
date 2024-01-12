import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'hardhat'

export async function deployVotingEscrowFixture(_ethers: typeof ethers) {
  const [owner, alice, bob, calvin] = await _ethers.getSigners()

  const ERC20Mock = await _ethers.getContractFactory('ERC20Mock')
  const mockToken = await ERC20Mock.deploy('100000000000000000000000000000000000', 18, 'ERC20Mock', 'MOCK')

  const EscrowDelegateCheckpoints = await _ethers.getContractFactory('EscrowDelegateCheckpoints')
  const escrowDelegateCheckpoints = await EscrowDelegateCheckpoints.deploy()

  const VotingEscrow = await _ethers.getContractFactory('VotingEscrow', {
    libraries: {
      EscrowDelegateCheckpoints: escrowDelegateCheckpoints.address,
    },
  })
  const votingEscrow = await VotingEscrow.deploy('VotingEscrow', 'veTOKEN', '1.0', mockToken.address)

  const VotingEscrowTestHelper = await _ethers.getContractFactory('VotingEscrowTestHelper')
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
