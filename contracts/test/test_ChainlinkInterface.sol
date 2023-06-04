// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../Auxil.sol";
import "../ChainlinkInterface.sol";
import "../mocks/MockAggregatorV3.sol";
import "../mocks/MockERC20.sol";
import "../lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";


contract TestChainlinkInterface is DSTest {
    ChainlinkInterface chainlinkInterface;
    // address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    address owner;

    address tokenUSDC; //usdc mock
    address tokenETH; //eth mock


    // These should ideally be mock contracts representing AggregatorV3Interface.
    MockAggregatorV3 token1Aggregator;
    MockAggregatorV3 token2Aggregator;

    MockERC20 usdcMock;
    MockERC20 ethMock;

    function setUp() public {
        owner = address(0x123);

        vm.startPrank(owner);

        usdcMock = new MockERC20("USDC", "USDC", 1_000_000, 6);
        ethMock = new MockERC20("ETH", "ETH", 1_000, 18);

        tokenUSDC = address(usdcMock);
        tokenETH = address(ethMock);

        chainlinkInterface = new ChainlinkInterface(owner);

        // Initializing Mock Aggregator contracts
        token1Aggregator = new MockAggregatorV3(8, 1*10**8);  // usdt
        token2Aggregator = new MockAggregatorV3(12, 2000*10**12); // eth

        // ERC20 huh = ERC20(tokenUSDC);
        // console.log("huh: ", huh.decimals());

        vm.stopPrank();
    }
    function testMockERC20s() public {
        assertEq(usdcMock.decimals(), 6);
        assertEq(ethMock.decimals(), 18);
        assertEq(usdcMock.totalSupply(), 1_000_000*10**6);
        assertEq(ethMock.totalSupply(), 1_000*10**18);
    }
    function testAddPriceFeed() public {
        vm.startPrank(owner);
        chainlinkInterface.addPriceFeed(tokenUSDC, address(token1Aggregator));
        vm.stopPrank();

        assertEq(chainlinkInterface.aggregatorAddresses(tokenUSDC), address(token1Aggregator));
    }

    function testRemovePriceFeed() public {
        vm.startPrank(owner);
        chainlinkInterface.addPriceFeed(tokenETH, address(token2Aggregator));
        chainlinkInterface.removePriceFeed(tokenETH);
        vm.stopPrank();

        assertEq(chainlinkInterface.aggregatorAddresses(tokenETH), address(0));
    }

    function testGetPrice() public {
        vm.startPrank(owner);
        chainlinkInterface.addPriceFeed(tokenUSDC, address(token1Aggregator));
        vm.stopPrank();

        (int256 price, uint8 decimals) = chainlinkInterface.getPrice(tokenUSDC);
        assertEq(int(price), 1*10**8);
        assertEq(uint(decimals), 8);
    }

    function testGetMinReceived() public {
        vm.startPrank(owner);
        chainlinkInterface.addPriceFeed(tokenUSDC, address(token1Aggregator));
        chainlinkInterface.addPriceFeed(tokenETH, address(token2Aggregator));
        vm.stopPrank();

        uint256 slippage = 100;

        address tokenFrom = tokenETH;
        address tokenTo = tokenUSDC;

        uint256 minReceived = chainlinkInterface.getMinReceived(tokenFrom, tokenTo, 1*10**18, slippage); //trade 1 eth for usdc
        console.log("minReceived: ", minReceived);
        // assertEq(minReceived, 1);
        assertEq(minReceived, (2000*10**6 * (100_000 - slippage)/100_000)); // As per your logic
    }
}


