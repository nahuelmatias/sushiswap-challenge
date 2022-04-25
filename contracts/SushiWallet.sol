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

interface SushiSwapPair {
    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );
}

interface SushiSwapV2Factory {
    function getPair(address, address) external view returns (address);
}

interface SushiSwapRouter {
    function factory() external view returns (address);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
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

contract SushiWallet is Ownable {
    string public constant name = "SushiWallet";
    address SushiRouterAddress; //Addr for SushiSwap router: https://dev.sushi.com/sushiswap/contracts ( 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506 )

    event Rescue(address tokenAddress, uint256 amount);

    constructor(address sushiRouterAddr) {
        _owner = msg.sender;
        SushiRouterAddress = sushiRouterAddr;
    }

    function subscribeToPool(
        address token_A_addr,
        address token_B_addr,
        uint256 token_A_amount,
        uint256 token_B_amount
    ) public onlyOwner returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Order tokens to get normalization in the data treatment.
        (address token0, address token1) = token_A_addr < token_B_addr
            ? (token_A_addr, token_B_addr)
            : (token_B_addr, token_A_addr);
        (uint256 token0Amount, uint256 token1Amount) = token_A_addr < token_B_addr
            ? (token_A_amount, token_B_amount)
            : (token_B_amount, token_A_amount);

        //1st: approve tokens A for the desired amount. Why not check for allow first? Because i will approve only for the current tx.
        if (!approveTokensForRouter(token0, token0Amount)) {
            //something has failed
            console.log("Error at Approve A tokens.");
            revert("Cannot Approve A Tokens");
        }
        if (!approveTokensForRouter(token1, token1Amount)) {
            //something has failed
            console.log("Error at Approve B tokens.");
            revert("Cannot Approve B Tokens");
        }
        //2nd: Calculate parity of tokens, if exists. If it does not exist, return 0. (I think that you can define your own LP with your own ratio, and SushiSwap
        // creates the LP by yourself, but i'm not sure and this is money.)
        uint256 amountBMin = calculateAmountOfToken1(token0, token1, token0Amount);
        if (amountBMin == 0) {
            console.log("The pair does not exist.");
            revert("The pair does not exist.");
        }
        console.log(amountBMin);
        if (amountBMin > token1Amount) {
            //it means that we didn't provide enought funds of the second token
            console.log("Not enought funds for the second token.");
            revert("Not enought funds for the second token.");
        }

        //3rd: Try to call SushiSwap to provide liquidity, tolerate only 0,5 of slippage, and only 30min for timeout
        (amountA,amountB,liquidity) = provideLiquidity(token0,token1,token0Amount,token1Amount);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param erc20TokenAddress a parameter just like in doxygen (must be followed by parameter name)
    /// @return success the return variables of a contract’s function state variable
    function approveTokensForRouter(address erc20TokenAddress, uint256 amountApprovedToSpend)
        internal
        onlyOwner
        returns (bool success)
    {
        //It should be something like:
        return IERC20(erc20TokenAddress).approve(SushiRouterAddress, amountApprovedToSpend);
    }

    function approveTokensForMasterChef(address erc20TokenAddress) internal onlyOwner returns (uint256) {}

    /// @notice provideLiquidity
    /// @dev Call Pool, compute 0,5% of slippage, and the timeout. Returns with the values of the pool
    /// @param tokenA First token to provide liquidity
    /// @param tokenB Second token to provide liquidity
    /// @param amountADesired First Token Amount to provide
    /// @param amountBDesired Second Token Amount to provide

    /// @return amountA the amount of First Token added to the pool.
    /// @return amountB the amount of First Token added to the pool.
    /// @return liquidity the percentage of the pool.

    function provideLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired
    )
        internal
        onlyOwner
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        uint256 amountAMin = 995*amountADesired / 1000;
        uint256 amountBMin = 995*amountBDesired / 1000;
        uint256 deadline = block.timestamp + 30 minutes;
        return
            SushiSwapRouter(SushiRouterAddress).addLiquidity(
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                address(this),
                deadline
            );
    }

    //Encapsulate the calculation if pair exists.
    function checkIfPairExists(address tokenA, address tokenB) public view onlyOwner returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = SushiSwapV2Factory(SushiSwapRouter(SushiRouterAddress).factory()).getPair(token0, token1);
    }

    //encapsulate the calculation of x*y=k if pair exists.
    function calculateAmountOfToken1(
        address token0,
        address token1,
        uint256 amount0
    ) public view onlyOwner returns (uint256 token1Amount) {
        //1st: locate pair, if exists. If it not exists, return 0.
        address pair = checkIfPairExists(token0, token1);
        if (pair == address(0)) {
            return 0;
        }
        (uint256 reserve0, uint256 reserve1, uint256 lastBlockTimestamp) = SushiSwapPair(pair).getReserves();
        token1Amount = SushiSwapRouter(SushiRouterAddress).quote(amount0, reserve0, reserve1);
    }

    function rescueTokens(address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_msgSender(), amount);
        emit Rescue(_token, amount);
    }
}
