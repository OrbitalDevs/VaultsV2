// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;


interface ISharedV2 {
    struct fees {
        uint256 owner;
        uint256 operator;
        uint256 users;
    }
    struct vaultInfoOut {
        string name;
        address operator;
        uint256 creationTime;
        address[] tokenList;
        fees feeRate;
        uint256[] balances;
        uint256 D;
        string strategy;
        bool isActive;
        bool autotradeActive;
        bool allowOtherUsers;
        uint256 oldestTradeTime;
    }
    struct vaultInfoDeploy {
        string name;
        address[] tokenList;
        uint256 feeOperator;
        uint256 feeUsers;
        bool allowOtherUsers; 
    }
    struct tradeInput { 
        address spendToken;
        address receiveToken;
        uint256 spendAmt;
        uint256 receiveAmtMin;
        address routerAddress;
        uint256 pathIndex;
    }
}