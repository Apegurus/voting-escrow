import { ethers } from 'hardhat'
import { time } from '@nomicfoundation/hardhat-network-helpers'

export async function deployOneYearLockFixture(_ethers: typeof ethers) {
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
  const ONE_GWEI = 1_000_000_000

  const lockedAmount = ONE_GWEI
  const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

  // Contracts are deployed using the first signer/account by default
  const [owner, otherAccount] = await _ethers.getSigners()

  const Lock = await _ethers.getContractFactory('Lock')
  const lock = await Lock.deploy(unlockTime, owner.address, { value: lockedAmount })

  return { lock, unlockTime, lockedAmount, owner, otherAccount }
}
