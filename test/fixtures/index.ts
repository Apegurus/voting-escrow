import { ethers } from 'hardhat'
export * from './deployLock'

/**
 * Example of a configurable fixture.
 *
 * @param _ethers
 * @returns
 */
export async function dynamicFixture(_ethers: typeof ethers, contractName: string, params?: any[]) {
  // Will return undefined if contract artifact doesn't exist
  const Contract = await _ethers.getContractFactory(contractName).catch(() => undefined)
  const contract = Contract ? (params ? await Contract.deploy(...params) : await Contract.deploy()) : undefined

  return { contract }
}
