// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {MockERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockERC20.sol";
import {MockUniswapV2Router02} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";
import {MockUniswapV3Router} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";

import "../vaultV2.sol";
import "../Aux.sol";
import "../GasStation.sol";
import "../../interfaces/ISharedV2.sol";
import "../../interfaces/IV3SwapRouter.sol";


contract TestVaultManagerV2 is DSTest {
    Utilities internal utils;
    address payable[] internal users;
    address user1;
    address user2;
    address owner;

    MockERC20[10] tokens;

    VaultFactoryV2 vaultFactory;
    VaultManagerV2 vaultManager;
    GasStation gasStation;

    AuxInfo auxInfo;
    // RouterInfo routerInfo;
    
    uint256 creationBlock;
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(20);
        user1 = users[1];
        user2 = users[2];
        owner = users[11];

        for (uint i=0; i<10; i++){
            tokens[i] = new MockERC20("mockToken", "TK", 1000*10**18);
        }

        vm.startPrank(owner);
        vaultFactory = new VaultFactoryV2();

        auxInfo = AuxInfo(address(vaultFactory.getAuxInfoAddress()));
        vaultManager = VaultManagerV2(vaultFactory.getVaultManagerAddress());

        gasStation = GasStation(vaultManager.getGasStationAddress());

        auxInfo.allowToken(address(tokens[0]), 10000);
        auxInfo.allowToken(address(tokens[1]), 10000);

        creationBlock = block.number;
        vm.stopPrank();
    }

    function test_transferOwnership() public {
        vm.startPrank(owner);
        vaultManager.transferOwnership(user1);
        vm.stopPrank();
        assertEq(vaultManager.owner(), user1);
    }
    function test_RevertTransferOwnershipNotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.transferOwnership(user2);
        vm.stopPrank();
    }

    function test_setAndGetAutoTrader() public {
        address newAutoTrader = users[12];
        vm.startPrank(owner);
        vaultManager.setAutoTrader(newAutoTrader);
        assertEq(vaultManager.getAutoTrader(), newAutoTrader);
        vm.stopPrank();
    }
    function test_RevertNotOwnerSetAndGetAutoTrader() public {
        address newAutoTrader = users[12];
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.setAutoTrader(newAutoTrader);
        vm.stopPrank();
    }
    function test_setAndGetGasStationParam() public {
        uint256 newGasStationParam = 700_000;
        vm.startPrank(owner);
        vaultManager.setGasStationParam(newGasStationParam);
        assertEq(vaultManager.getGasStationParam(), newGasStationParam);
        vm.stopPrank();
    }

    function test_RevertNotOwnerSetGasStationParam() public {
        uint256 newGasStationParam = 700_000;
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.setGasStationParam(newGasStationParam);
        vm.stopPrank();
    }
    function test_setAndGetTrade5MinTime() public {
        uint256 newTrade5MinTime = 30 * 60; // 2 trades per hour max
        vm.startPrank(owner);
        vaultManager.setTrade5MinTime(newTrade5MinTime);
        assertEq(vaultManager.getTrade5MinTime(), newTrade5MinTime);
        vm.stopPrank();
    }

    function test_RevertNotOwnerSetTrade5MinTime() public {
        uint256 newTrade5MinTime = 30 * 60; // 2 trades per hour max
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.setTrade5MinTime(newTrade5MinTime);
        vm.stopPrank();
    }
    function test_setAndGetUseGasStation() public {
        bool newUseGasStation = true;
        vm.startPrank(owner);
        vaultManager.setUseGasStation(newUseGasStation);
        assertTrue(vaultManager.getUseGasStation() == newUseGasStation);
        vm.stopPrank();
    }

    function test_RevertNotOwnerSetUseGasStation() public {
        bool newUseGasStation = true;
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.setUseGasStation(newUseGasStation);
        vm.stopPrank();
    }
    function test_setAndGetOwnerFeesDest() public {
        address newOwnerFeesDest = users[13];
        vm.startPrank(owner);
        vaultManager.setOwnerFeesDest(newOwnerFeesDest);
        assertEq(vaultManager.getOwnerFeesDest(), newOwnerFeesDest);
        vm.stopPrank();
    }
    function test_RevertNotOwnerSetOwnerFeesDest() public {
        address newOwnerFeesDest = users[13];
        vm.startPrank(user1);
        vm.expectRevert();
        vaultManager.setOwnerFeesDest(newOwnerFeesDest);
        vm.stopPrank();
    }

}



