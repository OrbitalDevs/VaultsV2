// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;


interface IShared {
    struct pair {
        address token0;
        address token1;
    }
    struct pairAmts {
        uint256 amt0;
        uint256 amt1;
    }
    struct tokenParams {
        uint256 minDepositAmt;
        uint256 initialDenominator;
    }
    struct fees {
        uint256 owner;
        uint256 operator;
        uint256 users;
    }
    struct vaultInfo {
        string name;
        address operator;
        uint256 creationTime;
        address routerAddress;
        address token0;
        address token1;
        fees feeRate;
        uint256 T0;
        uint256 T1;
        uint256 D;
        string strategy;
        bool isActive;
        bool autotradeActive;
        bool allowOtherUsers;
        uint256[5] lastTradeTimes;
    }
    struct vaultInfoDeploy {
        string name;
        address token0;
        address token1;
        uint256 feeOperator;
        uint256 feeUsers;
        string strategy;
        bool allowOtherUsers;    
    }
    struct tradeInput { //address vaultAddress, uint256 spendTokenNumber, uint256 spendAmt, uint256 receiveAmtMin, uint24 fee
        address vaultAddress;
        uint256 spendTokenNumber;
        uint256 spendAmt;
        uint256 receiveAmtMin;
        uint256 pathIndex;
        uint256 routerIndex;
    }
}