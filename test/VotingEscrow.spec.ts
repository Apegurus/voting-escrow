import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { dynamicFixture } from './fixtures'
import { deployVotingEscrowFicture } from './fixtures/deployVotingEscrow'

/**
 * Configurable fixture to use for each test file.
 *
 * As only one fixture can be used per test. This fixture intends to batch multiple contract
 * deployment functions into a single fixture.
 *
 * Fixtures improve test efficiency by reusing the same setup in every test.
 * loadFixture() runs this setup once, snapshots that state,
 * and resets the Hardhat Network to that snapshot for every test.
 */
async function fixture() {
  // Contracts are deployed using the first signer/account by default
  const accounts = await ethers.getSigners()
  const deployment = await deployVotingEscrowFicture(ethers)
  return { ...deployment, accounts }
}

describe('VotingEscrow', function () {
  it('Should be able to load fixture', async () => {
    const loadedFixture = await loadFixture(fixture)

    console.log(loadedFixture)

    expect(loadedFixture).to.not.be.undefined
  })

  describe('Lock Creation', function () {
    it('Should be able to create a new lock', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration, alice.address)

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      const ownerOf = await votingEscrow.ownerOf(0)
      const lockDetails = await votingEscrow.lockDetails(0)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
    })
  })
})
