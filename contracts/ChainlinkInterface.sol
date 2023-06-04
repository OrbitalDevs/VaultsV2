// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";

import "./functions.sol";
import "../interfaces/IAggregatorV3.sol";


contract ChainlinkInterface is Ownable {
    mapping(address => address) public aggregatorAddresses; //mapping from token to USD price feed address

    uint256 public constant maxSlippageMillipercent = 10_000; //10% slippage absolute max

    constructor(address ownerIn) {
        transferOwnership(ownerIn);
    }

    event PriceFeedAdded(address token, address priceFeed, bool added);
    function addPriceFeed(address token, address priceFeed) external onlyOwner {
        // require(aggregatorAddresses[token] == address(0), "price feed exists");
        aggregatorAddresses[token] = priceFeed;
        emit PriceFeedAdded(token, priceFeed, true);
    }

    function removePriceFeed(address token) external onlyOwner {
        aggregatorAddresses[token] = address(0);
        emit PriceFeedAdded(token, address(0), false);
    }

    function getPrice(address token) external view returns (int256 price, uint8 decimals) {
        address priceFeedAddress = aggregatorAddresses[token];
        require(priceFeedAddress != address(0), "price feed does not exist");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        
        (,price,,,) = priceFeed.latestRoundData();
        decimals = priceFeed.decimals();
        // return uint256(price);
    }

    function getMinReceived(address tokenFrom, address tokenTo, uint256 amtIn, uint256 slippageMillipercent) external view returns (uint256) {
        require(slippageMillipercent <= maxSlippageMillipercent, "slippage too high");
        address aggFrom = aggregatorAddresses[tokenFrom];
        address aggTo = aggregatorAddresses[tokenTo];
        require(aggFrom != address(0), "no feed");
        require(aggTo != address(0), "no feed");

        AggregatorV3Interface AIFrom = AggregatorV3Interface(aggFrom);
        AggregatorV3Interface AITo = AggregatorV3Interface(aggTo);


        (,int priceFromInt,,,) = AIFrom.latestRoundData();
        (,int priceToInt,,,) = AITo.latestRoundData();

        //technically, oracles allow for negative prices, but we should never see that.
        require(priceFromInt > 0 && priceToInt > 0, "price feed error");

        //formula: amtReceived = amtIn * (priceFrom * 10**tokenToDecimals) / (priceTo * 10**tokenFromDecimals)
        uint256 nExp =  ERC20(tokenTo).decimals() + AITo.decimals();
        uint256 dExp = ERC20(tokenFrom).decimals() + AIFrom.decimals();
        
        //reduce the fraction to avoid overflow
        if (nExp > dExp) {
            nExp = nExp - dExp;
            dExp = 0;
        } else {
            dExp = dExp - nExp;
            nExp = 0;
        }

        uint256 amtReceivedNominal = (amtIn * uint256(priceFromInt) * 10**nExp)/(uint256(priceToInt) * 10**dExp);
        return (amtReceivedNominal * (100_000 - slippageMillipercent)) / 100_000;
    }
}
