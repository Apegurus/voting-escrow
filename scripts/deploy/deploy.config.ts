import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Networks } from '../../hardhat'
import path from 'path'

// Define a base directory for deployments
export const DEPLOYMENTS_BASE_DIR = path.resolve(__dirname, '../../deployments')

/**
 * Get the deploy config for a given network
 * @param network
 * @returns
 */
export const getDeployConfig = (network: DeployableNetworks, signers?: SignerWithAddress[]): DeploymentVariables => {
  const config = deployableNetworkConfig[network]
  if (!config) {
    throw new Error(`No deploy config for network ${network}`)
  }
  return config(signers)
}

/**
 * Extract networks as deployments are needed
 *
 * NOTE: Add networks as needed
 */
export type DeployableNetworks = Extract<Networks, 'bsc' | 'bscTestnet'>

/**
 * Deployment Variables for each network
 *
 * NOTE: Update variables as needed
 */
interface DeploymentVariables {
  proxyAdminAddress: string
  adminAddress: string | SignerWithAddress
  wNative?: string
  veDetails: {
    name: string
    symbol: string
    version: string
  }
  contractOverrides: {
    lockToken?: string
  }
}

const deployableNetworkConfig: Record<DeployableNetworks, (signers?: SignerWithAddress[]) => DeploymentVariables> = {
  bsc: (signers?: SignerWithAddress[]) => {
    return {
      proxyAdminAddress: '0x',
      // NOTE: Example of extracting signers
      adminAddress: signers?.[0] || '0x',
      wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      veDetails: {
        name: 'Vote Escrow',
        symbol: 'veToken',
        version: '1',
      },
      contractOverrides: {
        lockToken: '0x',
      },
    }
  },
  bscTestnet: (signers?: SignerWithAddress[]) => {
    return {
      proxyAdminAddress: '0x',
      adminAddress: signers?.[0] || '0x',
      wNative: '0x',
      veDetails: {
        name: 'Vote Escrow',
        symbol: 'veToken',
        version: '1',
      },
      contractOverrides: {
        lockToken: '0xedb8b85a779e872e2aeef39df96a7fcc7d5ea6af',
      },
    }
  },
}
