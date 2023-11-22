import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'hardhat'

export async function deployVotingEscrowFicture(_ethers: typeof ethers) {
  const [owner, alice, bob, calvin] = await _ethers.getSigners()

  const ERC20Mock = await _ethers.getContractFactory('ERC20Mock')
  const mockToken = await ERC20Mock.deploy('1000000000000000000000000000000', 18, 'ERC20Mock', 'MOCK')

  const VotingEscrow = await _ethers.getContractFactory('VotingEscrow')
  const votingEscrow = await VotingEscrow.deploy('VotingEscrow', 'veTOKEN', '1.0', mockToken.address)

  await Promise.all([
    mockToken.approve(votingEscrow.address, '1000000000000000000000000000000'),
    mockToken.transfer(alice.address, '1000000000000000000000'),
    mockToken.transfer(bob.address, '1000000000000000000000'),
    mockToken.transfer(calvin.address, '1000000000000000000000'),
    mockToken.connect(alice).approve(votingEscrow.address, '1000000000000000000000000000000'),
    mockToken.connect(bob).approve(votingEscrow.address, '1000000000000000000000000000000'),
    mockToken.connect(calvin).approve(votingEscrow.address, '1000000000000000000000000000000'),
  ])

  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
  const ONE_GWEI = 1_000_000_000

  const duration = ONE_YEAR_IN_SECS
  const lockedAmount = ONE_GWEI
  const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

  return { mockToken, votingEscrow, unlockTime, lockedAmount, duration, owner, alice, bob, calvin }
}
