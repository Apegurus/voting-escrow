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

    expect(loadedFixture).to.not.be.undefined
  })

  describe('Lock Creation', function () {
    it('Should be able to create a new lock', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)

      // await connectedEscrow.createLockFor('100', duration * 2, alice.address)

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      const ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      let supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      await connectedEscrow.createLockFor(lockedAmount, duration, alice.address)
      supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      await connectedEscrow.checkpoint()

      await connectedEscrow.createLockFor(lockedAmount, duration / 2, alice.address)
      supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      expect(ownerOf).to.equal(alice.address)

      // expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      let latestTime = await time.latest()
      const [bias1, bias2, bias3] = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(bias1, bias2, bias3)

      const [vote1, vote2, vote3] = await Promise.all([
        connectedEscrow.getPastVotes(1, latestTime),
        connectedEscrow.getPastVotes(2, latestTime),
        connectedEscrow.getPastVotes(3, latestTime),
      ])

      console.log(vote1, vote2, vote3)

      await connectedEscrow.delegate(1, 2)
      await connectedEscrow.delegate(3, 1)
      latestTime = await time.latest()
      const [dVote1, dVote2, dVote3] = await Promise.all([
        connectedEscrow.getPastVotes(1, latestTime),
        connectedEscrow.getPastVotes(2, latestTime),
        connectedEscrow.getPastVotes(3, latestTime),
      ])

      await connectedEscrow.delegate(2, 3)

      console.log(dVote1, dVote2, dVote3)

      latestTime = await time.latest()
      const [ddVote1, ddVote2, ddVote3] = await Promise.all([
        connectedEscrow.getPastVotes(1, latestTime),
        connectedEscrow.getPastVotes(2, latestTime),
        connectedEscrow.getPastVotes(3, latestTime),
      ])

      console.log(ddVote1, ddVote2, ddVote3)

      await connectedEscrow.delegate(2, 2)

      latestTime = await time.latest()
      const [dddVote1, dddVote2, dddVote3] = await Promise.all([
        connectedEscrow.getPastVotes(1, latestTime),
        connectedEscrow.getPastVotes(2, latestTime),
        connectedEscrow.getPastVotes(3, latestTime),
      ])

      console.log(dddVote1, dddVote2, dddVote3)
      await connectedEscrow.delegate(1, 1)
      await connectedEscrow.delegate(3, 3)

      latestTime = await time.latest()
      const [ddddVote1, ddddVote2, ddddVote3, Bbias1, Bbias2, Bbias3] = await Promise.all([
        connectedEscrow.getPastVotes(1, latestTime),
        connectedEscrow.getPastVotes(2, latestTime),
        connectedEscrow.getPastVotes(3, latestTime),
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])

      console.log(ddddVote1, ddddVote2, ddddVote3, Bbias1, Bbias2, Bbias3)
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(supplyAt)
    })
  })
})
