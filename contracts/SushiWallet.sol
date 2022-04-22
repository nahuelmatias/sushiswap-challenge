// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
// >0.8 to avoid use of SafeMath functions
//But, if you want it...
//import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";
//using SafeMath for uint; // 
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// NOTE: This contract is a challenge for https://membrane.trade 
/*
Context:
SushiSwap is a decentralized exchange (DEX) protocol based off Uniswap. 
To compete with its predecessor, SushiSwap launched a liquidity mining program that rewards 
liquidity providers that decide to deposit their tokens on their DEX.
In order to participate for the liquidity program, you have to follow the following steps
● Approve the SushiSwap router to use your tokens.
● Provide liquidity on SushiSwap by entering a pool using that is incentivized by Sushi 
(https://app.sushi.com/pool). 
● Approve the MasterChef smart contract to use your tokens
● Deposit the liquidity token (SLP) you received after supplying liquidity into a yield farm 
managed by MasterChef smart contract (https://app.sushi.com/yield), and earn SUSHI.

Challenge:
The usual process for joining the liquidity mining program consist of 4 steps. This can be tiresome 
and consume a lot of time and extra gas.
Develop a smart contract that acts as a wallet, that encapsulates all the actions required to join 
SushiSwap’s liquidity mining program into a single, handy transaction.
This should work with MasterChefV1 and MasterChefV2 and with any pair of tokens.

Proposed solution:
- Make a smartcontract (SC) that calls independently the functions of Sushiswap.
- Make a function called "rescueERC20" to recover your tokens from the SC if some problems arise.
- A little asumption: I couldn't find a way to stake SLP, so the SC Wallet only approves for Sushiswap router, provide liquidity,
  approve the MasterChef and if you want to, recover your own SLP tokens with rescueERC20 function.
- Only the owner of the contract can do operations with the SC.
- Bugs? Everywhere! (Seriously, not ready for production or resale)

 */


interface SushiSwapRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

/// @title Context
/// @author OpenZeppelin ? 
/// @notice This mini contract encapsulates the msg.sender property of a transaction.
/// @dev This mini contract encapsulates the msg.sender property of a transaction, to ensure best code following and debug
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
*@title Ownable
*@author OpenZeppelin?
*@notice This mini contract encapsulates all owner operations of the contract.
*@dev This mini contract encapsulates all owner operations of the contract, to ensure best code following and debug.
*I deleted all non-relevant code, like transfer ownership
*/
abstract contract Ownable is Context {
    address internal _owner;
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: Only the OWNER can call this function.");
        _;
    }
}


/// @title SushiWallet
/// @author Matías Araujo
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

contract SushiWallet is Ownable{

    string public constant name = "SushiWallet";
    address SushiRouterAddress; //Addr for SushiSwap router: https://dev.sushi.com/sushiswap/contracts ( 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506 )

    event Rescue(address tokenAddress,uint256 amount);

    constructor(address sushiRouterAddr) {
        _owner = msg.sender;
        SushiRouterAddress = sushiRouterAddr;
        
    }

    function subscribeToPool( address token_A_addr, address token_B_addr, uint token_A_amount, uint token_B_amount) onlyOwner public returns (uint256) {
        //1st: approve tokens A for the desired amount. Why not check for allow first? Because i will approve only for the current tx.
        if(!approveTokensForRouter(token_A_addr,token_A_amount)){
            //something has failed
            console.log("Error at Approve A tokens.");
            revert("Cannot Approve A Tokens");
        }
        if(!approveTokensForRouter(token_B_addr,token_B_amount)){
            //something has failed
            console.log("Error at Approve B tokens.");
            revert("Cannot Approve B Tokens");
        }

        //Call SushiSwap to provide liquidity
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param erc20TokenAddress a parameter just like in doxygen (must be followed by parameter name)
    /// @return success the return variables of a contract’s function state variable
    function approveTokensForRouter(address erc20TokenAddress, uint256 amountApprovedToSpend) onlyOwner public returns (bool success) {
        //It should be something like:
        return IERC20(erc20TokenAddress).approve(SushiRouterAddress,amountApprovedToSpend);
    }

    function approveTokensForMasterChef(address erc20TokenAddress) onlyOwner public returns (uint256) {}

    function provideLiquidity(address erc20TokenAddress_1 , uint256 amount_1 ,address erc20TokenAddress_2 , uint256 amount_2) onlyOwner public returns (uint256) {

    }


    function rescueTokens(address _token) onlyOwner external {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_msgSender(), amount);
        emit Rescue(_token, amount);
    }
}
