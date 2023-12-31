import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { deployVotingEscrowFicture } from './fixtures/deployVotingEscrow'
import { isWithinLimit } from './utils'
import { VotingEscrow } from '../typechain-types'
import { BigNumber } from 'ethers'

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
const PRECISION = 1

async function validateState(state: any, votingEscrow: VotingEscrow, testTime: number) {
  const votesAccounts = {} as any
  const biasPromises = []
  const votesPromises = []
  const locksPromises = []
  const detailsPromises = []
  for (const token of state) {
    biasPromises.push(votingEscrow.balanceOfNFTAt(token.tokenId, testTime))
    locksPromises.push(votingEscrow.balanceOfLockAt(token.tokenId, testTime))
    detailsPromises.push(votingEscrow.lockDetails(token.tokenId))
    if (!votesAccounts[token.account.address] && votesAccounts[token.account.address] !== 0) {
      votesPromises.push(votingEscrow.getPastVotes(token.account.address, testTime))
      votesAccounts[token.account.address] = votesPromises.length - 1
    }
  }
  const [votes, bias, locks, details, supplyAt] = await Promise.all([
    Promise.all(votesPromises),
    Promise.all(biasPromises),
    Promise.all(locksPromises),
    Promise.all(detailsPromises),
    votingEscrow.getPastTotalSupply(testTime),
  ])

  const sumVotes = votes.reduce((total, currVote) => {
    return total.add(currVote)
  })

  const sumBias = bias.reduce((total, currBias) => {
    return total.add(currBias)
  })

  const sumLocks = locks.reduce((total, currLock) => {
    return total.add(currLock)
  })

  for (let i = 0; i < state.length; i++) {
    console.log(bias, locks, details, votes)
    if (!details[i].isPermanent) {
      let slope = details[i].amount.mul(PRECISION).div(MAX_TIME)
      let power = slope.mul(details[i].endTime.sub(testTime)).div(PRECISION)
      expect(bias[i]).to.equal(power.lte(0) ? 0 : power)
    } else {
      expect(bias[i]).to.equal(details[i].amount)
      expect(locks[i]).to.equal(details[i].amount)
    }
    expect(locks[i]).to.equal(bias[i])
    state[i] = {
      ...state[i],
      bias: bias[i],
      lock: locks[i],
      details: details[i],
      votes: votes[votesAccounts[state[i].account.address]],
    }
  }

  expect(sumBias).to.equal(sumVotes)
  expect(sumLocks).to.equal(sumVotes)
  expect(supplyAt).to.equal(sumVotes)
  return state
}

async function finalStateCheck(state: any, historyState: any, votingEscrow: VotingEscrow) {
  const testTimes = Object.keys(historyState)

  for (const testTime of testTimes) {
    const currentState = historyState[testTime]
    const testState = await validateState(state, votingEscrow, parseInt(testTime))
    for (let i = 0; i < currentState.length; i++) {
      expect(currentState[i].bias).to.equal(testState[i].bias)
      expect(currentState[i].votes).to.equal(testState[i].votes)
      expect(currentState[i].lock).to.equal(testState[i].lock)
    }
  }
}

