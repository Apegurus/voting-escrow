import { ethers } from 'hardhat'
// https://hardhat.org/hardhat-network-helpers/docs/reference
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'

import { dynamicFixture } from './fixtures'
import { deployEscrowWeightLensFixture } from '../scripts/deploy/fixtures/deployEscrowWeightLensFixture'
import { DeployManager } from '../scripts/deploy/DeployManager'
import { EscrowWeightLens, VotingEscrowV2Upgradeable } from '../typechain-types'

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
  const [deployer, admin, alice, bob, charlie] = accounts
  const deployManager = await DeployManager.create({ signer: deployer })
  const deployment = await deployEscrowWeightLensFixture(ethers, deployManager, {
    accountOverrides: {
      adminAddress: admin,
    },
    contractOverrides: {},
  })
  return { ...deployment, accounts }
}

describe('EscrowWeightLens.spec', function () {
  let FR: FixtureReturn
  let escrowWeightLens: EscrowWeightLens
  let votingEscrowV2Upgradeable: VotingEscrowV2Upgradeable

  before(async function () {
    // Add code here to run before all tests
  })

  beforeEach(async function () {
    // Add code here to run before each test
    FR = await loadFixture(fixture)
    escrowWeightLens = FR.contracts.escrowWeightLens
    votingEscrowV2Upgradeable = FR.contracts.votingEscrowV2Upgradeable
  })

  it('Should be able to load fixture', async () => {
    expect(FR).to.not.be.undefined
  })
})
