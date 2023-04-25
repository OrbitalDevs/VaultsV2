// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./ISharedV2.sol";


interface IVaultFactoryV2 {
    // Events
    event AddNewVault(address newVaultAddress);

    // Functions
    function getCreationBlock() external view returns(uint256);
    function getVaultManagerAddress() external view returns(address);
    function getVaultInfoAddress() external view returns(address);
    function getAuxInfoAddress() external view returns(address);
    function getMaxTokensPerVault() external view returns(uint256);
    function setMaxTokensPerVault(uint256 maxTokensPerVaultIn) external;
    function getFeeOwner() external view returns (uint256);
    function setFeeOwner(uint256 feeOwnerIn) external;
    function getNumVaults() external view returns (uint256);
    function getVaultAddress(uint256 index) external view returns (address);
    function isVaultDeployed(address vaultAddress) external view returns (bool);
    function deploy(ISharedV2.vaultInfoDeploy memory params) external returns(address);
}

