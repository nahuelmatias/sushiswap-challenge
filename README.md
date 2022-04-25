# sushiswap-challenge
Challenge for Membrane: An interaction with SushiSwap.

## Instructions
Not tried in Linux, at now, only works in Windows, but I'think that this will work too in Linux.

### Installation
> yarn install

Please don't forget to create a .env file with the following data:

>INFURA_KEY="YOUR_INFURA_KEY"
>
>MNEMONIC="please do not use your real seed phrase here"
>
>ETHERSCAN_API_KEY="ETHERSCAN_API_KEY_FOR_CODE_VERIFICATION"
>
>MAIN_ACCOUNT="YOUR_ACCOUNT_FOR_DEPLOYMENT"

### Compile
> npx hardhat compile

### Deploy in Testnet
First, edit _./scripts/deploy_in_testnet.ts_ with the address of SushiSwap in the desired network. At now, it works in Kovan Testnet Network.

> npx hardhat run --network kovan .\scripts\deploy_in_testnet.ts --verbose

### Verify
> npx hardhat verify {ADDR_FROM_LAST_STEP} --network kovan  --verbose

### Usage
With the Deployment Address, transfer the desired amount of two testnet tokens to the contract and call the function **_subscribeToPool_** in Etherscan.
It will call _approve_ for the desired tokens (Please take note of the address of your tokens) and their amounts.
Afterwards, it will call SushiSwap router for the desired pair, with a slippage of 0.5%.
Lastly, it will approve SLP tokens for the contract.

**KNOWN LIMITATION**: 
- At now, it will not put SLP tokens in Yield Farming. You can rescue the SLP tokens from the contract, and do it by yourself. Honestly, at the time being, I couldn't find the function in Sushi to do this in an automated way. (The prototype of the functions are now in the code, but does nothing. I think that is _deposit_ in MasterChef, but I'm not sure)
- Only support pair of tokens, do not support ETH-Another token. (Only implies modify the caller function, with payable and return the dust ETH not used in transaction, but it is not implemented at now)
- The contract try to remove liquidity, but it can crash.
- Tests? where we're going we don't need *tests* (Not really, I owe you the tests)
- It could be improved with Openzeppelin upgradable plugins.