describe('VotingEscrow', function () {
  it('Should be able to load fixture', async () => {
    const loadedFixture = await loadFixture(fixture)

    expect(loadedFixture).to.not.be.undefined
  })

  describe('Lock Management', function () {
    it('Should be able to create a single lock', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)
      const supplyBefore = await connectedEscrow.supply()

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const latestTime = await time.latest()

      const balanceAfter = await connectedToken.balanceOf(alice.address)
      const supplyAfter = await connectedEscrow.supply()

      const ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

      expect(supplyAt).to.equal(vote1)
      expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))
    })

    describe('Permanent locking', function () {
      it('Should be able to create a single permanent lock', async function () {
        const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLockFor(lockedAmount, 0, alice.address, true)
        let latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)
        const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)
        const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])
        const state = [{ tokenId: 1, account: alice }]
        await validateState(state, votingEscrow, latestTime)

        expect(supplyAt).to.equal(vote1)
        expect(lockedAmount).to.equal(vote1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        await time.increaseTo(latestTime + duration)
        latestTime = await time.latest()
        const updatedState = await validateState(state, votingEscrow, latestTime)
        expect(updatedState[0].votes).to.equal(lockedAmount)
      })

      it('Should be able to create a single permanent lock and unlock', async function () {
        const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLockFor(lockedAmount, 0, alice.address, true)
        let latestTime = await time.latest()
        const state = [{ tokenId: 1, account: alice }]
        await validateState(state, votingEscrow, latestTime)

        await connectedEscrow.unlockPermanent(1)
        latestTime = await time.latest()
        await validateState(state, votingEscrow, latestTime)
      })

      it('Should be able to create a single lock and update to permanent', async function () {
        const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
        const state = [{ tokenId: 1, account: alice }]
        let latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)
        const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)
        const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

        expect(supplyAt).to.equal(vote1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        await time.increaseTo(latestTime + duration)
        latestTime = await time.latest()
        let updatedState = await validateState(state, votingEscrow, latestTime)

        await connectedEscrow.increaseUnlockTime(1, 0, true)
        latestTime = await time.latest()
        updatedState = await validateState(state, votingEscrow, latestTime)

        expect(updatedState[0].votes).to.equal(lockedAmount)
      })
    })

    it('Should be able to increase unlock time', async function () {
      const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
      let latestTime = await time.latest()
      const state = [{ tokenId: 1, account: alice }]
      await validateState(state, votingEscrow, latestTime)

      await connectedEscrow.increaseUnlockTime(1, duration * 2, false)
      latestTime = await time.latest()
      await validateState(state, votingEscrow, latestTime)
    })

    it('Should not be able to increase unlock time if unauthorized', async function () {
      const { alice, bob, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedEscrowBob = votingEscrow.connect(bob)

      await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
      await expect(connectedEscrowBob.increaseUnlockTime(1, duration * 2, false)).to.be.revertedWithCustomError(
        connectedEscrow,
        'ERC721InsufficientApproval'
      )
    })

    describe('Withdraw/Claim', function () {
      it('Should be able to claim after lock expires', async function () {
        const { alice, votingEscrow, mockToken, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, oneDay, alice.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + oneDay)

        const vestedPayout = await connectedEscrow.vestedPayout(1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        expect(vestedPayout).to.equal(lockedAmount)

        await connectedEscrow.withdraw(1)

        const finalBalance = await connectedToken.balanceOf(alice.address)
        const finalSupply = await connectedEscrow.supply()

        expect(finalBalance).to.equal(balanceBefore)
        expect(finalSupply).to.equal(supplyBefore)
      })

      it('Should not be able to claim before lock expires', async function () {
        const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + oneDay)

        const vestedPayout = await connectedEscrow.vestedPayout(1)

        expect(vestedPayout).to.equal(0)

        await expect(connectedEscrow.withdraw(1)).to.be.revertedWith('ERC5725: No pending payout')
      })

      it('Should be able to claim on behalf of other user that approved', async function () {
        const { alice, bob, votingEscrow, mockToken, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedEscrowBob = votingEscrow.connect(bob)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, oneDay, bob.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(bob.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + oneDay)

        await connectedEscrowBob.setApprovalForAll(alice.address, true)

        const vestedPayout = await connectedEscrow.vestedPayout(1)

        expect(vestedPayout).to.equal(lockedAmount)

        await connectedEscrow.withdraw(1)

        const finalBalance = await mockToken.balanceOf(alice.address)

        expect(finalBalance).to.equal(balanceBefore)
      })

      it('Should not be able to claim on behalf of other user', async function () {
        const { alice, bob, votingEscrow, mockToken, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, oneDay, bob.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(bob.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + oneDay)

        const vestedPayout = await connectedEscrow.vestedPayout(1)

        expect(vestedPayout).to.equal(lockedAmount)

        await expect(connectedEscrow.withdraw(1)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })
    })

    describe('Split', function () {
      it('Should be able to split an unexpired lock in two', async function () {
        const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, latestTime)
        await time.increaseTo(latestTime + oneDay)

        await connectedEscrow.split([50, 50], 1)
        latestTime = await time.latest()

        const [token1, token2] = await Promise.all([
          votingEscrow.tokenOfOwnerByIndex(alice.address, 0),
          votingEscrow.tokenOfOwnerByIndex(alice.address, 1),
        ])
        const [lock1, lock2] = await Promise.all([votingEscrow.lockDetails(token1), votingEscrow.lockDetails(token2)])

        expect(lock1.amount).to.equal(lockedAmount / 2)
        expect(lock1.amount).to.equal(lock2.amount)

        await expect(votingEscrow.ownerOf(1)).to.be.revertedWithCustomError(connectedEscrow, 'ERC721NonexistentToken')
        await validateState(
          [
            { tokenId: token1, account: alice },
            { tokenId: token2, account: alice },
          ],
          votingEscrow,
          latestTime
        )
      })

      it('Should not be able to split an unauthorized veNFT', async function () {
        const { alice, bob, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedEscrowBob = votingEscrow.connect(bob)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, latestTime)
        await time.increaseTo(latestTime + oneDay)

        await expect(connectedEscrowBob.split([50, 50], 1)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })

      it('Should be able to split an unexpired lock in many uneven parts', async function () {
        const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, latestTime)
        await time.increaseTo(latestTime + oneDay)

        const splitAmounts = [50, 20, 10, 5, 15]

        await connectedEscrow.split(splitAmounts, 1)
        latestTime = await time.latest()

        const tokens = await Promise.all(
          splitAmounts.map((val, index) => votingEscrow.tokenOfOwnerByIndex(alice.address, index))
        )
        const locks = await Promise.all(tokens.map((val) => votingEscrow.lockDetails(val)))

        console.log(tokens, locks)
        let sumAmounts = BigNumber.from(0)
        const state = [] as any
        splitAmounts.forEach((amount, index) => {
          expect(locks[index].amount).to.equal((lockedAmount * amount) / 100)
          sumAmounts = sumAmounts.add(locks[index].amount)
          state.push({
            tokenId: tokens[index],
            account: alice,
          })
        })

        expect(sumAmounts).to.equal(lockedAmount)
        const updatedState = await validateState(state, votingEscrow, latestTime)
        console.log(updatedState)
      })
    })

    describe('Merge', function () {
      it('Should be able to merge two unexpired locks', async function () {
        const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState(
          [
            { tokenId: 1, account: alice },
            { tokenId: 2, account: alice },
          ],
          votingEscrow,
          latestTime
        )
        await time.increaseTo(latestTime + oneDay)

        await connectedEscrow.merge(1, 2)
        latestTime = await time.latest()

        const updatedState = await validateState([{ tokenId: 2, account: alice }], votingEscrow, latestTime)

        expect(updatedState[0].details.amount).to.equal(lockedAmount * 2)
      })

      it('Should not be able to merge an unauthorized veNFT', async function () {
        const { alice, bob, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedEscrowBob = votingEscrow.connect(bob)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState(
          [
            { tokenId: 1, account: alice },
            { tokenId: 2, account: alice },
          ],
          votingEscrow,
          latestTime
        )
        await time.increaseTo(latestTime + oneDay)

        await expect(connectedEscrowBob.merge(1, 2)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })
    })
  })

  describe('General Checkpoint tests', function () {
    it('Should be able to create a single lock', async function () {
      const { alice, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const latestTime = await time.latest()

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      const ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

      expect(supplyAt).to.equal(vote1)
    })

    it('Should be able to create and delegate locks', async function () {
      const { alice, bob, calvin, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)
      const state = []
      const stateHistory = {} as any

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      state.push({ account: alice, tokenId: 1 })

      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address, false)
      state.push({ account: bob, tokenId: 2 })

      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address, false)
      state.push({ account: calvin, tokenId: 3 })

      let latestTime = await time.latest()

      await validateState(state, votingEscrow, latestTime)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)
      latestTime = await time.latest()

      let updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      await connectedEscrow.globalCheckpoint()
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, calvin.address)
      await connectedEscrow['delegate(uint256,address)'](2, alice.address)

      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[2].votes)
      expect(updatedState[1].bias.add(updatedState[2].bias)).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)

      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[1].votes)
      expect(updatedState[1].bias.add(updatedState[2].bias)).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, alice.address)
      await connectedEscrow['delegate(uint256,address)'](2, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, calvin.address)

      latestTime = await time.latest()
      await validateState(state, votingEscrow, latestTime)
      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)

      await time.increaseTo(latestTime + duration / 2)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)

      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)
      await finalStateCheck(state, stateHistory, votingEscrow)

      await time.increaseTo(latestTime + duration)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)
      await finalStateCheck(state, stateHistory, votingEscrow)
    })

    it('Should have adecuate balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)
      const state = []
      const stateHistory = {} as any

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const lockDetails = await votingEscrow.lockDetails(1)
      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.getPastTotalSupply(await latestTime)
      const vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)
      expect(supplyAt).to.equal(vote)

      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address, false)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.getPastTotalSupply(await latestTime)
      console.log('-- Supply after second lock --', supplyAt)

      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address, false)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      console.log('-- Supply after third lock --', supplyAt)

      state.push({ account: alice, tokenId: 1 })
      state.push({ account: bob, tokenId: 2 })
      state.push({ account: calvin, tokenId: 3 })

      const ownerOf = await votingEscrow.ownerOf(1)
      expect(ownerOf).to.equal(alice.address)
      expect(lockDetails.amount).to.equal(lockedAmount)

      let updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      await finalStateCheck(state, stateHistory, votingEscrow)
    })

    it('Should have adecuate delegated balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)
      const state = []
      const stateHistory = {} as any

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const lockDetails = await votingEscrow.lockDetails(1)
      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.getPastTotalSupply(await latestTime)
      const vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)
      expect(supplyAt).to.equal(vote)
      await connectedEscrow.createLockFor(lockedAmount, duration, bob.address, false)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.getPastTotalSupply(await latestTime)
      console.log('-- Supply after second lock --', supplyAt)
      await connectedEscrow.createLockFor(lockedAmount, duration / 2, calvin.address, false)
      latestTime = await time.latest()
      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      console.log('-- Supply after third lock --', supplyAt)

      state.push({ account: alice, tokenId: 1 })
      state.push({ account: bob, tokenId: 2 })
      state.push({ account: calvin, tokenId: 3 })

      const ownerOf = await votingEscrow.ownerOf(1)
      expect(ownerOf).to.equal(alice.address)
      expect(lockDetails.amount).to.equal(lockedAmount)

      let updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow['delegate(uint256,address)'](1, alice.address)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[0].votes)

      await finalStateCheck(state, stateHistory, votingEscrow)
    })

    it('Should have adecuately calculate voting power for one lock over time', async function () {
      // TODO: Revisit validate state (as it checks things twot times)
      const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const state = [{ tokenId: 1, account: alice }]
      const lockDetails = await votingEscrow.lockDetails(1)

      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      let vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)

      let slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      let power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      console.log(`-- Supply after first lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(power).to.equal(vote)
      expect(lockDetails.amount).to.equal(lockedAmount)

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after second lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 4 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)
    })

    it('Should have adecuately calculate voting power after increasing ammount for one lock over time', async function () {
      // TODO: Revisit validate state (as it checks things twot times)
      const { alice, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      const state = [{ tokenId: 1, account: alice }]
      let lockDetails = await votingEscrow.lockDetails(1)

      let latestTime = await time.latest()
      let supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      let vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log('-- Supply after first lock --', supplyAt)

      let slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      let power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      console.log(`-- Supply after first lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(power).to.equal(vote)
      expect(lockDetails.amount).to.equal(lockedAmount)

      await connectedEscrow.increaseAmount(1, lockedAmount)
      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()
      lockDetails = await votingEscrow.lockDetails(1)
      expect(lockDetails.amount).to.equal(lockedAmount * 2)

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      let balance = await connectedEscrow.balanceOfNFTAt(1, latestTime)
      console.log(
        `-- Supply after second lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} ---- Balance ${balance} --'`
      )

      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 3942000)
      await connectedEscrow.increaseAmount(1, lockedAmount)
      lockDetails = await votingEscrow.lockDetails(1)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 4 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, latestTime)
    })
  })

  describe('veNFT transfers', function () {
    it('Should be able to create and transfer single lock', async function () {
      const { alice, bob, votingEscrow, mockToken, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)
      const connectedToken = mockToken.connect(alice)

      const balanceBefore = await connectedToken.balanceOf(alice.address)

      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      let latestTime = await time.latest()

      const balanceAfter = await connectedToken.balanceOf(alice.address)

      let ownerOf = await votingEscrow.ownerOf(1)
      const lockDetails = await votingEscrow.lockDetails(1)
      const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

      expect(ownerOf).to.equal(alice.address)

      expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

      expect(lockDetails.amount).to.equal(lockedAmount)
      const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

      expect(supplyAt).to.equal(vote1)

      await connectedEscrow.transferFrom(alice.address, bob.address, 1)
      latestTime = await time.latest()

      const [vote2, voteAlice, bias2] = await Promise.all([
        connectedEscrow.getPastVotes(bob.address, latestTime),
        connectedEscrow.getPastVotes(alice.address, latestTime),
        connectedEscrow.balanceOfNFTAt(1, latestTime),
      ])

      ownerOf = await votingEscrow.ownerOf(1)
      expect(ownerOf).to.equal(bob.address)
      expect(vote2).to.equal(bias2)
      expect(voteAlice).to.equal(0)
    })
  })
})
