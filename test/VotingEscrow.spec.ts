import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { time, loadFixture, mine } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { deployVotingEscrowFixture } from './fixtures/deployVotingEscrow'
import { isWithinLimit } from './utils'
import { VotingEscrow, VotingEscrowTestHelper } from '../typechain-types'
import { BigNumber } from 'ethers'
import { chunk } from 'lodash'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { token } from '../typechain-types/@openzeppelin/contracts'

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
  const deployment = await deployVotingEscrowFixture(ethers)
  return { ...deployment, accounts }
}

const MAX_TIME = 2 * 365 * 86400
const PRECISION = 1

async function validateState(
  state: any,
  votingEscrow: VotingEscrow,
  votingEscrowTestHelper: VotingEscrowTestHelper,
  testTime: number
) {
  console.time('validatestate')
  const votesAccounts = {} as any
  const biasPromises = []
  const votesPromises = []
  const locksPromises = []
  const detailsPromises = []
  const delegatesPromises = []
  for (const token of state) {
    biasPromises.push(votingEscrow.balanceOfNFTAt(token.tokenId, testTime))
    locksPromises.push(votingEscrowTestHelper.balanceOfLockAt(token.tokenId, testTime))
    detailsPromises.push(votingEscrow.lockDetails(token.tokenId))
    delegatesPromises.push(votingEscrow['delegates(uint256,uint48)'](token.tokenId, testTime))
    if (!votesAccounts[token.account.address] && votesAccounts[token.account.address] !== 0) {
      votesPromises.push(votingEscrow.getPastVotes(token.account.address, testTime))
      votesAccounts[token.account.address] = votesPromises.length - 1
    }
  }
  const [votes, bias, locks, details, delegates, supplyAt] = await Promise.all([
    Promise.all(votesPromises),
    Promise.all(biasPromises),
    Promise.all(locksPromises),
    Promise.all(detailsPromises),
    Promise.all(delegatesPromises),
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
    // console.log(bias, locks, details, votes)
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
      testTime,
      bias: bias[i],
      lock: locks[i],
      details: details[i],
      delegates: delegates[i],
      votes: votes[votesAccounts[state[i].account.address]],
    }
  }
  expect(sumBias).to.equal(sumVotes)
  expect(sumLocks).to.equal(sumVotes)
  expect(supplyAt).to.equal(sumVotes)
  console.timeEnd('validatestate')
  return state
}

async function finalStateCheck(
  state: any,
  historyState: any,
  votingEscrow: VotingEscrow,
  votingEscrowTestHelper: VotingEscrowTestHelper
) {
  const testTimes = Object.keys(historyState)

  for (const testTime of testTimes) {
    const currentState = historyState[testTime]
    const testState = await validateState(state, votingEscrow, votingEscrowTestHelper, parseInt(testTime))
    for (let i = 0; i < currentState.length; i++) {
      expect(currentState[i].bias).to.equal(testState[i].bias)
      expect(currentState[i].votes).to.equal(testState[i].votes)
      expect(currentState[i].lock).to.equal(testState[i].lock)
    }
  }
}

async function createManyLocks(
  accounts: SignerWithAddress[],
  increment: number,
  votingEscrowTestHelper: VotingEscrowTestHelper,
  lockedAmount: number,
  latestTokenId: number,
  state: any
) {
  const chunkSize = 25
  const chunkedAccounts = chunk(accounts, chunkSize)
  let chunkNumber = 0
  for (const thisAccounts of chunkedAccounts) {
    let params = {
      amount: [],
      duration: [],
      to: [],
      isPermanent: [],
    } as any
    thisAccounts.map((account: SignerWithAddress, index: number) => {
      const duration = increment * (chunkNumber + index + 1)
      if (duration > MAX_TIME) return
      const tokenId = latestTokenId + 1
      state.push({ tokenId, account: account })
      params.amount.push(lockedAmount)
      params.duration.push(duration)
      params.to.push(account.address)
      params.isPermanent.push(false)
      latestTokenId = tokenId
    })
    if (params.amount.length !== 0) {
      console.time(`createLock-${chunkNumber}`)
      console.log(
        `creating ${params.amount.length} locks from ${latestTokenId - params.amount.length} to ${latestTokenId}`
      )
      await votingEscrowTestHelper.createManyLocks(params.amount, params.duration, params.to, params.isPermanent)
      console.timeEnd(`createLock-${chunkNumber}`)
      chunkNumber += params.amount.length
    }
  }
  await mine(1)
  return { state, latestTokenId }
}

