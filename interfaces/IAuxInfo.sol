// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;


interface IAuxInfo {
    // Structs
    struct routerInfo {
        bool allowed;
        uint256 listPosition;
        address routerInfoContractAddress;
    }

    struct tokenInfo {
        bool allowed;
        uint256 listPosition;
        uint256 initialDenominator;
    }
    // Allowed Tokens Section
    function getNumAllowedTokens() external view returns (uint256);
    function getAllowedToken(uint256 index) external view returns (address);
    function getAllowedTokens() external view returns (address[] memory);
    function getAllowedTokenInfo(address token) external view returns (tokenInfo memory);
    function setAllowedTokenInfo(address token, uint256 initialDenominator) external;
    function allowToken(address token, uint256 initialDenominator) external;
    function disallowToken(address token) external;
    function isTokenAllowed(address token) external view returns (bool);
    function areTokensAllowed(address[] memory tokens) external view returns (bool);

    // Allowed Routers Section
    function getNumAllowedRouters() external view returns (uint256);
    function getAllowedRouter(uint256 index) external view returns (address routerAddress);
    function getRouterInfo(address routerAddress) external view returns (routerInfo memory);
    function isRouterAllowed(address routerAddress) external view returns (bool);
    function allowRouter(address routerAddress, string calldata nameIn, uint256 routerType) external returns (address routerInfoContractAddress);
    function disallowRouter(address routerAddress) external;
}

// interface IAuxInfo {
//     struct routerInfo {
//         bool allowed;
//         uint256 listPosition;
//         address routerInfoContractAddress;
//     }
//     struct tokenInfo {
//         bool allowed;
//         uint256 listPosition;
//         uint256 minDepositAmt;
//         uint256 initialDenominator;
//     }
//     //Allowed Tokens Section
//     function getNumAllowedTokens() external view returns (uint256);
//     function getAllowedToken(uint256 index) external view returns (address);
//     function getAllowedTokenInfo(address token) external view returns (tokenInfo memory);
//     function setAllowedTokenInfo(address token, uint256 minDepositAmt, uint256 initialDenominator) external;
//     function getMinDepositAmt(address token) external view returns (uint256);
//     function allowToken(address token, uint256 initialDenominator) external;
//     function disallowToken(address token) external;
//     function isTokenAllowed(address token) external view returns (bool);
//     function areTokensAllowed(address[] memory tokens) external view returns (bool);
//     //Allowed Routers Section
//     function getNumAllowedRouters() external view returns (uint256);
//     function getAllowedRouter(uint256 index) external view returns (address routerAddress);
//     function getRouterInfo(address routerAddress) external view returns (routerInfo memory);
//     function isRouterAllowed(address routerAddress) external view returns (bool);
//     function allowRouter(address routerAddress, string calldata nameIn, uint256 routerType) external;
//     function disallowRouter(address routerAddress) external;
// }