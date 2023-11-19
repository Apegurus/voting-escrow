/**
 * # Usage
 *
 * 1. Add this file to the root/plugins directory
 * 2. Add the following to hardhat.config.ts:
 *    import './plugins/abiPlugins'
 * 3. Use the abiCompare function in a script:
 *    const { baseAbi, contract1ExtendedAbi, contract2ExtendedAbi } = await hre.abiCompare(contract1, contract2, subDir)
 *
 */
import { extendEnvironment } from 'hardhat/config'
import { HardhatPluginError } from 'hardhat/plugins'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { generateSolidity } from 'abi-to-sol'
import fs from 'fs'
import path from 'path'

// Extend the Hardhat Runtime Environment with abiPlugins
declare module 'hardhat/types' {
  interface HardhatRuntimeEnvironment {
    abiCompare: (
      contract1: string,
      contract2: string,
      subDir?: string
    ) => Promise<{
      baseAbi: any[]
      contract1ExtendedAbi: any[]
      contract2ExtendedAbi: any[]
    }>
    abiToInterface: (parameters: Partial<Parameters<typeof generateSolidity>[0]>) => Promise<string>
  }
}

// This is a Hardhat plugin that will add an `abiCompare` function to the Hardhat Runtime Environment
extendEnvironment((hre: HardhatRuntimeEnvironment) => {
  /**
   * Compare the ABIs of two contracts and return the base ABI and the extended ABIs.
   *
   * @param contractName1
   * @param contractName2
   * @param subDir sub directory inside of the artifacts directory where the ABIs are located. Should match the contracts/ directory structure.
   * @returns
   */
  hre.abiCompare = async function (contractName1: string, contractName2: string, subDir: string = '') {
    // TODO: This provides a sub dir param, but I would prefer to iterate through all contracts in the artifacts dir
    const getContractPath = (contractName: string) =>
      path.join(hre.config.paths.artifacts, `contracts/${subDir}${contractName}.sol/${contractName}.json`)
    const contract1AbiPath = getContractPath(contractName1)
    const contract2AbiPath = getContractPath(contractName2)

    if (!fs.existsSync(contract1AbiPath) || !fs.existsSync(contract2AbiPath)) {
      throw new HardhatPluginError(
        'abiCompare',
        `Contracts ${contractName1} or ${contractName2} not found in artifacts directory.`
      )
    }

    const contract1Abi = JSON.parse(fs.readFileSync(contract1AbiPath, 'utf8')).abi
    const contract2Abi = JSON.parse(fs.readFileSync(contract2AbiPath, 'utf8')).abi

    const baseAbi = []
    const contract1ExtendedAbi = []
    const contract2ExtendedAbi = []

    for (const func of contract1Abi) {
      if (contract2Abi.some((item: {}) => JSON.stringify(item) === JSON.stringify(func))) {
        baseAbi.push(func)
      } else {
        contract1ExtendedAbi.push(func)
      }
    }

    for (const func of contract2Abi) {
      if (!baseAbi.some((item) => JSON.stringify(item) === JSON.stringify(func))) {
        contract2ExtendedAbi.push(func)
      }
    }

    return {
      baseAbi,
      contract1ExtendedAbi,
      contract2ExtendedAbi,
    }
  }

  /**
   * Uses abi-to-sol to convert an ABI to a Solidity interface.
   *
   * @param parameters Uses a partial and provides default values if not provided.
   * @returns
   */
  hre.abiToInterface = async function (parameters: Partial<Parameters<typeof generateSolidity>[0]> = {}) {
    const defaultParameters: Parameters<typeof generateSolidity>[0] = {
      abi: [],
      name: 'IContract',
      solidityVersion: '^0.8.0',
      license: 'UNLICENSED', // MIT, GPL-3.0-or-later
      prettifyOutput: true,
      outputAttribution: true,
      outputSource: false,
    }

    const finalParameters = { ...defaultParameters, ...parameters }

    const solidityInterface = generateSolidity(finalParameters)

    return solidityInterface
  }
})
