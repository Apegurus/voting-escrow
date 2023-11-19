import { ethers, network } from 'hardhat'
import { impersonateAccount, setBalance } from '@nomicfoundation/hardhat-network-helpers'

/**
 * Unlock an account and set its starting balance.
 *
 * @param address Address to impersonate
 * @param etherBalance Starting balance of the account
 * @returns
 *
 * Example usage:
 *
 * import { unlockSigner } from "./utils/accountHelper";
 *
 * describe("MyContract", () => {
 *   it("should do something with an unlocked signer", async () => {
 *     const address = "0x000000000000000000000000000000000000dead"; // Example address to impersonate
 *     const unlockedSigner = await unlockSigner(address);
 *
 *     const myContract = await ethers.getContractFactory("MyContract");
 *     const contract = await myContract.deploy();
 *
 *     // Call a contract function using the unlocked signer
 *     const result = await contract.connect(unlockedSigner).doSomething();
 *
 *     expect(result).to.equal(expectedResult);
 *   });
 * });
 *
 */
export async function unlockSigner(address: string, etherBalance = '1') {
  await impersonateAccount(address)
  await setBalance(address, ethers.utils.parseEther(etherBalance))
  return ethers.getSigner(address)
}
