// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;



interface IChainlinkInterface {
    function owner() external view returns (address);
    function maxSlippageMillipercent() external view returns (address);
    function setSequencerUptimeFeed(address feedAddress) external;
    function getSequencerUptimeFeed() external view returns (address);
    function sequencerUptime() external view returns (uint256);

    event PriceFeedAdded(address token, address priceFeed, bool added);
    function addPriceFeed(address token, address priceFeed) external ;

    function removePriceFeed(address token) external;
    function getPriceFeed(address token) external view returns (address) ;
    function getPrice(address token) external view returns (int256 price, uint8 decimals);
    function getMinReceived(address tokenFrom, address tokenTo, uint256 amtIn, uint256 slippageMillipercent) external view returns (uint256);
}
