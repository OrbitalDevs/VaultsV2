// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "../../../functions.sol";

import "interfaces/IV3SwapRouter.sol";


abstract contract MockUniswapV3Router is IV3SwapRouter {
    mapping(address => uint256) public tokenBalances;

    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        address[] memory path = functions.decodeAddresses(params.path);
        address tokenIn = path[0];
        address tokenOut = path[params.path.length - 1];
        require(params.amountIn <= IERC20(tokenIn).balanceOf(msg.sender), "Insufficient token balance");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= params.amountIn, "Insufficient allowance");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        tokenBalances[tokenIn] += params.amountIn;

        // You can add any logic here to calculate the amountOut based on your testing requirements.
        // For simplicity, we're just setting it to half of the amountIn.
        amountOut = params.amountIn / 2;
        tokenBalances[tokenOut] -= amountOut;

        require(tokenBalances[tokenOut] >= amountOut, "Not enough tokens in the router");
        IERC20(tokenOut).transfer(params.recipient, amountOut);

        // emit ExactInput(params.amountIn, amountOut);
    }

    // function addLiquidity(AddLiquidityParams calldata params) external override {
    //     // This function can be implemented as per your testing requirements.
    // }

    // function removeLiquidity(RemoveLiquidityParams calldata params) external override {
    //     // This function can be implemented as per your testing requirements.
    // }
}

contract MockUniswapV2Router02 {
    using SafeERC20 for IERC20;

    uint256 public rate;

    constructor() {
        rate = 2; // 1 tokenIn = 2 tokenOut
    }

    function setRate(uint256 newRate) external {
        rate = newRate;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        IERC20 tokenIn = IERC20(path[0]);
        IERC20 tokenOut = IERC20(path[path.length - 1]);

        uint256 amountOut = amountIn * rate;

        require(amountOut >= amountOutMin, "insufficient output amount");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(to, amountOut);
    }
}
