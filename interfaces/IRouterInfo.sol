// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;


interface IRouterInfo {
    // Structs
    struct listInfo {
        bool allowed;
        uint256 listPosition;
    }

    struct pair {
        address token0;
        address token1;
        uint256 numPathsAllowed;
    }

    // RouterInfo functions
    function getName() external view returns (string memory);
    function getRouterAddress() external view returns (address);
    function getRouterType() external view returns (uint256);
    function getInfo() external view returns (string memory, address, uint256);

    // Allowed pairs functions
    function getNumAllowedPairs() external view returns (uint256);
    function getAllowedPair(uint256 index) external view returns (pair memory pairInfo);
    function isPairAllowed(address token0, address token1) external view returns (bool);

    // Allowed paths for each pair
    function getNumAllowedPaths(address token0, address token1) external view returns (uint256);
    function getAllowedPath(address token0, address token1, uint256 pathIndex) external view returns (bytes memory);

    // Path management functions
    function allowPath(address token0, address token1, bytes memory path) external;
    function disallowPath(address token0, address token1, uint256 pathIndex) external;
}

// interface IRouterInfo  {
//     struct pair {
//         address token0;
//         address token1;
//         uint256 numPathsAllowed;
//     }
//     function getName() external view returns (string memory);
//     function getRouterAddress() external view returns (address);
//     function getRouterType() external view returns (uint256);
//     function getInfo() external view returns (string memory, address, uint256);
//     function getNumAllowedPairs() external view returns (uint256);
//     function getAllowedPair(uint256 index) external view returns (pair memory pairInfo);
//     function isPairAllowed(address token0, address token1) external view returns (bool);
//     function getNumAllowedPaths(address token0, address token1) external view returns (uint256);
//     function getAllowedPath(address token0, address token1, uint256 pathIndex) external view returns (bytes memory);
//     function allowPath(address token0, address token1, bytes memory path) external;
//     function disallowPath(address token0, address token1, uint256 pathIndex) external;
// }