import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'

type BalanceSnapshot = {
  balance: BigNumber
  blockNumber: number
  timestamp: number
}

export const createNativeBalanceSnapshotter = (_ethers: typeof ethers) => {
  const snapshots: { [address: string]: BalanceSnapshot[] } = {}

  return async (address: string) => {
    const provider = _ethers.provider
    const [blockNumber, balance] = await Promise.all([provider.getBlockNumber(), provider.getBalance(address)])
    const block = await provider.getBlock(blockNumber)

    if (!snapshots[address]) {
      snapshots[address] = []
    }

    const lastSnapshot = snapshots[address].length > 0 ? snapshots[address][snapshots[address].length - 1] : null
    const newSnapshot: BalanceSnapshot = { balance, blockNumber, timestamp: block.timestamp }

    if (lastSnapshot) {
      const balanceDiff = balance.sub(lastSnapshot.balance)
      const blockDiff = blockNumber - lastSnapshot.blockNumber
      const timeDiff = block.timestamp - lastSnapshot.timestamp

      snapshots[address].push(newSnapshot)

      return { balanceDiff, blockDiff, timeDiff, snapshots: snapshots[address] }
    } else {
      snapshots[address].push(newSnapshot)
      return { balanceDiff: BigNumber.from(0), blockDiff: 0, timeDiff: 0, snapshots: snapshots[address] }
    }
  }
}

/**
 * Provide an ERC20 contract and an array of account addresses and receive on object
 *   structured { account: string(balance) }
 *
 * @param {*} erc20Address
 * @param {*} accounts
 * @returns
 */
export async function getAccountTokenBalances(erc20Address: string, accounts: string[]) {
  let promises = []
  let accountBalances = {}
  const ERC20_Factory = await ethers.getContractFactory('ERC20')
  const erc20Contract = ERC20_Factory.attach(erc20Address)

  for (const account of accounts) {
    promises.push(
      erc20Contract.balanceOf(account).then(
        (balance: BigNumber) =>
          (accountBalances = {
            ...accountBalances,
            [account]: balance.toString(),
          })
      )
    )
  }

  await Promise.all(promises)
  return accountBalances
}
