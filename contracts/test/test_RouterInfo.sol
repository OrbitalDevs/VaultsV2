// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../Auxil.sol";

contract TestRouterInfo is DSTest {
    RouterInfo routerInfo;
    Utilities internal utils;

    // Variables for constructor
    // address ownerIn = address(this);
    string name = "MyRouter";
    address routerAddress = address(0x123);
    uint256 routerType = 0;
    address payable[] internal users;
    address user1;
    address user2;
    address owner;
    bytes32 internal constant INIT_HASH =   
        0xc38721b5250eca0e6e24e742a913819babbc8948f0098b931b3f53ea7b3d8967;
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(20);
        user1 = users[1];
        user2 = users[2];
        owner = users[11];
        // vm.prank(owner);
        routerInfo = new RouterInfo(owner, name, routerAddress, routerType);
    }

    function testTransferOwnership() public {
        vm.prank(owner);
        routerInfo.transferOwnership(user1);
        vm.stopPrank();
        assertEq(routerInfo.owner(), user1);
    }

    function testRevertTransferOwnershipNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        routerInfo.transferOwnership(user2);
        vm.stopPrank();
    }

    function testGetName() public {
        string memory contractName = routerInfo.getName();
        console.log("contractName: %s", contractName);
        assertEq(contractName, name);
    }

    function testGetRouterAddress() public {
        address contractRouterAddress = routerInfo.getRouterAddress();
        assertEq(contractRouterAddress, routerAddress);
    }

    function testGetRouterType() public {
        uint256 contractRouterType = routerInfo.getRouterType();
        assertEq(contractRouterType, routerType);
    }

    function testGetInfo() public {
        (string memory contractName, address contractRouterAddress, uint256 contractRouterType) = routerInfo.getInfo();
        assertEq(contractName, name);
        assertEq(contractRouterAddress, routerAddress);
        assertEq(contractRouterType, routerType);
    }

    function testAllowPath() public {
        address token0 = address(0x1);
        address token1 = address(0x2);
        bytes memory path = hex"010203";

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, path);
        vm.stopPrank();

        bytes memory contractPath = routerInfo.getAllowedPath(token0, token1, 0);
        assertEq0(contractPath, path);

        bool allowed = routerInfo.isPairAllowed(token0, token1);
        assertTrue(allowed);
    }
    function testRevertAllowPathNotOwner() public {
        address token0 = address(0x1);
        address token1 = address(0x2);

        bytes memory path = abi.encodePacked(token0, token1);

        vm.prank(user1);
        vm.expectRevert();
        routerInfo.allowPath(token0, token1, path);
        vm.stopPrank();
    }
    function testDisallowPath() public {
        address token0 = address(0x1);
        address token1 = address(0x2);
        bytes memory path = hex"010203";
        uint256 pathIndex = 0;

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, path);
        vm.prank(owner);
        routerInfo.disallowPath(token0, token1, pathIndex);
        vm.stopPrank();

        bool allowed = routerInfo.isPairAllowed(token0, token1);
        assertTrue(!allowed);
    }
    function testRevertDisallowPathNotOwner() public {
        address token0 = address(0x1);
        address token1 = address(0x2);

        // First, allow a path as the owner
        bytes memory path = abi.encodePacked(token0, token1);
        vm.prank(owner);
        routerInfo.allowPath(token0, token1, path);
        vm.stopPrank();

        // Then, try to disallow the path as a non-owner
        vm.prank(user1);
        vm.expectRevert();
        routerInfo.disallowPath(token0, token1, 0);
        vm.stopPrank();
    }


    function testGetNumAllowedPairs() public {
        address token0 = address(0x1);
        address token1 = address(0x2);
        address token2 = address(0x3);

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, hex"010203");
        uint256 numAllowedPairs1 = routerInfo.getNumAllowedPairs();
        assertEq(numAllowedPairs1, 1);

        vm.prank(owner);
        routerInfo.allowPath(token0, token2, hex"010204");
        uint256 numAllowedPairs2 = routerInfo.getNumAllowedPairs();
        assertEq(numAllowedPairs2, 2);

        vm.prank(owner);
        routerInfo.disallowPath(token0, token1, 0);
        uint256 numAllowedPairs3 = routerInfo.getNumAllowedPairs();
        assertEq(numAllowedPairs3, 1);
    }
    function testGetAllowedPair() public {
        address token0 = address(0x1);
        address token1 = address(0x2);

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, hex"010203");
        RouterInfo.pair memory allowedPair = routerInfo.getAllowedPair(0);

        assertEq(allowedPair.token0, token0);
        assertEq(allowedPair.token1, token1);
        assertEq(allowedPair.numPathsAllowed, 1);
    }
    function testGetNumAllowedPaths() public {
        address token0 = address(0x1);
        address token1 = address(0x2);

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, hex"010203");
        uint256 numAllowedPaths1 = routerInfo.getNumAllowedPaths(token0, token1);
        assertEq(numAllowedPaths1, 1);

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, hex"020304");
        uint256 numAllowedPaths2 = routerInfo.getNumAllowedPaths(token0, token1);
        assertEq(numAllowedPaths2, 2);

        vm.prank(owner);
        routerInfo.disallowPath(token0, token1, 0);
        uint256 numAllowedPaths3 = routerInfo.getNumAllowedPaths(token0, token1);
        assertEq(numAllowedPaths3, 1);
    }
    function testGetAllowedPath() public {
        address token0 = address(0x1);
        address token1 = address(0x2);
        bytes memory path1 = hex"010203";
        bytes memory path2 = hex"020304";

        vm.prank(owner);
        routerInfo.allowPath(token0, token1, path1);
        vm.prank(owner);
        routerInfo.allowPath(token0, token1, path2);

        bytes memory allowedPath1 = routerInfo.getAllowedPath(token0, token1, 0);
        bytes memory allowedPath2 = routerInfo.getAllowedPath(token0, token1, 1);

        assertEq0(allowedPath1, path1);
        assertEq0(allowedPath2, path2);
    }


}