import { expect } from 'chai'
import { ethers } from 'hardhat'
import '@nomiclabs/hardhat-ethers'

import { SushiWallet__factory, SushiWallet } from '../build/types'

const IERC20_SOURCE = '@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20'

const SUSHISWAP_ROUTER_TESTNET = '0x1b02da8cb0d097eb8d57a175b88c7d8b47997506'
const DAI_TESTNET = '0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa'
const BAT_TESTNET = '0x482dC9bB08111CB875109B075A40881E48aE02Cd'
const SLP_TESTNET = '0xcA358D6C7b4721B7465eB851f946F486D6b43bAb'

const { getContractFactory, getSigners } = ethers

describe('SushiWallet', () => {
  let sushiwallet: SushiWallet
  let batContract, daiContract, slpContract

  beforeEach(async () => {
    // 1
    const signers = await getSigners()
    console.log('Account balance:', (await signers[1].getBalance()).toString())

    // 2
    const counterFactory = (await getContractFactory('SushiWallet', signers[1])) as SushiWallet__factory
    sushiwallet = await counterFactory.deploy(SUSHISWAP_ROUTER_TESTNET)
    await sushiwallet.deployed()
    // The address the Contract WILL have once mined
    console.log('Contract Address: ' + sushiwallet.address)

    // The transaction that was sent to the network to deploy the Contract
    console.log('Transaction Hash: ' + sushiwallet.deployTransaction.hash)

    // 3
    expect(sushiwallet.address).to.properAddress
  })

  // 4
  describe('Owner', async () => {
    it('Should return the address of the owner', async () => {
      const signers = await getSigners()
      const count = await sushiwallet.owner()
      expect(count).to.eq(signers[1].address)
    })
  })

  describe('Name', async () => {
    it('Should return the name of the contract', async () => {
      const name = await sushiwallet.name()
      expect(name).to.eq('SushiWallet')
    })
  })

  describe('Quotation', async () => {
    it('Should call SushiWallet, and call Quote (With DAI and BAT) ', async () => {
      const quotation = await sushiwallet.calculateAmountOfToken1(DAI_TESTNET, BAT_TESTNET, 10000)
      console.log('Quotation: ' + quotation)
      expect(quotation).to.gt(0)
    })
  })
  describe('subscribeToPool', async () => {
    it('Should call SushiWallet, and call subscribeToPool ( transferring DAI and BAT to this address) ', async () => {
      const signers = await getSigners()

      //1st: call quotation to transfer the appropiate funds.
      const quotationbat = await sushiwallet.calculateAmountOfToken1(DAI_TESTNET, BAT_TESTNET, 10000)
      console.log('Quotation: ' + quotationbat)

      //2nd: provide some funds of DAI and BAT to the sc
      batContract = await ethers.getContractAt(IERC20_SOURCE, BAT_TESTNET, signers[1])
      batContract = batContract.connect(signers[1])
      console.log('Testnet Account BAT balance', await batContract.balanceOf(signers[1].address))
      await batContract.transfer(sushiwallet.address, 10000)
      console.log('SushiWallet BAT balance', await batContract.balanceOf(sushiwallet.address))

      daiContract = await ethers.getContractAt(IERC20_SOURCE, DAI_TESTNET, signers[1])
      daiContract = daiContract.connect(signers[1])
      console.log('Testnet Account DAI balance', await daiContract.balanceOf(signers[1].address))
      await daiContract.transfer(sushiwallet.address, quotationbat)
      console.log('SushiWallet DAI balance', await daiContract.balanceOf(sushiwallet.address))

      //3rd: put it in liquidity
      const liquidity = await sushiwallet.subscribeToPool(DAI_TESTNET, BAT_TESTNET, quotationbat, 10000)
      console.log('SushiWallet Liquidity', liquidity)

      //4th: ask for SLP token if the contract has funds! (if it is correct, contract has SLP tokens available)
      slpContract = await ethers.getContractAt(IERC20_SOURCE, SLP_TESTNET, signers[1])
      slpContract = slpContract.connect(signers[1])
      const slpBalance = await slpContract.balanceOf(sushiwallet.address)
      console.log('SushiWallet SLP balance', slpBalance)
      expect(slpBalance).to.gt(0)
    }).timeout(400000)
  }).timeout(400000)
})
