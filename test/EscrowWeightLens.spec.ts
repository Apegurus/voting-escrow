import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { dynamicFixture } from './fixtures'
import { deployEscrowWeightLensFixture } from '../scripts/deploy/fixtures/deployEscrowWeightLensFixture'
import { DeployManager } from '../scripts/deploy/DeployManager'
import { ERC20Mock, EscrowWeightLens, VotingEscrowV2Upgradeable } from '../typechain-types'
import { BigNumber, BigNumberish } from 'ethers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { parseEther } from 'ethers/lib/utils'

/**
 * Helper function to convert days to seconds.
 * @param {number} days - The number of days to convert.
 * @returns {number} The number of seconds in the given days.
 */
function getSecondsFromDays(days: number): number {
  return days * 24 * 60 * 60
}

type LockConfig = { lockTimeInDays: number; lockAmount: BigNumberish; signer: SignerWithAddress }

/**
 * Helper function to create locks for a given address with an array of lock configurations.
 * @param {SignerWithAddress} signerWithAddress - The signer object with an address property.
 * @param {Array<{lockTimeInDays: number, lockAmount: BigNumber}>} lockConfigs - An array of lock configurations.
 * @param {VotingEscrowV2Upgradeable} votingEscrowV2Upgradeable - The VotingEscrowV2Upgradeable contract instance.
 */
async function createLocksForAddress(lockConfigs: LockConfig[], votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable) {
  const lockTokenAddress = await votingEscrowV2Upgradeable.token()
  const lockToken = await ethers.getContractAt('ERC20Mock', lockTokenAddress)

  for (const lockConfig of lockConfigs) {
    const lockTimeInSeconds = getSecondsFromDays(lockConfig.lockTimeInDays)
    const lockAmount = lockConfig.lockAmount
    const permanentLockTime = false
    await lockToken.connect(lockConfig.signer).approve(votingEscrowV2Upgradeable.address, lockAmount)
    await votingEscrowV2Upgradeable
      .connect(lockConfig.signer)
      .createLock(lockAmount, lockTimeInSeconds, permanentLockTime)
  }
}

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
type FixtureReturn = Awaited<ReturnType<typeof fixture>>
async function fixture() {
  // Contracts are deployed using the first signer/account by default
  const accounts = await ethers.getSigners()
  const [deployer, admin, alice, bob, charlie, dan] = accounts
  const deployManager = await DeployManager.create({ signer: deployer })
  // Deploy the EscrowWeightLens contract
  const deployment = await deployEscrowWeightLensFixture(ethers, deployManager, {
    accountOverrides: {
      adminAddress: admin,
    },
    contractOverrides: {},
  })
  const votingEscrowV2Upgradeable = deployment.contracts.votingEscrowV2Upgradeable
  const lockTokenAddress = await votingEscrowV2Upgradeable.token()
  const lockToken = await ethers.getContractAt('ERC20Mock', lockTokenAddress)
  // Transfer lockTokens to each account
  const transferAmount = ethers.utils.parseEther('1000000') // 1M lockTokens
  await Promise.all([
    lockToken.connect(deployer).transfer(alice.address, transferAmount),
    lockToken.connect(deployer).transfer(bob.address, transferAmount),
    lockToken.connect(deployer).transfer(charlie.address, transferAmount),
    lockToken.connect(deployer).transfer(dan.address, transferAmount),
  ])
  // Create locks for each account
  const lockConfig: LockConfig[] = [
    { lockTimeInDays: 47, lockAmount: parseEther('1000'), signer: alice }, // 45 days lock
    { lockTimeInDays: 92, lockAmount: parseEther('3000'), signer: bob }, // 90 days lock
    { lockTimeInDays: 182, lockAmount: parseEther('6000'), signer: charlie }, // 180 days lock
    { lockTimeInDays: 367, lockAmount: parseEther('12000'), signer: dan }, // 1 year lock
  ]
  await Promise.all(lockConfig.map((config, index) => createLocksForAddress([config], votingEscrowV2Upgradeable)))

  // Return the deployment and accounts
  return {
    ...deployment,
    contracts: {
      ...deployment.contracts,
      votingEscrowV2Upgradeable,
      lockToken,
    },
    config: {
      escrowWeightLensConfig: deployment.config.escrowWeightLensConfig,
      lockConfig,
    },
    accounts: {
      deployer,
      admin,
      alice,
      bob,
      charlie,
      dan,
    },
  }
}