describe('VotingEscrow', function () {
  it('Should be able to load fixture', async () => {
    const loadedFixture = await loadFixture(fixture)

    expect(loadedFixture).to.not.be.undefined
  })

  describe('Lock Management', function () {
    describe('Create veNFT', function () {
      it('Should be able to create a single lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLock(lockedAmount, duration * 2, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)
        const supplyAt = await votingEscrow.getPastTotalSupply(latestTime)

        expect(ownerOf).to.equal(alice.address)

        expect(lockDetails.amount).to.equal(lockedAmount)
        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        const [vote1] = await Promise.all([connectedEscrow.getPastVotes(alice.address, latestTime)])

        expect(supplyAt).to.equal(vote1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))
      })

      it('Should revert for value 0 lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await expect(connectedEscrow.createLock(0, duration * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ZeroAmount'
        )
      })

      it('Should revert for duration 0 lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await expect(connectedEscrow.createLock(lockedAmount, 0 * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockDurationNotInFuture'
        )
      })

      it('Should revert for duration above max lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await expect(connectedEscrow.createLock(lockedAmount, MAX_TIME * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockDurationTooLong'
        )
      })
    })

    describe('Update veNFT', function () {
      it('Should revert when increasing amount by 0', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLock(lockedAmount, duration * 2, false)
        await expect(connectedEscrow.increaseAmount(1, 0)).to.be.revertedWithCustomError(connectedEscrow, 'ZeroAmount')
      })

      it('Should revert when increasing amount of unexisting tokenId', async function () {
        const { alice, votingEscrow } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await expect(connectedEscrow.increaseAmount(123, 1000000000000)).to.be.revertedWithCustomError(
          connectedEscrow,
          'NoLockFound'
        )
      })

      it('Should revert when increasing amount of expired lock tokenId', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, lockedAmount, duration } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        await connectedEscrow.createLock(lockedAmount, duration, false)

        let latestTime = await time.latest()
        await time.increaseTo(latestTime + duration)
        await expect(connectedEscrow.increaseAmount(1, 1000000000000)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockExpired'
        )
      })

      it('Should be able to increase veNFT locked amount', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        await connectedEscrow.createLock(lockedAmount, duration * 2, false)
        let latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        let lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await connectedEscrow.increaseAmount(1, lockedAmount)
        lockDetails = await votingEscrow.lockDetails(1)
        expect(lockDetails.amount).to.equal(lockedAmount * 2)
        latestTime = await time.latest()
        await validateState([{ tokenId: 1, account: alice }], votingEscrow, votingEscrowTestHelper, latestTime)
      })

      it('Should be able to increase unlock time', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()
        const state = [{ tokenId: 1, account: alice }]
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        await connectedEscrow.increaseUnlockTime(1, duration * 2, false)
        latestTime = await time.latest()
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
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

      it('Should revert when increasing lock time of unnexisting lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await expect(connectedEscrow.increaseUnlockTime(123, duration * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721NonexistentToken'
        )
      })

      it('Should revert when increasing locktime of expired veNFT', async function () {
        const { alice, bob, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)

        let latestTime = await time.latest()
        await time.increaseTo(latestTime + duration)
        await expect(connectedEscrow.increaseUnlockTime(1, duration * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockExpired'
        )
      })

      it('Should revert when increased lock-time is lower than current one', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)

        await expect(connectedEscrow.increaseUnlockTime(1, 10000, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockDurationNotInFuture'
        )
      })

      it('Should revert when increased lock-time is higher than max', async function () {
        const { alice, bob, votingEscrow, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)

        await expect(connectedEscrow.increaseUnlockTime(1, MAX_TIME * 2, false)).to.be.revertedWithCustomError(
          connectedEscrow,
          'LockDurationTooLong'
        )
      })
    })

    describe('Permanent locking', function () {
      it('Should be able to create a single permanent lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

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
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        expect(supplyAt).to.equal(vote1)
        expect(lockedAmount).to.equal(vote1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        await time.increaseTo(latestTime + duration)
        latestTime = await time.latest()
        const updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
        expect(updatedState[0].votes).to.equal(lockedAmount)
      })

      it('Should be able to create a single permanent lock and unlock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, 0, alice.address, true)
        let latestTime = await time.latest()
        const state = [{ tokenId: 1, account: alice }]
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        await connectedEscrow.unlockPermanent(1)
        latestTime = await time.latest()
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      })

      it('Should revert on unlockPermanent when lock is not permanent', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()
        const state = [{ tokenId: 1, account: alice }]
        await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        await expect(connectedEscrow.unlockPermanent(1)).to.be.revertedWithCustomError(
          connectedEscrow,
          'NotPermanentLock'
        )
      })

      it('Should be able to create a single lock and update to permanent', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

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
        let updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        await connectedEscrow.increaseUnlockTime(1, 0, true)
        latestTime = await time.latest()
        updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        expect(updatedState[0].votes).to.equal(lockedAmount)
      })
    })

    describe('Withdraw/Claim', function () {
      it('Should be able to withdraw after lock expires', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, clockUnit, mockToken, lockedAmount } = await loadFixture(
          fixture
        )

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLockFor(lockedAmount, clockUnit, alice.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + clockUnit)

        const vestedPayout = await connectedEscrow.vestedPayout(1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        expect(vestedPayout).to.equal(lockedAmount)

        await connectedEscrow.claim(1)

        const finalBalance = await connectedToken.balanceOf(alice.address)
        const finalSupply = await connectedEscrow.supply()

        expect(finalBalance).to.equal(balanceBefore)
        expect(finalSupply).to.equal(supplyBefore)
      })

      it('Should revert on claim of permanent lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, 0, alice.address, true)

        await expect(connectedEscrow.claim(1)).to.be.revertedWithCustomError(connectedEscrow, 'PermanentLock')
      })

      it('Should be able to claim after lock expires', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, clockUnit, lockedAmount } = await loadFixture(
          fixture
        )

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)
        const supplyBefore = await connectedEscrow.supply()

        await connectedEscrow.createLockFor(lockedAmount, clockUnit, alice.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)
        const supplyAfter = await connectedEscrow.supply()

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(alice.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + clockUnit)

        const vestedPayout = await connectedEscrow.vestedPayout(1)
        expect(supplyAfter).to.equal(supplyBefore.add(lockedAmount))

        expect(vestedPayout).to.equal(lockedAmount)

        await connectedEscrow.claim(1)

        const finalBalance = await connectedToken.balanceOf(alice.address)
        const finalSupply = await connectedEscrow.supply()

        expect(finalBalance).to.equal(balanceBefore)
        expect(finalSupply).to.equal(supplyBefore)
      })

      it('Should not be able to claim before lock expires', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
          fixture
        )

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

        await expect(connectedEscrow.claim(1)).to.be.revertedWithCustomError(connectedEscrow, 'LockNotExpired')
      })

      it('Should be able to claim on behalf of other user that approved', async function () {
        const { alice, bob, votingEscrow, clockUnit, mockToken, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedEscrowBob = votingEscrow.connect(bob)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        await connectedEscrow.createLockFor(lockedAmount, clockUnit, bob.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(bob.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + clockUnit)

        await connectedEscrowBob.setApprovalForAll(alice.address, true)

        const vestedPayout = await connectedEscrow.vestedPayout(1)

        expect(vestedPayout).to.equal(lockedAmount)

        await connectedEscrow.claim(1)

        const finalBalance = await mockToken.balanceOf(alice.address)

        expect(finalBalance).to.equal(balanceBefore)
      })

      it('Should not be able to claim on behalf of other user', async function () {
        const { alice, bob, votingEscrow, clockUnit, mockToken, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedToken = mockToken.connect(alice)

        const balanceBefore = await connectedToken.balanceOf(alice.address)

        await connectedEscrow.createLockFor(lockedAmount, clockUnit, bob.address, false)
        const latestTime = await time.latest()

        const balanceAfter = await connectedToken.balanceOf(alice.address)

        const ownerOf = await votingEscrow.ownerOf(1)
        const lockDetails = await votingEscrow.lockDetails(1)

        expect(ownerOf).to.equal(bob.address)

        expect(balanceAfter).to.equal(balanceBefore.sub(lockedAmount))

        expect(lockDetails.amount).to.equal(lockedAmount)

        await time.increaseTo(latestTime + clockUnit)

        const vestedPayout = await connectedEscrow.vestedPayout(1)

        expect(vestedPayout).to.equal(lockedAmount)

        await expect(connectedEscrow.claim(1)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })
    })

    describe('Split', function () {
      it('Should be able to split an unexpired lock in two', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, votingEscrowTestHelper, latestTime)
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
          votingEscrowTestHelper,
          latestTime
        )
      })

      it('Should not be able to split an unauthorized veNFT', async function () {
        const { alice, bob, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)
        const connectedEscrowBob = votingEscrow.connect(bob)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, votingEscrowTestHelper, latestTime)
        await time.increaseTo(latestTime + oneDay)

        await expect(connectedEscrowBob.split([50, 50], 1)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })

      it('Should revert on split of expired veNFT', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, votingEscrowTestHelper, latestTime)
        await time.increaseTo(latestTime + duration)

        await expect(connectedEscrow.split([50, 50], 1)).to.be.revertedWithCustomError(connectedEscrow, 'LockExpired')
      })

      it('Should be able to split an unexpired lock in many uneven parts', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        let latestTime = await time.latest()

        await validateState([{ tokenId: 1, account: alice }], votingEscrow, votingEscrowTestHelper, latestTime)
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
        const updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
        console.log(updatedState)
      })
    })

    describe('Merge', function () {
      it('Should be able to merge two unexpired locks', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

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
          votingEscrowTestHelper,
          latestTime
        )
        await time.increaseTo(latestTime + oneDay)

        await connectedEscrow.merge(1, 2)
        latestTime = await time.latest()

        const updatedState = await validateState(
          [{ tokenId: 2, account: alice }],
          votingEscrow,
          votingEscrowTestHelper,
          latestTime
        )

        expect(updatedState[0].details.amount).to.equal(lockedAmount * 2)
      })

      it('Should be able to merge two unexpired locks with one being permanent', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        const oneDay = 24 * 60 * 60

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, true)
        let latestTime = await time.latest()

        await validateState(
          [
            { tokenId: 1, account: alice },
            { tokenId: 2, account: alice },
          ],
          votingEscrow,
          votingEscrowTestHelper,
          latestTime
        )
        await time.increaseTo(latestTime + oneDay)

        await connectedEscrow.merge(1, 2)
        latestTime = await time.latest()

        const updatedState = await validateState(
          [{ tokenId: 2, account: alice }],
          votingEscrow,
          votingEscrowTestHelper,
          latestTime
        )

        expect(updatedState[0].details.amount).to.equal(lockedAmount * 2)
      })

      it('Should merge veNFT and keep lockTime of longest lock', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
        const state = [
          { tokenId: 1, account: alice },
          { tokenId: 2, account: alice },
        ]
        let latestTime = await time.latest()
        let updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

        await connectedEscrow.merge(1, 2)
        console.log(updatedState)
        let details = await connectedEscrow.lockDetails(2)
        console.log(details)

        expect(details.endTime).to.equal(updatedState[1].details.endTime)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
        details = await connectedEscrow.lockDetails(4)

        await connectedEscrow.merge(4, 3)
        const newDetails = await connectedEscrow.lockDetails(3)
        expect(details.endTime).to.equal(newDetails.endTime)
      })

      it('Should not be able to merge an unauthorized veNFT', async function () {
        const { alice, bob, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

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
          votingEscrowTestHelper,
          latestTime
        )
        await time.increaseTo(latestTime + oneDay)

        await expect(connectedEscrowBob.merge(1, 2)).to.be.revertedWithCustomError(
          connectedEscrow,
          'ERC721InsufficientApproval'
        )
      })

      it('Should revert when merging same veNFT id', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)

        await expect(connectedEscrow.merge(1, 1)).to.be.revertedWithCustomError(connectedEscrow, 'SameNFT')
      })

      it('Should revert when merging expired veNFT id', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, false)
        await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
        let latestTime = await time.latest()
        await time.increaseTo(latestTime + duration)

        await expect(connectedEscrow.merge(2, 1)).to.be.revertedWithCustomError(connectedEscrow, 'LockExpired')
      })

      it('Should revert when merging from perma lock veNFT id', async function () {
        const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

        const connectedEscrow = votingEscrow.connect(alice)

        await connectedEscrow.createLockFor(lockedAmount, duration, alice.address, true)
        await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)

        await expect(connectedEscrow.merge(1, 2)).to.be.revertedWithCustomError(connectedEscrow, 'PermanentLock')
      })
    })
  })

  describe('Delegation', function () {
    it('Should self delegate upon veNFT creation', async function () {
      const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      const state = [
        { tokenId: 1, account: alice },
        { tokenId: 2, account: alice },
        { tokenId: 3, account: alice },
      ]
      let latestTime = await time.latest()
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      const aliceDelegates = await connectedEscrow.accountDelegates(alice.address)
      console.log(aliceDelegates)
      aliceDelegates.forEach((delegate) => {
        expect(delegate).to.equal(alice.address)
      })
    })

    it('Should delegate all veNFTs of one address', async function () {
      const { alice, bob, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

      const connectedEscrow = votingEscrow.connect(alice)

      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLock(lockedAmount, duration * 2, false)
      await connectedEscrow.createLockFor(lockedAmount, duration * 2, alice.address, false)
      await connectedEscrow.createLockFor(lockedAmount, duration * 2, bob.address, false)
      const state = [
        { tokenId: 1, account: alice },
        { tokenId: 2, account: alice },
        { tokenId: 3, account: alice },
        { tokenId: 4, account: alice },
        { tokenId: 5, account: alice },
        { tokenId: 6, account: bob },
      ]
      let latestTime = await time.latest()
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await connectedEscrow['delegate(address)'](bob.address)
      latestTime = await time.latest()

      const finalState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      const aliceBalance = await connectedEscrow.balanceOf(alice.address)
      console.log(finalState)
      console.log(aliceBalance)
      expect(finalState[0].votes).to.equal(0)
      expect(finalState[5].votes).to.equal(
        finalState[0].bias
          .add(finalState[1].bias)
          .add(finalState[2].bias)
          .add(finalState[3].bias)
          .add(finalState[4].bias)
          .add(finalState[5].bias)
      )
    })

    it('Should be able to process two years worth of checkpoints', async function () {
      this.timeout(800000)
      const { alice, bob, votingEscrow, clockUnit, votingEscrowTestHelper, lockedAmount, accounts } = await loadFixture(
        fixture
      )

      const connectedEscrow = votingEscrow.connect(alice)
      let latestTokenId = (await votingEscrow.totalSupply()).toNumber()
      let state = [] as any

      console.log(accounts.length)
      console.time('createLocks')
      let result = await createManyLocks(
        accounts,
        clockUnit,
        votingEscrowTestHelper,
        lockedAmount,
        latestTokenId,
        state
      )
      state = result.state
      latestTokenId = result.latestTokenId

      console.timeEnd('createLocks')

      let latestTime = await time.latest()

      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      await time.increaseTo(latestTime + MAX_TIME)
      latestTime = await time.latest()
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      let totalSupply = await votingEscrow.getPastTotalSupply(latestTime)

      await connectedEscrow['delegate(address)'](bob.address)
      latestTime = await time.latest()
      totalSupply = await votingEscrow.getPastTotalSupply(latestTime)

      await votingEscrow.globalCheckpoint()
      latestTime = await time.latest()
      totalSupply = await votingEscrow.getPastTotalSupply(latestTime)

      const finalState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      console.log(finalState)

      result = await createManyLocks(accounts, clockUnit, votingEscrowTestHelper, lockedAmount, latestTokenId, state)
      state = result.state
      latestTokenId = result.latestTokenId
      latestTime = await time.latest()
      const newState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      console.log(newState)
    })
  })

  describe('General Checkpoint tests', function () {
    it('Should be able to create a single lock', async function () {
      const { alice, votingEscrow, votingEscrowTestHelper, mockToken, duration, lockedAmount } = await loadFixture(
        fixture
      )

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
      const { alice, bob, calvin, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(
        fixture
      )
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

      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)
      latestTime = await time.latest()

      let updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      await connectedEscrow.globalCheckpoint()
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, calvin.address)
      await connectedEscrow['delegate(uint256,address)'](2, alice.address)

      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[2].votes)
      expect(updatedState[1].bias.add(updatedState[2].bias)).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)

      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[1].votes)
      expect(updatedState[1].bias.add(updatedState[2].bias)).to.equal(updatedState[0].votes)

      await connectedEscrow['delegate(uint256,address)'](1, alice.address)
      await connectedEscrow['delegate(uint256,address)'](2, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, calvin.address)

      latestTime = await time.latest()
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)

      await time.increaseTo(latestTime + duration / 2)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)

      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)
      await finalStateCheck(state, stateHistory, votingEscrow, votingEscrowTestHelper)

      await time.increaseTo(latestTime + duration)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias).to.equal(updatedState[0].votes)
      expect(updatedState[1].bias).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[2].votes)
      await finalStateCheck(state, stateHistory, votingEscrow, votingEscrowTestHelper)
    })

    it('Should have adecuate balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(
        fixture
      )
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

      let updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      await finalStateCheck(state, stateHistory, votingEscrow, votingEscrowTestHelper)
    })

    it('Should have adecuate delegated balances over time', async function () {
      const { alice, bob, calvin, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(
        fixture
      )
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

      let updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow['delegate(uint256,address)'](1, bob.address)
      await connectedEscrow['delegate(uint256,address)'](3, alice.address)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[1].votes)
      expect(updatedState[2].bias).to.equal(updatedState[0].votes)

      await connectedEscrow.globalCheckpoint()
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 7884000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow.globalCheckpoint()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState

      await connectedEscrow['delegate(uint256,address)'](1, alice.address)

      latestTime = await time.latest()
      updatedState = await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
      stateHistory[latestTime] = updatedState
      await connectedEscrow.checkpointDelegatee(alice.address)
      expect(updatedState[0].bias.add(updatedState[1].bias)).to.equal(updatedState[0].votes)

      await finalStateCheck(state, stateHistory, votingEscrow, votingEscrowTestHelper)
    })

    it('Should have adecuately calculate voting power for one lock over time', async function () {
      // TODO: Revisit validate state (as it checks things twot times)
      const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

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
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 4 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(supplyAt).to.equal(vote)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
    })

    it('Should have adecuately calculate voting power after increasing ammount for one lock over time', async function () {
      // TODO: Revisit validate state (as it checks things twot times)
      const { alice, votingEscrow, votingEscrowTestHelper, duration, lockedAmount } = await loadFixture(fixture)

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
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await time.increaseTo(latestTime + 3942000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after third lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

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
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)

      await time.increaseTo(latestTime + 15768000)
      latestTime = await time.latest()

      slope = lockDetails.amount.mul(PRECISION).div(MAX_TIME)
      power = slope.mul(lockDetails.endTime.sub(latestTime)).div(PRECISION)

      supplyAt = await votingEscrow.getPastTotalSupply(latestTime)
      vote = await connectedEscrow.getPastVotes(alice.address, latestTime)
      console.log(`-- Supply after 5 lock  ${supplyAt} -- Slope ${slope} -- Power ${power} -- Vote ${vote} --'`)
      expect(isWithinLimit(power, vote, 1)).to.be.true
      expect(isWithinLimit(supplyAt, vote, 1)).to.be.true
      await validateState(state, votingEscrow, votingEscrowTestHelper, latestTime)
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
