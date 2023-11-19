import { ethers } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

/**
 * Estimates the gas cost for a read operation on a contract function.
 *
 * @template C - The type of the contract.
 * @template F - The name of the function to estimate gas for.
 * @param {C} contract - The contract instance.
 * @param {F} functionName - The name of the function to estimate gas for.
 * @param {Parameters<C[F]>} args - The arguments to pass to the function.
 * @returns {Promise<BigNumber>} - A promise that resolves with the estimated gas cost as a BigNumber.
 */
export async function estimateReadOperationGas<C extends Contract, F extends keyof C>(
  contract: C,
  functionName: F,
  args: Parameters<C[F]>
): Promise<BigNumber> {
  const transaction = {
    to: contract.address,
    data: contract.interface.encodeFunctionData(functionName as string, args),
  }

  const gasEstimate = await ethers.provider.estimateGas(transaction)
  return gasEstimate
}
