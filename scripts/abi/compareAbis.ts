import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { writeJSONToFile } from '../utils/files'
import * as fs from 'fs'

async function convertAbiToSol_FromPath(abiPath: string, contractName: string, solidityVersion: string) {
  // Read the ABI from a file
  const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'))

  const solidityInterface = await hre.abiToInterface({
    abi,
    name: contractName,
    solidityVersion,
  })

  return solidityInterface
}

const compareAbis = async (
  hre: HardhatRuntimeEnvironment,
  {
    contract1,
    contract2,
    subDir,
    baseName = 'Contract_Base',
  }: {
    contract1: string
    contract2: string
    subDir?: string
    baseName?: string
  }
) => {
  const { baseAbi, contract1ExtendedAbi, contract2ExtendedAbi } = await hre.abiCompare(contract1, contract2, subDir)

  let solidityInterface = await hre.abiToInterface({ abi: baseAbi, name: baseName, solidityVersion: '0.8.13' })
  fs.writeFileSync(__dirname + `/I${baseName}.sol`, solidityInterface)

  solidityInterface = await hre.abiToInterface({
    abi: contract1ExtendedAbi,
    name: contract1,
    solidityVersion: '0.8.13',
  })
  fs.writeFileSync(__dirname + `/I${contract1}.sol`, solidityInterface)

  solidityInterface = await hre.abiToInterface({
    abi: contract2ExtendedAbi,
    name: contract2,
    solidityVersion: '0.8.13',
  })
  fs.writeFileSync(__dirname + `/I${contract2}.sol`, solidityInterface)

  await writeJSONToFile(__dirname + `/${baseName}Abi`, baseAbi)
  await writeJSONToFile(__dirname + `/${contract1}_extendedAbi`, contract1ExtendedAbi)
  await writeJSONToFile(__dirname + `/${contract2}_extendedAbi`, contract2ExtendedAbi)
  console.log('ABIs sorted and saved to files in scripts/abi.')
}

/**
 * Example usage
 */
const options1 = {
  contract1: 'Lock',
  contract2: 'Lock',
  subDir: '',
  baseName: 'Lock_Base',
}

const options2 = {
  contract1: 'Lock',
  contract2: 'Lock',
  subDir: '',
  baseName: 'Lock_Base',
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
compareAbis(hre, options1).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
