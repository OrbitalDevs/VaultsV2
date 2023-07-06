// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";

import "./functions.sol";
import "../interfaces/IAggregatorV3.sol";



contract ChainlinkInterface is Ownable {
    mapping(address => address) private aggregatorAddresses; //mapping from token to USD price feed address

    AggregatorV2V3Interface private sequencerUptimeFeed;
    uint256 private immutable GRACE_PERIOD_TIME; // 3600 recommended (1 hour)

    uint256 public immutable maxSlippageMillipercent; //10% recommended

    constructor(uint256 maxSlippageMillipercentIn, uint256 gracePeriodTimeIn) {
        // transferOwnership(ownerIn);
        maxSlippageMillipercent = maxSlippageMillipercentIn;
        GRACE_PERIOD_TIME = gracePeriodTimeIn;
    }

    function setSequencerUptimeFeed(address feedAddress) external onlyOwner {
        sequencerUptimeFeed = AggregatorV2V3Interface(feedAddress);
    }

    function getSequencerUptimeFeed() external view returns (address) {
        return address(sequencerUptimeFeed);
    }

    function sequencerUptime() public view returns (uint256) {
        if (address(sequencerUptimeFeed) == address(0)) { //for networks that don't have a sequencer uptime feed
            return type(uint256).max;
        }
        (,int256 answer, uint startedAt,,) = sequencerUptimeFeed.latestRoundData();
        if (answer != 0) { //sequencer is down
            return 0;
        }

        uint256 timeSinceUp = block.timestamp - startedAt;
        return timeSinceUp;
        // return timeSinceUp >= GRACE_PERIOD_TIME;
    }

    event PriceFeedAdded(address token, address priceFeed, bool added);
    function addPriceFeed(address token, address priceFeed) external onlyOwner {
        aggregatorAddresses[token] = priceFeed;
        emit PriceFeedAdded(token, priceFeed, true);
    }

    function removePriceFeed(address token) external onlyOwner {
        aggregatorAddresses[token] = address(0);
        emit PriceFeedAdded(token, address(0), false);
    }

    function getPriceFeed(address token) external view returns (address) {
        return aggregatorAddresses[token];
    }

    function getPrice(address token) external view returns (int256 price, uint8 decimals) {
        address priceFeedAddress = aggregatorAddresses[token];
        require(priceFeedAddress != address(0), "price feed does not exist");
        require(sequencerUptime() > GRACE_PERIOD_TIME, "sequencer is down");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        
        (,price,,,) = priceFeed.latestRoundData();
        decimals = priceFeed.decimals();
        // return uint256(price);
    }

    function getMinReceived(address tokenFrom, address tokenTo, uint256 amtIn, uint256 slippageMillipercent) external view returns (uint256) {
        require(sequencerUptime() > GRACE_PERIOD_TIME, "sequencer is down");
        require(slippageMillipercent <= maxSlippageMillipercent, "slippage too high");

        require(aggregatorAddresses[tokenFrom] != address(0), "no feed");
        require(aggregatorAddresses[tokenTo] != address(0), "no feed");

        AggregatorV3Interface AIFrom = AggregatorV3Interface(aggregatorAddresses[tokenFrom]);
        AggregatorV3Interface AITo = AggregatorV3Interface(aggregatorAddresses[tokenTo]);

        uint80 roundID;
        uint80 answeredInRound;
        int priceFromInt;
        int priceToInt;

        (roundID, priceFromInt,,, answeredInRound) = AIFrom.latestRoundData();
        require(answeredInRound == roundID, "priceFrom stale");

        (roundID, priceToInt,,, answeredInRound) = AITo.latestRoundData();
        require(answeredInRound == roundID, "priceTo stale");

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

        // return ((amtIn * uint256(priceFromInt) * 10**nExp)/(uint256(priceToInt) * 10**dExp) * (100_000 - slippageMillipercent)) / 100_000;
    }
}
