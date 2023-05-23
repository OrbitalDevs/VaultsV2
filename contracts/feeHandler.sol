// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/SafeERC20.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";

import "../interfaces/IV3SwapRouter.sol";
import "../interfaces/IUniswapV2Router02.sol";


import "./functions.sol";
import "./reentrancyGuard.sol";
import "./Auxil.sol";

import "./Token.sol";


contract FeeHandler is Ownable, ReentrancyGuarded {
    using SafeERC20 for IERC20;

    struct buybackInfo {
        address token;
        address routerAddress;
        uint256 pathIndex;
        uint256 minReceived;
    }

    AuxInfo private immutable auxInfo;
    address private orbitalTokenAddress;
    uint256 private buybackPercent = 25; 


    constructor(address orbitalTokenAddressIn, address AuxInfoAddress) {
        transferOwnership(msg.sender);
        orbitalTokenAddress = orbitalTokenAddressIn;
        auxInfo = AuxInfo(AuxInfoAddress);
    }

    function getorbitalTokenAddress() external view returns(address){
        return orbitalTokenAddress;
    }

    function getBuybackPercent() external view returns(uint256){
        return buybackPercent;
    }

    // function setBuybackPercent(uint256 buybackPercentIn) external nonReentrant onlyOwner {
    //     require(buybackPercentIn <= 100, "> 100");
    //     buybackPercent = buybackPercentIn;
    // }

    function withdraw(buybackInfo[] calldata buybackList) external nonReentrant onlyOwner returns(uint256[] memory recAmounts, uint256 amtBurned){
        recAmounts = new uint256[](buybackList.length);
        uint256 orbitalReceivedTotal = 0;
        for (uint i =0; i < buybackList.length; i++) {
            buybackInfo memory info = buybackList[i];
            // require(info.token != orbitalTokenAddress, "cannot withdraw orbital token");
            
            IERC20 token = IERC20(info.token);
            uint256 balance = token.balanceOf(address(this));
            
            if (balance > 0){
                uint256 buybackAmount = (buybackPercent*balance)/100;
                uint256 ownerFeeAmt = balance - buybackAmount;
                if (buybackAmount > 0 && info.token != orbitalTokenAddress) { //do not swap Orbital with itself
                    require(auxInfo.isRouterAllowed(info.routerAddress), "router not allowed");
                    RouterInfo RI = RouterInfo(info.routerAddress);

                    uint256 routerType = RI.getRouterType();

                    bytes memory pathMiddle = RI.getAllowedPath(info.token, orbitalTokenAddress, info.pathIndex);
                    bytes memory path = abi.encodePacked(info.token, pathMiddle, orbitalTokenAddress);

                    uint256 recAmt;
                    if (routerType == 0) { //Uniswap V2 type router
                        address[] memory pathArray = functions.decodeAddresses(path);
                        IUniswapV2Router02 router = IUniswapV2Router02(info.routerAddress);
                        uint256[] memory recAmountsTemp;
                        recAmountsTemp = router.swapExactTokensForTokens(buybackAmount, 
                                                                     info.minReceived, 
                                                                     pathArray, 
                                                                     address(this), 
                                                                     block.timestamp);
                        // recAmt = recAmounts[recAmounts.length - 1];
                        // orbitalReceivedTotal += recAmt;
                        orbitalReceivedTotal += recAmountsTemp[recAmountsTemp.length - 1];
                    } else { //V3 type router
                        IV3SwapRouter.ExactInputParams memory params = 
                            IV3SwapRouter.ExactInputParams({
                                path: path,
                                recipient: address(this),
                                amountIn: buybackAmount,
                                amountOutMinimum: info.minReceived
                            });
                        IV3SwapRouter router = IV3SwapRouter(info.routerAddress);
                        recAmt = router.exactInput(params);
                        orbitalReceivedTotal += recAmt;
                    }
                    recAmounts[i] = recAmt;
                }
                if (ownerFeeAmt > 0) {
                    token.safeTransfer(msg.sender, ownerFeeAmt);
                }
            }
        }
        
        if (orbitalReceivedTotal > 0) {
            Orbital orbital = Orbital(orbitalTokenAddress);
            orbital.burn(orbitalReceivedTotal);
            amtBurned = orbitalReceivedTotal;
        }
        // Orbital orbital = Orbital(orbitalTokenAddress);
        // uint256 orbitalBalance = orbital.balanceOf(address(this));
        // amtBurned = orbitalBalance;
        // if (amtBurned > 0)
        //     orbital.burn(amtBurned);
    }
}