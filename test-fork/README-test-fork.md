# Fork/Simulation Testing with Hardhat

- [Hardhat: Forking other networks](https://hardhat.org/hardhat-network/docs/guides/forking-other-networks)

## Setup

1. Update [hardhat-fork.config](../hardhat-fork.config.ts) under `hardhat.forkingl.url` with the fork RPC endpoint. (Forking is only configured on the `hardhat` network, but multiple fork configs can be created for different networks.)
 --> NOTE: Any RPC works for current blocks, but for historical blocks you will need an archive node
2. Add `<fork-test>.spec.ts` files to the [test-fork](../test-fork) directory.
3. Run `yarn test:fork`
