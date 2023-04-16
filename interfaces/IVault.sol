// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "./IV3SwapRouter.sol";

interface IVault {
    function increaseAllowance(address token, address spenderAddress, uint256 value) external;
    // function decreaseAllowance(address token, address spenderAddress, uint256 value) external;
    function trade(address routerAddress, IV3SwapRouter.ExactInputParams calldata params) external returns (uint256 receiveAmt);   
}