describe('EscrowWeightLens', function () {
  let FR: FixtureReturn
  let escrowWeightLens: EscrowWeightLens
  let votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable
  let lockToken: ERC20Mock
  let escrowWeightLensConfig: { durationDaysThresholds: number[]; multipliers: number[] }
  let lockConfig: LockConfig[] = []
  let accounts = {
    deployer: {} as SignerWithAddress,
    admin: {} as SignerWithAddress,
    alice: {} as SignerWithAddress,
    bob: {} as SignerWithAddress,
    charlie: {} as SignerWithAddress,
    dan: {} as SignerWithAddress,
  }

  before(async function () {
    // Add code here to run before all tests
  })

  beforeEach(async function () {
    // Add code here to run before each test
    FR = await loadFixture(fixture)
    escrowWeightLens = FR.contracts.escrowWeightLens
    votingEscrowV2Upgradeable = FR.contracts.votingEscrowV2Upgradeable
    lockToken = FR.contracts.lockToken
    escrowWeightLensConfig = FR.config.escrowWeightLensConfig
    lockConfig = FR.config.lockConfig
    accounts = FR.accounts
  })

  it('Should be able to load fixture', async () => {
    expect(FR).to.not.be.undefined
  })

  describe('EscrowWeightLens', function () {
    describe('Initialization', function () {
      it('should initialize with correct parameters', async function () {
        const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
        const escrowWeightMultipliers = await escrowWeightLens.getMultipliers()

        expect(await escrowWeightLens.votingEscrow()).to.equal(votingEscrowV2Upgradeable.address)
        expect(escrowWeightMultipliers._durationDaysThresholds).to.deep.equal(durationDaysThresholds)
        expect(escrowWeightMultipliers._multipliers).to.deep.equal(multipliers)
      })

      it('should fail if initialized again', async function () {
        const { durationDaysThresholds, multipliers } = escrowWeightLensConfig

        await expect(
          escrowWeightLens.initialize(votingEscrowV2Upgradeable.address, durationDaysThresholds, multipliers)
        ).to.be.revertedWith('Initializable: contract is already initialized')
      })
    })

    describe('setMultipliers', function () {
      it('should set multipliers correctly', async function () {
        const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
        await escrowWeightLens.setMultipliers(durationDaysThresholds, multipliers)
        const escrowWeightMultipliers = await escrowWeightLens.getMultipliers()

        expect(escrowWeightMultipliers._durationDaysThresholds).to.deep.equal(durationDaysThresholds)
        expect(escrowWeightMultipliers._multipliers).to.deep.equal(multipliers)
      })

      it('should fail if arrays have different lengths', async function () {
        const { durationDaysThresholds } = escrowWeightLensConfig
        const multipliers = [1000] // Incorrect length

        await expect(
          escrowWeightLens.setMultipliers(durationDaysThresholds, multipliers)
        ).to.be.revertedWithCustomError(escrowWeightLens, 'MismatchedLengths')
      })

      it('should fail if not called by owner', async function () {
        const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
        const { alice } = accounts

        await expect(
          escrowWeightLens.connect(alice).setMultipliers(durationDaysThresholds, multipliers)
        ).to.be.revertedWith('Ownable: caller is not the owner')
      })

      it('should fail if duration thresholds are not in descending order', async function () {
        const multipliers = [1500, 1300, 1100] // Correct length and precision
        const durationDaysThresholds = [30, 60, 90] // Not in descending order

        await expect(
          escrowWeightLens.setMultipliers(durationDaysThresholds, multipliers)
        ).to.be.revertedWithCustomError(escrowWeightLens, 'DurationsNotDescendingOrder')
      })

      it('should fail if any multiplier is below precision', async function () {
        const durationDaysThresholds = [90, 60, 30] // Correct order
        const multipliers = [1500, 1300, 900] // One multiplier below precision

        await expect(
          escrowWeightLens.setMultipliers(durationDaysThresholds, multipliers)
        ).to.be.revertedWithCustomError(escrowWeightLens, 'MultiplierBelowPrecision')
      })
    })

    describe('getMultiplierForDaysLocked', function () {
      it('should return the correct multiplier for given days locked', async function () {
        const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
        const daysLocked = 90 // This should match one of the thresholds

        const expectedMultiplier = multipliers[durationDaysThresholds.indexOf(daysLocked)]
        const actualMultiplier = await escrowWeightLens.getMultiplierForDaysLocked(daysLocked)

        expect(actualMultiplier.multiplier).to.equal(expectedMultiplier)
      })

      it('should return default multiplier if no thresholds are met', async function () {
        const daysLocked = 1 // This should not meet any thresholds
        const actualMultiplier = await escrowWeightLens.getMultiplierForDaysLocked(daysLocked)

        expect(actualMultiplier.multiplier).to.equal(1000)
      })
    })

    describe('getEscrowWeight', function () {
      it('should calculate total weight correctly for an owner', async function () {
        const { alice } = accounts
        const totalWeight = await escrowWeightLens.getEscrowWeight(alice.address)
        const expectedWeight = lockConfig
          .filter((config) => config.signer === alice)
          .reduce((weight, config) => {
            const durationInSeconds = config.lockTimeInDays * 24 * 60 * 60
            const multiplier = escrowWeightLensConfig.multipliers.find(
              (_, index) =>
                durationInSeconds >= getSecondsFromDays(escrowWeightLensConfig.durationDaysThresholds[index])
            )
            return weight.add(
              BigNumber.from(config.lockAmount)
                .mul(multiplier || escrowWeightLensConfig.multipliers[escrowWeightLensConfig.multipliers.length - 1])
                .div(1000)
            )
          }, ethers.BigNumber.from(0))
        expect(totalWeight.totalWeight).to.equal(expectedWeight)
      })

      it('should calculate total maxTier, and maxMultiplier correctly for an owner', async function () {
        const { alice } = accounts
        const startingTime = await time.latest()

        const aliceLockConfig: LockConfig[] = [
          // NOTE: VotingEscrowV2Upgradeable rounds the end time down to the nearest WEEK and these need to be scaled up accordingly
          { lockTimeInDays: 52, lockAmount: parseEther('1000'), signer: alice }, // Tier 1
          { lockTimeInDays: 100, lockAmount: parseEther('2000'), signer: alice }, // Tier 2
          { lockTimeInDays: 190, lockAmount: parseEther('3000'), signer: alice }, // Tier 3
          { lockTimeInDays: 367, lockAmount: parseEther('4000'), signer: alice }, // Tier 4
        ]

        let previousMaxTier = BigNumber.from(0)
        let previousMaxMultiplier = BigNumber.from(0)

        for (let i = 0; i < aliceLockConfig.length; i++) {
          await createLocksForAddress([aliceLockConfig[i]], votingEscrowV2Upgradeable)
          const { maxTier, maxMultiplier } = await escrowWeightLens.getEscrowWeight(alice.address)

          const aliceBalance = await votingEscrowV2Upgradeable.balanceOf(alice.address)
          const currentTokenId = await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(
            alice.address,
            aliceBalance.toNumber() - 1
          )
          const lockDetails = await votingEscrowV2Upgradeable.lockDetails(currentTokenId)
          const daysToExpiration = BigNumber.from(lockDetails.endTime)
            .sub(lockDetails.startTime)
            .div(24 * 60 * 60)
          console.log(`Expected days to expiration: ${daysToExpiration.toString()}`)

          expect(maxTier).to.be.gt(previousMaxTier)
          expect(maxMultiplier).to.be.gt(previousMaxMultiplier)

          previousMaxTier = maxTier
          previousMaxMultiplier = maxMultiplier
        }

        expect(previousMaxTier).to.equal(BigNumber.from(4))
        expect(previousMaxMultiplier).to.equal(BigNumber.from(2000))
      })

      it('should return 0 if owner has no balance', async function () {
        const { charlie } = accounts
        await time.increase(365 * 24 * 60 * 60) // Increase time to unlock all tokens
        const charlieTokenId = await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(charlie.address, 0)
        await votingEscrowV2Upgradeable.connect(charlie).claim(charlieTokenId) // Assuming this is the method to withdraw all tokens
        const totalWeight = await escrowWeightLens.getEscrowWeight(charlie.address)
        expect(totalWeight.totalWeight).to.equal(0)
      })
    })

    describe('getEscrowWeightForTokenIds', function () {
      it('should calculate total weight correctly for given token IDs', async function () {
        const { alice } = accounts

        const additionalLockConfig = [
          { lockTimeInDays: 367, lockAmount: parseEther('1000'), signer: alice }, // 30 days lock
        ]
        await createLocksForAddress(additionalLockConfig, votingEscrowV2Upgradeable)

        const tokenIds = [
          await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(alice.address, 0),
          await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(alice.address, 1),
        ]
        const lockDetails = await Promise.all(tokenIds.map((tokenId) => votingEscrowV2Upgradeable.lockDetails(tokenId)))

        let expectedWeight = BigNumber.from(0)
        for (const tokenId of tokenIds) {
          const escrowWeight = await escrowWeightLens.getEscrowWeightForTokenIds(alice.address, [tokenId])
          expectedWeight = expectedWeight.add(escrowWeight.totalWeight)
        }

        const actualEscrowWeight = await escrowWeightLens.getEscrowWeightForTokenIds(alice.address, tokenIds)
        expect(actualEscrowWeight.totalWeight).to.equal(expectedWeight)
        // Perform manual calculation to verify
        const calculatedWeight = lockDetails[0].amount
          .mul(BigNumber.from(1))
          .add(lockDetails[1].amount.mul(BigNumber.from(2)))
        expect(actualEscrowWeight.totalWeight).to.equal(calculatedWeight)
      })

      it('should fail if a token ID does not belong to the owner', async function () {
        const { alice, bob } = accounts

        const tokenId = await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(bob.address, 0)

        await expect(
          escrowWeightLens.getEscrowWeightForTokenIds(alice.address, [tokenId])
        ).to.be.revertedWithCustomError(escrowWeightLens, 'NotLockOwner')
      })
    })

    describe('Internal Functions', function () {
      describe('_setMultipliers', function () {
        it('should correctly set internal multipliers and thresholds', async function () {
          const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
          await escrowWeightLens.setMultipliers(durationDaysThresholds, multipliers)
          const { _durationDaysThresholds, _multipliers } = await escrowWeightLens.getMultipliers()

          expect(_durationDaysThresholds).to.deep.equal(durationDaysThresholds)
          expect(_multipliers).to.deep.equal(multipliers)
        })
      })
      describe('_getMultiplierForSecondsLocked', function () {
        it('should return the correct multiplier for given seconds locked', async function () {
          const { durationDaysThresholds, multipliers } = escrowWeightLensConfig
          const expectedMultiplier = multipliers[0]

          const actualMultiplier = await escrowWeightLens.getMultiplierForDaysLocked(durationDaysThresholds[0])

          expect(actualMultiplier.multiplier).to.equal(expectedMultiplier)
        })
      })
      describe('_calculateWeight', function () {
        it('should return the correct weight for a lock', async function () {
          const { alice } = accounts
          const tokenId = await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(alice.address, 0)
          const actualWeight = await escrowWeightLens
            .connect(alice)
            .getEscrowWeightForTokenIds(alice.address, [tokenId])

          expect(actualWeight.totalWeight).to.equal(parseEther('1000'))
        })
        it('should return 0 if the lock is not active', async function () {
          // Increase time to unlock all tokens
          await time.increase(getSecondsFromDays(750))
          const { alice } = accounts
          const tokenId = await votingEscrowV2Upgradeable.tokenOfOwnerByIndex(alice.address, 0)
          const actualWeight = await escrowWeightLens
            .connect(alice)
            .getEscrowWeightForTokenIds(alice.address, [tokenId])

          expect(actualWeight.totalWeight).to.equal(0)
        })
      })
    })
  })
})
