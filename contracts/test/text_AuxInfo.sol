// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../Aux.sol";

contract TestAuxInfo is DSTest {
    AuxInfo auxInfo;
    address owner;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        owner = address(this);
        auxInfo = new AuxInfo(owner);
    }

    function testInitialState() public {
        assertEq(auxInfo.getNumAllowedTokens(), 0);
        assertEq(auxInfo.getNumAllowedRouters(), 0);
        address token = address(0x1);
        address router = address(0x3);
        assertTrue(!auxInfo.isTokenAllowed(token));
        assertTrue(!auxInfo.isRouterAllowed(router));
    }
    function testTransferOwnership() public {
        address user = address(0x2);
        auxInfo.transferOwnership(user);
        assertEq(auxInfo.owner(), user);
    }

    function testFailTransferOwnershipNotOwner() public {
        address user = address(0x2);
        vm.prank(user);
        auxInfo.transferOwnership(user);
        vm.stopPrank();
    }

    function testInitialOwner() public {
        assertEq(auxInfo.owner(), owner);
    }
    function testAllowDisallowToken() public {
        address token = address(0x1);
        uint256 initialDenominator = 10;

        auxInfo.allowToken(token, initialDenominator);
        AuxInfo.tokenInfo memory allowedToken = auxInfo.getAllowedTokenInfo(token);

        assertTrue(allowedToken.allowed);
        // assertEq(allowedToken.minDepositAmt, minDepAmt);
        assertEq(allowedToken.initialDenominator, initialDenominator);

        auxInfo.disallowToken(token);
        AuxInfo.tokenInfo memory disallowedToken = auxInfo.getAllowedTokenInfo(token);

        assertTrue(!disallowedToken.allowed);
    }

    function testAllowToken() public {
        address token = address(0x1);
        uint256 initialDenominator = 10;

        auxInfo.allowToken(token, initialDenominator);
        AuxInfo.tokenInfo memory allowedToken = auxInfo.getAllowedTokenInfo(token);

        assertTrue(allowedToken.allowed);
        // assertEq(allowedToken.minDepositAmt, minDepAmt);
        assertEq(allowedToken.initialDenominator, initialDenominator);
    }
    function testFailAllowTokenNotOwner() public {
        address user = address(0x2);
        address token = address(0x1);
        uint256 initialDenominator = 10;

        vm.prank(user);
        auxInfo.allowToken(token, initialDenominator);
        vm.stopPrank();
    }
    function testDisallowToken() public {
        address token = address(0x1);
        uint256 initialDenominator = 10;

        auxInfo.allowToken(token,initialDenominator);
        auxInfo.disallowToken(token);

        bool isAllowed = auxInfo.isTokenAllowed(token);
        assertTrue(!isAllowed);
    }

    function testFailDisallowTokenNotOwner() public {
        address token = address(0x1);
        uint256 initialDenominator = 10;
        address user = address(0x2);

        auxInfo.allowToken(token, initialDenominator);

        vm.prank(user);
        auxInfo.disallowToken(token);
        vm.stopPrank();
    }
    function testAllowRouter() public {
        address routerAddress = address(0x3);
        string memory routerName = "TestRouter";
        uint256 routerType = 1;

        auxInfo.allowRouter(routerAddress, routerName, routerType);
        AuxInfo.routerInfo memory allowedRouter = auxInfo.getRouterInfo(routerAddress);

        assertTrue(allowedRouter.allowed);
        assertEq(allowedRouter.routerInfoContractAddress, address(allowedRouter.routerInfoContractAddress));
    }
    function testFailAllowRouterNotOwner() public {
        address user = address(0x2);
        address router = address(0x3);
        string memory routerName = "Router";
        uint256 routerType = 0;

        vm.prank(user);
        auxInfo.allowRouter(router, routerName, routerType);
        vm.stopPrank();
    }
    function testDisallowRouter() public {
        address routerAddress = address(0x3);
        string memory routerName = "TestRouter";
        uint256 routerType = 1;

        auxInfo.allowRouter(routerAddress, routerName, routerType);
        auxInfo.disallowRouter(routerAddress);

        bool isAllowed = auxInfo.isRouterAllowed(routerAddress);
        assertTrue(!isAllowed);
    }
    function testFailDisallowRouterNotOwner() public {
        address router = address(0x3);
        string memory routerName = "Router";
        uint256 routerType = 0;
        address user = address(0x2);

        auxInfo.allowRouter(router, routerName, routerType);

        vm.prank(user);
        auxInfo.disallowRouter(router);
        vm.stopPrank();
    }
    function testAreTokensAllowed() public {
        address token1 = address(0x1);
        uint256 initialDenominator1 = 10;

        address token2 = address(0x2);

        uint256 initialDenominator2 = 20;

        auxInfo.allowToken(token1, initialDenominator1);
        auxInfo.allowToken(token2, initialDenominator2);

        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        bool result = auxInfo.areTokensAllowed(tokens);
        assertTrue(result);
    }
    function testAreTokensNotAllowed() public {
        address token1 = address(0x1);

        uint256 initialDenominator1 = 10;

        address token2 = address(0x2);
        uint256 initialDenominator2 = 20;

        address token3 = address(0x3);

        auxInfo.allowToken(token1, initialDenominator1);
        auxInfo.allowToken(token2, initialDenominator2);

        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = token2;
        tokens[2] = token3;

        bool result = auxInfo.areTokensAllowed(tokens);
        assertTrue(!result);
    }
    function testGetNumAllowedRouters() public {
        address routerAddress1 = address(0x4);
        string memory routerName1 = "TestRouter1";
        uint256 routerType1 = 0;

        address routerAddress2 = address(0x5);
        string memory routerName2 = "TestRouter2";
        uint256 routerType2 = 1;

        auxInfo.allowRouter(routerAddress1, routerName1, routerType1);
        auxInfo.allowRouter(routerAddress2, routerName2, routerType2);

        uint256 numAllowedRouters = auxInfo.getNumAllowedRouters();
        assertEq(numAllowedRouters, 2);
    }
    function testGetAllowedRouter() public {
        address routerAddress1 = address(0x4);
        string memory routerName1 = "TestRouter1";
        uint256 routerType1 = 0;

        address routerAddress2 = address(0x5);
        string memory routerName2 = "TestRouter2";
        uint256 routerType2 = 1;

        auxInfo.allowRouter(routerAddress1, routerName1, routerType1);
        auxInfo.allowRouter(routerAddress2, routerName2, routerType2);

        address allowedRouter1 = auxInfo.getAllowedRouter(0);
        address allowedRouter2 = auxInfo.getAllowedRouter(1);

        assertEq(allowedRouter1, routerAddress1);
        assertEq(allowedRouter2, routerAddress2);
    }
    function testSetAllowedTokenInfo() public {
        address token = address(0x1);

        uint256 initialDenominator = 10;

        uint256 newInitialDenominator = 20;

        auxInfo.allowToken(token, initialDenominator);
        auxInfo.setAllowedTokenInfo(token,  newInitialDenominator);

        AuxInfo.tokenInfo memory updatedToken = auxInfo.getAllowedTokenInfo(token);

        assertTrue(updatedToken.allowed);
        // assertEq(updatedToken.minDepositAmt, newMinDepAmt);
        assertEq(updatedToken.initialDenominator, newInitialDenominator);
    }

    function testFailSetAllowedTokenInfoNotOwner() public {
        address token = address(0x1);

        uint256 initialDenominator = 10;

        uint256 newInitialDenominator = 20;
        address user = address(0x2);

        auxInfo.allowToken(token, initialDenominator);

        vm.prank(user);
        auxInfo.setAllowedTokenInfo(token, newInitialDenominator);
        vm.stopPrank();
    }

    function testGetNumAllowedTokens() public {
        address token1 = address(0x1);
        address token2 = address(0x2);

        uint256 initialDenominator1 = 10;
        uint256 initialDenominator2 = 15;

        assertEq(auxInfo.getNumAllowedTokens(), 0);

        auxInfo.allowToken(token1, initialDenominator1);
        assertEq(auxInfo.getNumAllowedTokens(), 1);

        auxInfo.allowToken(token2, initialDenominator2);
        assertEq(auxInfo.getNumAllowedTokens(), 2);

        auxInfo.disallowToken(token1);
        assertEq(auxInfo.getNumAllowedTokens(), 1);

        auxInfo.disallowToken(token2);
        assertEq(auxInfo.getNumAllowedTokens(), 0);
    }
    function testGetAllowedToken() public {
        address token1 = address(0x1);
        address token2 = address(0x2);

        uint256 initialDenominator1 = 10;
        uint256 initialDenominator2 = 15;

        auxInfo.allowToken(token1, initialDenominator1);
        auxInfo.allowToken(token2, initialDenominator2);

        address retrievedToken1 = auxInfo.getAllowedToken(0);
        address retrievedToken2 = auxInfo.getAllowedToken(1);

        assertEq(retrievedToken1, token1);
        assertEq(retrievedToken2, token2);
    }
    function testGetRouterInfo() public {
        address router = address(0x3);
        string memory nameIn = "Test Router";
        uint256 routerType = 1;

        auxInfo.allowRouter(router, nameIn, routerType);
        AuxInfo.routerInfo memory retrievedRouterInfo = auxInfo.getRouterInfo(router);

        assertTrue(retrievedRouterInfo.allowed);
        assertEq(retrievedRouterInfo.listPosition, 0);
        assertTrue(retrievedRouterInfo.routerInfoContractAddress != address(0));
    }
    function testIsRouterAllowed() public {
        address router1 = address(0x3);
        address router2 = address(0x4);
        string memory nameIn = "Test Router";
        uint256 routerType = 1;

        auxInfo.allowRouter(router1, nameIn, routerType);

        assertTrue(auxInfo.isRouterAllowed(router1));
        assertTrue(!auxInfo.isRouterAllowed(router2));

        auxInfo.disallowRouter(router1);

        assertTrue(!auxInfo.isRouterAllowed(router1));
    }
    function testGetAllowedRouterByIndex() public {
        address router1 = address(0x3);
        address router2 = address(0x4);
        string memory nameIn = "Test Router";
        uint256 routerType = 1;

        auxInfo.allowRouter(router1, nameIn, routerType);
        auxInfo.allowRouter(router2, nameIn, routerType);

        address retrievedRouter1 = auxInfo.getAllowedRouter(0);
        address retrievedRouter2 = auxInfo.getAllowedRouter(1);

        assertEq(retrievedRouter1, router1);
        assertEq(retrievedRouter2, router2);
    }

    // function testGetMinDepositAmt() public {
    //     address token = address(0x1);
    //     uint256 minDepAmt = 1000;
    //     uint256 initialDenominator = 10;

    //     auxInfo.allowToken(token, initialDenominator);
    //     uint256 retrievedMinDepAmt = auxInfo.getMinDepositAmt(token);

    //     assertEq(retrievedMinDepAmt, minDepAmt);
    // }
    function testIsTokenAllowed() public {
        address token1 = address(0x1);
        address token2 = address(0x2);

        uint256 initialDenominator1 = 10;

        auxInfo.allowToken(token1, initialDenominator1);

        assertTrue(auxInfo.isTokenAllowed(token1));
        assertTrue(!auxInfo.isTokenAllowed(token2));

        auxInfo.disallowToken(token1);

        assertTrue(!auxInfo.isTokenAllowed(token1));
    }



}