// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./ISharedV2.sol";


interface IVaultManagerV2 {
    function getAutoTrader() external view returns (address);
    function setAutoTrader(address autoTraderIn) external;
    function getGasStationParam() external view returns (uint256);
    function setGasStationParam(uint256 gasStationParamIn) external;
    function getTrade5MinTime() external view returns (uint256);
    function setTrade5MinTime(uint256 trade5MinTimeIn) external;
    function getUseGasStation() external view returns (bool);
    function setUseGasStation(bool useGasStationIn) external;
    function getCreationBlock() external view returns (uint256);
    function getGasStationAddress() external view returns (address);
    function getOwnerFeesDest() external view returns (address);
    function setOwnerFeesDest(address newOwnerFeesDest) external;

    event Deposit(address vaultAddress, address user, uint256[] amts);
    function deposit(address vaultAddress, uint256[] memory amts) external;

    event Withdraw(address vaultAddress, address user, 
                   uint256[] balancesBefore, 
                   uint256 deltaN, 
                   ISharedV2.fees deltaNFees, 
                   uint256 DBefore);
    function withdraw(address vaultAddress, uint256 percentage) external;

    event Trade(address spendToken, 
                address receiveToken,
                uint256 spendTokenTotalBefore, 
                uint256 receiveTokenTotalBefore, 
                uint256 spendAmt, 
                uint256 receiveAmt);
    function trade(address vaultAddress, ISharedV2.tradeInput memory params) external returns (uint256 receiveAmt);
}


// interface IVaultManagerV2 {
//     function name() external pure returns(string memory);
//     function getAutoTrader() external view returns (address);
//     function setAutoTrader(address autoTraderIn) external;
//     function getGasStationParam() external view returns (uint256);
//     function setGasStationParam(uint256 gasStationParamIn) external;
//     function getTrade5MinTime() external view returns (uint256);
//     function setTrade5MinTime(uint256 trade5MinTimeIn) external ;
//     function getOldestTradeTime(address vaultAddress) external view returns (uint256);
//     function getUseGasStation() external view returns (bool);
//     function setUseGasStation(bool useGasStationIn) external;
//     function getCreationBlock() external view returns (uint256);
//     function getFactoryAddress() external view returns (address);
//     function getGasStationAddress() external view returns (address);
//     function getOwnerFeesDest() external view returns (address);
//     function setOwnerFeesDest(address newOwnerFeesDest) external;
//     function deactivate(address vaultAddress) external;
//     function setAllowOtherUsers(address vaultAddress, bool allow) external;
//     function setStrategy(address vaultAddress, string calldata stratString) external;
//     function setStrategyAndActivate(address vaultAddress, string calldata stratString, bool activate) external;
//     function setAutotrade(address vaultAddress, bool status) external;
//     function getFundTokens(address vaultAddress) external view returns (address[] memory);
//     function getFundBalances(address vaultAddress) external view returns (uint256[] memory);
//     function setOperator(address vaultAddress, address operator) external;
//     // function getVaultInfo(address vaultAddress) external view returns (ISharedV2.vaultInfoOut memory);
//     //needed for debugging only
//     function getNumerator(address vaultAddress, address user) external view returns (uint256);
//     // function getUserBalances(address vaultAddress, address user) external view returns (uint256[] memory);   
//     function deposit(address vaultAddress, uint256[] memory amts) external;
//     function withdraw(address vaultAddress, uint256 percentage) external;
//     function trade(address vaultAddress, ISharedV2.tradeInput memory params) external returns (uint256 receiveAmt);
//     function sweepSelf(address tokenAddress) external;
    
// }
