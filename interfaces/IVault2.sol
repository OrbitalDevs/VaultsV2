// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "./IV3SwapRouter.sol";
import "./ISharedV2.sol";

interface IVaultV2 {
    function D() external view returns (uint256);
    function setD(uint256 DIn) external;
    function N(address user) external view returns (uint256);
    function setN(address user, uint256 NIn) external;
    function isTokenAllowed(address token) external view returns (bool);
    function getToken(uint256 index) external view returns (address);
    function getTokens() external view returns (address[] memory);
    function getOldestTradeTime() external view returns (uint256);
    function getFees() external view returns (ISharedV2.fees memory);
    function deactivate() external;
    function setAllowOtherUsers(bool allow) external;
    function setStrategy(string calldata stratString) external;
    function setStrategyAndActivate(string calldata stratString, bool activate) external;
    function setAutotrade(bool status) external;
    function balance(address token) external view returns (uint256);
    function balances() external view returns (uint256[] memory);
    function increaseAllowance(address token, address spenderAddress, uint256 value) external;
    function tradeV2(address routerAddress, uint amountIn, uint amountOutMin, address[] calldata path) external returns (uint256 receiveAmt);
    function tradeV3(address routerAddress, IV3SwapRouter.ExactInputParams calldata params) external returns (uint256 receiveAmt);
}

// interface IVaultV2 {
//     function D() external view returns (uint256);
//     function setD(uint256 DIn) external;
//     function N(address user) external view returns (uint256);
//     function setN(address user, uint256 NIn) external;
//     function isTokenAllowed(address token) external view returns (bool);
//     function getTokenIndex(address token) external view returns (uint256);
//     function getNumTokens() external view returns (uint256);
//     function getToken(uint256 index) external view returns (address);
//     function getTokens() external view returns (address[] memory);
//     function getName() external view returns (string memory);
//     function getCreationTime() external view returns (uint256);
//     function getOldestTradeTime() external view returns (uint256);
//     function getFees() external view returns (ISharedV2.fees memory);
//     function deactivate() external;
//     function setAllowOtherUsers(bool allow) external;
//     function setStrategy(string calldata stratString) external;
//     function setStrategyAndActivate(string calldata stratString, bool activate) external;
//     function setAutotrade(bool status) external;
//     function balance(address token) external view returns (uint256);
//     function balances() external view returns (uint256[] memory);
//     function increaseAllowance(address token, address spenderAddress, uint256 value) external;
//     function tradeV2(address routerAddress, uint amountIn, uint amountOutMin, address[] calldata path) external returns (uint256 receiveAmt);
//     function tradeV3(address routerAddress, IV3SwapRouter.ExactInputParams calldata params) external returns (uint256 receiveAmt);
// }