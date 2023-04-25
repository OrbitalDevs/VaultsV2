// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./ISharedV2.sol";

interface IVaultInfo {
    function getVaultInfo(address vaultAddress) external view 
        returns (ISharedV2.vaultInfoOut memory);
    function getAmtsNeededForDeposit(address vaultAddress, uint256 indexOfReferenceToken, uint256 amtIn) external view 
        returns (uint256 requestCode, uint256[] memory amtsNeeded);
    function getUserBalances(address vaultAddress, address userAddress) external view 
        returns (uint256[] memory bals);
}