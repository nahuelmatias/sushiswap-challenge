import '@nomiclabs/hardhat-ethers'
import { ethers } from 'hardhat'

const SUSHISWAP_ROUTER_TESTNET = '0x1b02da8cb0d097eb8d57a175b88c7d8b47997506'

async function main() {

  const signers = await ethers.getSigners()
  const deployer = signers[1]
  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const factory = await ethers.getContractFactory('SushiWallet', deployer)

  // If we had constructor arguments, they would be passed into deploy()
  const contract = await factory.deploy(SUSHISWAP_ROUTER_TESTNET)

  // The address the Contract WILL have once mined
  console.log('Contract Address: ' + contract.address)

  // The transaction that was sent to the network to deploy the Contract
  console.log('Transaction Hash: ' + contract.deployTransaction.hash)

  // The contract is NOT deployed yet; we must wait until it is mined
  await contract.deployed()
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
