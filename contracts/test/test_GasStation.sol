// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

// import "../vaultV2.sol";
// import "../Aux.sol";
import "../GasStation.sol";



contract TestGasStation is DSTest {
    Utilities internal utils;
    address payable[] internal users;
    address user1;
    address user2;
    address owner;

    GasStation gasStation;

    
    uint256 creationBlock;
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(20);
        user1 = users[1];
        user2 = users[2];
        owner = users[11];

        vm.startPrank(owner);
        gasStation = new GasStation();
        vm.stopPrank();
    }

    function test_gasStationTransferOwnership() public {
        vm.startPrank(owner);
        gasStation.transferOwnership(user1);
        vm.stopPrank();
        assertEq(gasStation.owner(), user1);
    }

    function test_gasStationRevertTransferOwnershipNotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        gasStation.transferOwnership(user2);
        vm.stopPrank();
    }

    function test_gasStationOwner() public {
        assertEq(gasStation.owner(), owner);
    }

    function test_gasStationDeposit() public {
        uint256 depositAmount = 1 ether;
        vm.startPrank(user1);
        gasStation.deposit{value: depositAmount}();
        vm.stopPrank();
        uint256 userGasBalance = gasStation.balanceOf(user1);
        assertEq(userGasBalance, depositAmount);
    }
    function test_gasStationWithdraw() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 5*10**17; // 0.5 ether
        vm.startPrank(user1);
        gasStation.deposit{value: depositAmount}();
        gasStation.withdraw(withdrawAmount);
        vm.stopPrank();
        uint256 userGasBalance = gasStation.balanceOf(user1);
        assertEq(userGasBalance, depositAmount - withdrawAmount);
    }
    function test_RevertInsufficientGasBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;
        vm.startPrank(user1);
        gasStation.deposit{value: depositAmount}();
        vm.expectRevert();
        gasStation.withdraw(withdrawAmount);
        vm.stopPrank();
    }
    function test_removeGas() public {
        uint256 depositAmount = 1 ether;
        uint256 removeAmount = 5*10**17; // 0.5 ether
        vm.startPrank(user1);
        gasStation.deposit{value: depositAmount}();
        vm.stopPrank();

        vm.startPrank(owner);
        gasStation.removeGas(removeAmount, payable(user1), user1);
        vm.stopPrank();

        uint256 userGasBalance = gasStation.balanceOf(user1);
        assertEq(userGasBalance, depositAmount - removeAmount);
    }
    function test_RevertNotOwnerRemoveGas() public {
        uint256 depositAmount = 1 ether;
        uint256 removeAmount = 5*10**17; // 0.5 ether
        vm.startPrank(user1);
        gasStation.deposit{value: depositAmount}();
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert();
        gasStation.removeGas(removeAmount, payable(user1), user1);
        vm.stopPrank();
    }
}


// contract MaliciousContract {
//     VaultFactoryV2 public vaultFactory;
//     address payable[] internal users;
//     AuxInfo auxInfo;

//     constructor(VaultFactoryV2 _vaultFactory, address payable[] memory _users, AuxInfo _auxInfo) {
//         vaultFactory = _vaultFactory;
//         users = _users;
//         auxInfo = _auxInfo;
//     }

//     function attack() external {
//         address[] memory allowedTokens = auxInfo.getAllowedTokens();

//         require(allowedTokens.length >= 2, "Insufficient allowed tokens");

//         ISharedV2.vaultInfoDeploy memory params;
//         params.name = "Malicious Vault";
//         params.tokenList = new address[](2);
//         params.tokenList[0] = allowedTokens[0];
//         params.tokenList[1] = allowedTokens[1];
//         params.feeOperator = 1000; // 1%
//         params.feeUsers = 1000; // 1%
//         params.allowOtherUsers = true;
//         console.log("guardCounter: %s", vaultFactory.readGuardCounter());
//         vaultFactory.deploy(params);
//         console.log("guardCounter: %s", vaultFactory.readGuardCounter());
//         // Attempting to call deploy() again within the same transaction
//         vaultFactory.deploy(params);
//         console.log("guardCounter: %s", vaultFactory.readGuardCounter());
//     }
// }

