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
export const getDeployConfig = (network: DeployableNetworks, overrides: FixtureOverrides = {}): DeploymentVariables => {
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
 * DeployableNetworks is a subset of the Networks type, specifically including
 * networks where deployment scripts will be executed. To support additional networks,
 * extend the Extract type with the network's key as defined in the Networks type.
 */
export type DeployableNetworks = Extract<Networks, 'bsc' | 'bscTestnet' | 'hardhat'>

/**
 * DeploymentAccounts defines the structure for account-related configurations
 * needed during the deployment process. It currently includes an adminAddress
 * which can be a string or a SignerWithAddress object.
 *
 * Extend or modify this interface to include additional account-related configurations as needed.
 */
export interface DeploymentAccounts {
  adminAddress: string | SignerWithAddress
}

/**
 * DeploymentContractOverrides allows for specifying addresses of already deployed
 * contracts or for overriding the default addresses during deployment.
 *
 * Extend or modify this interface to include overrides for additional contracts as needed.
 */
export interface DeploymentContractOverrides {
  lockToken?: string
  votingEscrowV2Upgradeable?: string
  escrowWeightLens?: string
  proxyAdminAddress?: string
  artProxy?: string
}

/**
 * Deployment variables used for the deployment of contracts in this project.
 *
 * Extend or modify the DeploymentVariables interface if additional variables are required.
 */
interface DeploymentVariables {
  // Accounts and contract overrides should be configured above
  accounts: DeploymentAccounts
  contractOverrides: DeploymentContractOverrides
  // These deployment variables can be changed and extended as needed.
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
}

/**
 * Configuration for each deployable network. The structure is based on the interfaces above.
 *
 * accountOverrides and contractOverrides are optional and can be used to override configured values in this file.
 */
const deployableNetworkConfig: Record<
  DeployableNetworks,
  ({ accountOverrides, contractOverrides }: FixtureOverrides) => DeploymentVariables
> = {
  bsc: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || '',
      },
      contractOverrides: {
        // lockToken: contractOverrides?.lockToken || '0x2F760FCb977AF39E94A3E074dcd3649a16F8652C',
        votingEscrowV2Upgradeable: contractOverrides?.votingEscrowV2Upgradeable || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
        artProxy: contractOverrides?.artProxy || '',
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
    }
  },
  bscTestnet: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || '0x',
      },
      contractOverrides: {
        lockToken: contractOverrides?.lockToken || '0xedb8b85a779e872e2aeef39df96a7fcc7d5ea6af',
        votingEscrowV2Upgradeable: contractOverrides?.votingEscrowV2Upgradeable || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
        artProxy: contractOverrides?.artProxy || '',
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
    }
  },
  hardhat: ({ accountOverrides, contractOverrides }: FixtureOverrides) => {
    const defaultAccount = '0x-no-address-passed'
    return {
      accounts: {
        // NOTE: Example of extracting signers
        adminAddress: accountOverrides?.adminAddress || defaultAccount,
      },
      contractOverrides: {
        lockToken: contractOverrides?.lockToken || '',
        votingEscrowV2Upgradeable: contractOverrides?.votingEscrowV2Upgradeable || '',
        proxyAdminAddress: contractOverrides?.proxyAdminAddress || '',
        artProxy: contractOverrides?.artProxy || '',
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
    }
  },
}
