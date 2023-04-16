// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;


import "./IShared.sol";


interface IVaultManager {
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function name() external pure returns (string memory);
    function getTrade5MinTime() external view returns (uint256);
    function setTrade5MinTime(uint256 trade5MinTimeIn) external;
    function getOldestTradeTime(address vaultAddress) external view returns (uint256);
    function getUseGasStation() external view returns (bool);
    function setUseGasStation(bool useGasStationIn) external;
    function getGasStationParam() external view returns (uint256);
    function setGasStationParam(uint256 gasStationExtraIn) external;
    function getCreationBlock() external view returns (uint256);
    function getFactoryAddress() external view returns (address);
    function getGasStationAddress() external view returns (address);
    function getOwnerFeesDest() external view returns (address);
    function setOwnerFeesDest(address newOwnerFeesDest) external;
    function getFundTokens(address vaultAddress) external view returns (address, address);
    function deactivate(address vaultAddress) external;
    function setAllowOtherUsers(address vaultAddress, bool allow) external;
    function setStrategy(address vaultAddress, string calldata stratString) external;
    function setStrategyAndActivate(address vaultAddress, string calldata stratString, bool activate) external;
    function setAutotrade(address vaultAddress, bool status) external;
    function setOperator(address vaultAddress, address operator) external;
    function getFundBalances(address vaultAddress) external view returns (uint256, uint256);
    function getVaultInfo(address vaultAddress) external view returns (IShared.vaultInfo memory);
    function getNumerator(address vaultAddress, address user) external view returns (uint256);
    function getBalances(address vaultAddress, address user) external view returns (uint256, uint256);
    function addNewVault(IShared.vaultInfo calldata vaultInfoIn, address vaultAddress) external;
    function deposit(address vaultAddress, uint256 amount0, uint256 amount1) external;
    function withdraw(address vaultAddress, uint256 percentage) external;
    function trade(IShared.tradeInput memory params) external returns (uint256 receiveAmt);
    function sweepVault(address vaultAddress) external;
    function sweepSelf(address tokenAddress) external;
}
