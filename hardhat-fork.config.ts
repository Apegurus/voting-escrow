import { getEnv } from './hardhat/utils'
import hardhatConfig from './hardhat.config'

// https://hardhat.org/hardhat-network/docs/guides/forking-other-networks
export default {
  ...hardhatConfig,
  networks: {
    ...hardhatConfig.networks,
    hardhat: {
      allowUnlimitedContractSize: false,
      forking: {
        url: getEnv('FORK_RPC_URL') || '',
      },
    },
  },
}
