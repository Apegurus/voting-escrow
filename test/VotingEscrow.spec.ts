import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import chai, { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { dynamicFixture } from './fixtures'
import { deployVotingEscrowFicture } from './fixtures/deployVotingEscrow'
import { isWithinLimit } from './utils'
import { setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'

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

const MAX_TIME = 2 * 365 * 86400

describe('VotingEscrow', function () {
  it('Should be able to load fixture', async () => {
    const loadedFixture = await loadFixture(fixture)

    expect(loadedFixture).to.not.be.undefined
  })

  describe('Lock Creation', function () {
    it('Should be able to create a single lock', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)
      let latestTime = await time.latest()

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      const ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      let supplyAt = await votingEscrow.supplyAt(latestTime)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

      expect(supplyAt).to.equal(vote1)
    })

    it('Should be able to create a new lock', async function () {
      const { alice, bob, calvin, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      const ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      let supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address)
      supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      // await connectedEscrow.checkpoint()

      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address)
      supplyAt = await votingEscrow.supplyAt(await time.latest())
      console.log(supplyAt)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      let latestTime = await time.latest()
      const [bias1, bias2, bias3] = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(bias1, bias2, bias3)

      const [vote1, vote2, vote3] = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])

      console.log(vote1, vote2, vote3)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)
      latestTime = await time.latest()
      const [dVote1, dVote2, dVote3] = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])

      await connectedEscrow['delegate(uint256,address)'](1, calvin.address)
      await connectedEscrow['delegate(uint256,address)'](2, alice.address)

      console.log(dVote1, dVote2, dVote3)

      latestTime = await time.latest()
      const [ddVote1, ddVote2, ddVote3] = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])

      console.log(ddVote1, ddVote2, ddVote3)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)

      latestTime = await time.latest()
      const [dddVote1, dddVote2, dddVote3] = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])

      console.log(dddVote1, dddVote2, dddVote3)
      await connectedEscrow['delegate(uint256,address)'](1, alice.address)
      await connectedEscrow['delegate(uint256,address)'](2, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, calvin.address)

      latestTime = await time.latest()
      const [ddddVote1, ddddVote2, ddddVote3, Bbias1, Bbias2, Bbias3, lock1, lock2, lock3] = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
        connectedEscrow.balanceOfLockAt(1, latestTime),
        connectedEscrow.balanceOfLockAt(2, latestTime),
        connectedEscrow.balanceOfLockAt(3, latestTime),
      ])

      console.log(ddddVote1, ddddVote2, ddddVote3, Bbias1, Bbias2, Bbias3, lock1, lock2, lock3)
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(supplyAt)

      // We can increase the time in Hardhat Network
      await time.increaseTo(latestTime + duration / 2)
      latestTime = await time.latest()
      const [dddddVote1, dddddVote2, dddddVote3, Bbbias1, Bbibas2, Bbbias3, llock1, llock2, llock3] = await Promise.all(
        [
          connectedEscrow.getPastVotes(alice.address, latestTime),
          connectedEscrow.getPastVotes(bob.address, latestTime),
          connectedEscrow.getPastVotes(calvin.address, latestTime),
          connectedEscrow.balanceOfNFTAt(1, latestTime),
          connectedEscrow.balanceOfNFTAt(2, latestTime),
          connectedEscrow.balanceOfNFTAt(3, latestTime),
          connectedEscrow.balanceOfLockAt(1, latestTime),
          connectedEscrow.balanceOfLockAt(2, latestTime),
          connectedEscrow.balanceOfLockAt(3, latestTime),
        ]
      )

      console.log(dddddVote1, dddddVote2, dddddVote3, Bbbias1, Bbibas2, Bbbias3, llock1, llock2, llock3)
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(supplyAt)
    })
    it('Should have adecuate balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      let bias = []
      let vote = []

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)
      const lockDetails = await votingEscrow.lockDetails(1)
      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.supplyAt(await latestTime)
      vote[0] = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)
      expect(supplyAt).to.equal(vote[0])
      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.supplyAt(await latestTime)
      console.log('-- Supply after second lock --', supplyAt)
      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log('-- Supply after third lock --', supplyAt)

      const ownerOf = await votingEscrow.ownerOf(1)
      expect(ownerOf).to.equal(alice.address)
      expect(lockDetails.amount).to.equal(lockedAmount)

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      let sumVotes = vote[0].add(vote[1]).add(vote[2])

      expect(supplyAt).to.equal(sumVotes)
      await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      expect(supplyAt).to.equal(vote[0].add(vote[1]).add(vote[2]))

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      sumVotes = vote[0].add(vote[1]).add(vote[2])
      expect(supplyAt).to.equal(sumVotes)

      await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      sumVotes = vote[0].add(vote[1]).add(vote[2])
      expect(supplyAt).to.equal(sumVotes)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      sumVotes = vote[0].add(vote[1]).add(vote[2])
      // expect(supplyAt).to.equal(sumVotes)
      expect(isWithinLimit(supplyAt, sumVotes, 1)).to.be.true

      await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      sumVotes = vote[0].add(vote[1]).add(vote[2])
      // expect(supplyAt).to.equal(sumVotes)
      expect(isWithinLimit(supplyAt, sumVotes, 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]), 1)).to.be.true

      // await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]), 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]), 1)).to.be.true

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]), 1)).to.be.true
    })

    it('Should have adecuate delegated balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      let bias = []
      let vote = []

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)
      const lockDetails = await votingEscrow.lockDetails(1)
      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.supplyAt(await latestTime)
      vote[0] = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)
      expect(supplyAt).to.equal(vote[0])
      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.supplyAt(await latestTime)
      console.log('-- Supply after second lock --', supplyAt)
      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log('-- Supply after third lock --', supplyAt)

      const ownerOf = await votingEscrow.ownerOf(1)
      expect(ownerOf).to.equal(alice.address)
      expect(lockDetails.amount).to.equal(lockedAmount)

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)
      let sumVotes = vote[0].add(vote[1]).add(vote[2])
      expect(supplyAt).to.equal(sumVotes)
      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      sumVotes = vote[0].add(vote[1]).add(vote[2])
      console.log(
        `Voting power at after checkpoint ${latestTime} after delegation`,
        vote[0],
        vote[1],
        vote[2],
        sumVotes,
        supplyAt
      )
      // expect(supplyAt).to.equal(sumVotes)
      expect(isWithinLimit(supplyAt, sumVotes, 1)).to.be.true

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      sumVotes = vote[0].add(vote[1]).add(vote[2])

      console.log(
        `Voting power after checkpoint ${latestTime} after delegation`,
        vote[0],
        vote[1],
        vote[2],
        sumVotes,
        `-- Supply at  -- ${supplyAt}`
      )
      // expect(supplyAt).to.equal(sumVotes)
      expect(isWithinLimit(supplyAt, sumVotes, 1)).to.be.true

      await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      expect(supplyAt).to.equal(vote[0].add(vote[1]).add(vote[2]))

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      // await connectedEscrow.globalCheckpoint()
      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`Voting power at after checkpoint ${latestTime}`, vote[0], vote[1], vote[2])
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true

      await connectedEscrow['delegate(uint256,address)'](1, alice.address)

      latestTime = await time.latest()

      bias = await Promise.all([
        connectedEscrow.balanceOfNFTAt(1, latestTime),
        connectedEscrow.balanceOfNFTAt(2, latestTime),
        connectedEscrow.balanceOfNFTAt(3, latestTime),
      ])
      console.log(`Balance of NFT at ${latestTime}`, bias[0], bias[1], bias[2])

      vote = await Promise.all([
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(calvin.address, latestTime),
      ])
      console.log(`Voting power at ${latestTime}`, vote[0], vote[1], vote[2])

      supplyAt = await votingEscrow.supplyAt(latestTime)
      console.log(`-- Supply at  -- ${latestTime}`, supplyAt)
      expect(isWithinLimit(supplyAt, vote[0].add(vote[1]).add(vote[2]))).to.be.true
    })

    it('Should have adecuately calculate voting power for one lock over time', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)
      const lockDetails = await votingEscrow.lockDetails(1)

      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.supplyAt(latestTime)
      let vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)

      let slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      let power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      console.log(`-- Supply after first lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(power).to.equal(vote)
      expect(lockDetails.amount).to.equal(lockedAmount)

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after second lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 4 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
    })

    it('Should have adecuately calculate voting power after increasing ammount for one lock over time', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address)
      let lockDetails = await votingEscrow.lockDetails(1)

      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.supplyAt(latestTime)
      let vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)

      let slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      let power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      console.log(`-- Supply after first lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(power).to.equal(vote)
      expect(lockDetails.amount).to.equal(lockedAmount)

      await connectedEscrow.increaseAmount(1, lockedAmount)
      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()
      lockDetails = await votingEscrow.lockDetails(1)
      expect(lockDetails.amount).to.equal(lockedAmount * 2)

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      let balance = await connectedEscrow.balanceOfNFTAt(1, latestTime)
      console.log(
        `-- Supply after second lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} ---- Balance ${balance} --'`
      )
      // expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      // expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 3942000)
      await connectedEscrow.increaseAmount(1, lockedAmount)
      lockDetails = await votingEscrow.lockDetails(1)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 4 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(1e12).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(1e12)

      supplyAt = await votingEscrow.supplyAt(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
    })
  })
})
