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
export const getDeployConfig = (network: DeployableNetworks, overrides: FixtureOverrides): DeploymentVariables => {
  const config = deployableNetworkConfig[network]
  if (!config) {
    throw new Error(`No deploy config for network ${network}`)
  }
  return config(overrides)
}

export interface FixtureOverrides {
  accountOverrides?: Partial<DeploymentAccounts>
  contractOverrides?: DeploymentContractOverrides
}

/**
 * Extract networks as deployments are needed
 *
 * NOTE: Add networks as needed
 */
export type DeployableNetworks = Extract<Networks, 'bsc' | 'bscTestnet' | 'hardhat'>

export interface DeploymentAccounts {
  adminAddress: string | SignerWithAddress
}

export interface DeploymentContractOverrides {
  lockToken?: string
  votingEscrowV2?: string
  escrowWeightLens?: string
  proxyAdminAddress?: string
}

/**
 * Deployment Variables for each network
 *
 * NOTE: Update variables as needed
 */
interface DeploymentVariables {
  accounts: DeploymentAccounts
  wNative?: string
  veDetails: {
    name: string
    symbol: string
    version: string
  }
  escrowWeightLens: {
    durationDaysThresholds: number[]
    multipliers: number[]
  }
  contractOverrides: DeploymentContractOverrides
}

const deployableNetworkConfig: Record<
  DeployableNetworks,
  ({ accountOverrides, contractOverrides }: FixtureOverrides) => DeploymentVariables
> = {
  bsc: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || '0x',
      },
      wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      veDetails: {
        name: 'Vote Escrow',
        symbol: 'veToken',
        version: '1',
      },
      escrowWeightLens: {
        durationDaysThresholds: [365, 180, 90, 45],
        multipliers: [2000, 1500, 1250, 1000],
      },
      contractOverrides: {
        lockToken: contractOverrides?.lockToken || '0x2F760FCb977AF39E94A3E074dcd3649a16F8652C',
        votingEscrowV2: contractOverrides?.votingEscrowV2 || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
      },
    }
  },
  bscTestnet: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || '0x',
      },
      wNative: '0x',
      veDetails: {
        name: 'Vote Escrow',
        symbol: 'veToken',
        version: '1',
      },
      escrowWeightLens: {
        durationDaysThresholds: [365, 180, 90, 45],
        multipliers: [2000, 1500, 1250, 1000],
      },
      contractOverrides: {
        lockToken: contractOverrides?.lockToken || '0xedb8b85a779e872e2aeef39df96a7fcc7d5ea6af',
        votingEscrowV2: contractOverrides?.votingEscrowV2 || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
      },
    }
  },
  hardhat: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    const defaultAccount = '0x-no-address-passed'
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || defaultAccount,
      },
      wNative: '0x',
      veDetails: {
        name: 'Vote Escrow',
        symbol: 'veToken',
        version: '1',
      },
      escrowWeightLens: {
        durationDaysThresholds: [365, 180, 90, 45],
        multipliers: [2000, 1500, 1250, 1000],
      },
      contractOverrides: {
        lockToken: contractOverrides?.lockToken || '',
        votingEscrowV2: contractOverrides?.votingEscrowV2 || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
      },
    }
  },
}
