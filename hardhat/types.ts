import { CompilerOutputBytecode } from 'hardhat/types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'

export type TaskRunOptions = {
  force?: boolean
  from?: SignerWithAddress
}

export type Libraries = { [key: string]: string }

export type Artifact = {
  abi: unknown[]
  evm: {
    bytecode: CompilerOutputBytecode
    deployedBytecode: CompilerOutputBytecode
    methodIdentifiers: {
      [methodSignature: string]: string
    }
  }
}
