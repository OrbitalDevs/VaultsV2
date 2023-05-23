// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../vaultV2.sol";
import "../Auxil.sol";
import "../../interfaces/ISharedV2.sol";
import "../../interfaces/IV3SwapRouter.sol";
import {MockERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockERC20.sol";
import {MockUniswapV2Router02} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";
import {MockUniswapV3Router} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";


contract TestVaultV2 is DSTest {
    VaultV2 vault;
    MockUniswapV2Router02 mockRouter;
    MockUniswapV2Router02 mockV3Router;
    
    // Variables for constructor
    address ownerIn = address(this);
    address operatorIn = address(0x123);
    string nameIn = "MyVault";
    address[] tokenList = new address[](2);
    
    ISharedV2.fees fees = ISharedV2.fees({owner: 1000, operator: 1000, users: 1000});
    bool allowOtherUsersIn = true;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function setUp() public {
        MockERC20 token1 = new MockERC20("Token1", "TK1", 2000 ether);
        MockERC20 token2 = new MockERC20("Token2", "TK2", 2000 ether);

        console.log("token1: %s", address(token1), 
                    token1.balanceOf(address(this)), 
                    token1.balanceOf(ownerIn));

        // address[] memory tokensIn = new address[](2);
        tokenList[0] = address(token1);
        tokenList[1] = address(token2);

        // tokenList.push(address(0x3));
        // console.log("tokenList: HELLOO");
        vault = new VaultV2(ownerIn, operatorIn, nameIn, tokenList, fees, allowOtherUsersIn);
        // RouterInfo ri = new RouterInfo(ownerIn, name, address(0x123), 0);

        mockRouter = new MockUniswapV2Router02();
        mockV3Router = new MockUniswapV2Router02();

        // Transfer tokens to the MockRouter
        token1.transfer(address(mockRouter), 500 ether);
        token2.transfer(address(mockRouter), 500 ether);
        console.log('setUp complete');
    }

    function testTransferOwnership() public {
        vm.prank(ownerIn);
        vault.transferOwnership(operatorIn);
        vm.stopPrank();
        assertEq(vault.owner(), operatorIn);
    }
    function testRevertTransferOwnershipNotOwner() public {
        vm.prank(operatorIn);
        vm.expectRevert();
        vault.transferOwnership(ownerIn);
        vm.stopPrank();
    }

    // // Test that only the owner or operator can deactivate the vault
    function testDeactivate() public {
        bool active = vault.isActive();
        assertTrue(active);
        vault.deactivate();
        active = vault.isActive();
        assertTrue(!active);
        // assertTrue(true);
        console.log('testDeactivate complete');
    }

    // Test that the vault's strategy can be set and retrieved correctly
    function testSetStrategy() public {
        string memory newStrategy = "NewStrategy";
        string memory currentStrategy = vault.strategy();

        assertEq(currentStrategy, "");

        vm.prank(operatorIn);
        vault.setStrategy(newStrategy);
        currentStrategy = vault.strategy();

        assertEq(currentStrategy, newStrategy);

        vm.stopPrank();
    }

    // Test that only the operator can set the strategy
    function testRevertSetStrategyNotOperator() public {
        address nonOperator = address(0x456);
        string memory newStrategy = "NewStrategy";
        vm.startPrank(nonOperator);
        vm.expectRevert();
        vault.setStrategy(newStrategy);
        vm.stopPrank();
    }
    // Test that the setAutotrade function sets the autotradeActive state variable correctly
    function testSetAutotrade() public {
        bool currentAutotradeStatus = vault.autotradeActive();
        assertTrue(!currentAutotradeStatus);

        vm.startPrank(operatorIn);
        vault.setAutotrade(true);
        currentAutotradeStatus = vault.autotradeActive();

        assertTrue(currentAutotradeStatus);
        vm.stopPrank();
    }

    // Test that only the operator can call setAutotrade
    function testRevertSetAutotradeNotOperator() public {
        address nonOperator = address(0x789);
        vm.startPrank(nonOperator);
        vm.expectRevert();
        vault.setAutotrade(true);

        vm.stopPrank();
    }
    // Test that the setStrategyAndActivate function sets the strategy and autotradeActive state variables correctly
    function testSetStrategyAndActivate() public {
        string memory newStrategy = "NewStrategy2";
        string memory currentStrategy = vault.strategy();
        bool currentAutotradeStatus = vault.autotradeActive();

        assertEq(currentStrategy, "");
        assertTrue(!currentAutotradeStatus);

        vm.startPrank(operatorIn);
        vault.setStrategyAndActivate(newStrategy, true);
        currentStrategy = vault.strategy();
        currentAutotradeStatus = vault.autotradeActive();

        assertEq(currentStrategy, newStrategy);
        assertTrue(currentAutotradeStatus);
        vm.stopPrank();
    }

    function testRevertSetStrategyAndActivate() public {
        address nonOperator = address(0x789);
        string memory newStrategy = "NewStrategy2";
        string memory currentStrategy = vault.strategy();
        bool currentAutotradeStatus = vault.autotradeActive();

        assertEq(currentStrategy, "");
        assertTrue(!currentAutotradeStatus);

        vm.startPrank(nonOperator);
        vm.expectRevert();
        vault.setStrategyAndActivate(newStrategy, true);
        vm.stopPrank();
    }

    // Test that the setAllowOtherUsers function can be called by the operator and sets the allowOtherUsers state variable correctly
    function testSetAllowOtherUsers() public {
        bool currentAllowOtherUsers = vault.allowOtherUsers();
        assertTrue(currentAllowOtherUsers);

        vm.startPrank(operatorIn);
        vault.setAllowOtherUsers(false);
        currentAllowOtherUsers = vault.allowOtherUsers();

        assertTrue(!currentAllowOtherUsers);
        vm.stopPrank();
    }

    // Test that only the operator can call setAllowOtherUsers
    function testRevertSetAllowOtherUsersNotOperator() public {
        address nonOperator = address(0xABC);
        vm.prank(nonOperator);

        vm.expectRevert();
        vault.setAllowOtherUsers(false);
        vm.stopPrank();
    }

    // Test that the balance function returns the correct token balance of the vault contract
    function testBalance() public {
        MockERC20 token1 = MockERC20(tokenList[0]);
        uint256 token1Balance = token1.balanceOf(address(vault));

        uint256 vaultToken1Balance = vault.balance(address(token1));
        assertEq(token1Balance, vaultToken1Balance);
    }

    // Test that the balances function returns the correct token balances of the vault contract
    function testBalances() public {
        MockERC20 token1 = MockERC20(tokenList[0]);
        MockERC20 token2 = MockERC20(tokenList[1]);

        uint256 token1Balance = token1.balanceOf(address(vault));
        uint256 token2Balance = token2.balanceOf(address(vault));

        uint256[] memory vaultBalances = vault.balances();
        assertEq(vaultBalances.length, 2);
        assertEq(vaultBalances[0], token1Balance);
        assertEq(vaultBalances[1], token2Balance);
    }
    // Test that the increaseAllowance function correctly increases the allowance of the specified spender
    function testIncreaseAllowance() public {
        MockERC20 token1 = MockERC20(tokenList[0]);
        address spender = address(0xABC);

        uint256 initialAllowance = token1.allowance(address(vault), spender);
        assertEq(initialAllowance, 0);

        uint256 allowanceIncrease = 1000 ether;
        vault.increaseAllowance(address(token1), spender, allowanceIncrease);

        uint256 newAllowance = token1.allowance(address(vault), spender);
        assertEq(newAllowance, allowanceIncrease);
    }

    // Test that only the owner can call the increaseAllowance function
    function testRevertIncreaseAllowanceNotOwner() public {
        MockERC20 token1 = MockERC20(tokenList[0]);
        address spender = address(0xDEF);
        uint256 allowanceIncrease = 1000 ether;

        address nonOwner = address(0x456);
        vm.prank(nonOwner);

        vm.expectRevert();
        vault.increaseAllowance(address(token1), spender, allowanceIncrease);

        vm.stopPrank();
    }


    function testTradeV2() public {
        MockERC20 token1 = MockERC20(tokenList[0]);
        MockERC20 token2 = MockERC20(tokenList[1]);

        console.log("token1: %s", address(token1),  
                    token1.balanceOf(ownerIn));
        console.log("token2: %s", address(token2), 
                    token2.balanceOf(ownerIn));
        console.log("token1: %s", address(token1), 
                    token1.balanceOf(address(vault)));
        console.log("token2: %s", address(token2), 
                    token2.balanceOf(address(vault)));

        // Transfer some tokens to the vault
        token1.transfer(address(vault), 500 ether);
        token2.transfer(address(vault), 500 ether);

        console.log("token1: %s", address(token1),  
                    token1.balanceOf(ownerIn));
        console.log("token2: %s", address(token2), 
                    token2.balanceOf(ownerIn));
        console.log("token1: %s", address(token1), 
                    token1.balanceOf(address(vault)));
        console.log("token2: %s", address(token2), 
                    token2.balanceOf(address(vault)));

        // Set up the path for the token swap
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        uint256 amountIn = 100 ether;
        uint256 amountOutMin = 50 ether;

        // Increase allowance for the mock router
        vault.increaseAllowance(address(token1), address(mockRouter), amountIn);
        vault.increaseAllowance(address(token2), address(mockRouter), amountIn);

        // Call tradeV2 function
        uint256 receiveAmt = vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);

        // Check received amount and token balances
        assertEq(receiveAmt, 200 ether);
        assertEq(token1.balanceOf(address(vault)), 400 ether);
        assertEq(token2.balanceOf(address(vault)), 700 ether);
    }

    // Test that the tradeV2 function reverts when the input amount is higher than the allowed maximum
    function testRevertTradeV2ExceedsMaxInputAmount() public {
        vm.startPrank(ownerIn);
        uint256 amountIn = 600 ether;
        uint256 amountOutMin = 1 ether;
        address[] memory path = new address[](2);
        path[0] = tokenList[0];
        path[1] = tokenList[1];

        vm.expectRevert();
        vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);
        vm.stopPrank();
    }

    // Test that the tradeV3 function reverts when the input amount is higher than the allowed maximum
    function testRevertTradeV3ExceedsMaxInputAmount() public {
        vm.startPrank(ownerIn);
        uint256 amountIn = 600 ether;
        uint256 amountOutMin = 1 ether;
        bytes memory path = abi.encodePacked(tokenList[0], tokenList[1]);
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams(
            path,
            address(this),
            amountIn,
            amountOutMin
        );

        vm.expectRevert();
        vault.tradeV3(address(mockRouter), params);
        vm.stopPrank();
    }
    function testRevertTradeV3NonOwner() public {
        uint256 amountIn = 100 ether;
        uint256 amountOutMin = 80 ether;

        // Allow the vault to spend Token1 on behalf of the test contract
        IERC20(tokenList[0]).approve(address(vault), amountIn);

        // Set up the ExactInputParams struct
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: abi.encodePacked(tokenList[0], tokenList[1]),
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: amountOutMin
        });

        // Attempt to trade with a non-owner address
        address nonOwner = address(0xABC);
        vm.startPrank(nonOwner);

        vm.expectRevert();
        vault.tradeV3(address(mockRouter), params);
        vm.stopPrank();
    }
    function testGetTokens() public {
        address[] memory tokens = vault.getTokens();
        uint256 tokenCount = tokens.length;

        assertEq(tokenCount, tokenList.length, "Token count mismatch");

        for (uint256 i = 0; i < tokenCount; i++) {
            assertEq(tokens[i], tokenList[i], "Token address mismatch");
        }
    }
    function testGetFees() public {
        ISharedV2.fees memory returnedFees = vault.getFees();

        assertEq(returnedFees.owner, fees.owner, "Owner fee mismatch");
        assertEq(returnedFees.operator, fees.operator, "Operator fee mismatch");
        assertEq(returnedFees.users, fees.users, "Users fee mismatch");
    }
    function testGetAndSetDenominator() public {
        uint256 initialDenominator = vault.D();
        uint256 newDenominator = 1000;

        assertEq(initialDenominator, 0, "Initial Denominator should be 0");

        vault.setD(newDenominator);
        uint256 updatedDenominator = vault.D();

        assertEq(updatedDenominator, newDenominator, "Updated Denominator should be equal to the new value");
    }

    function testGetAndSetNumerator() public {
        address user = address(0x123);
        uint256 initialNumerator = vault.N(user);
        uint256 newNumerator = 500;

        assertEq(initialNumerator, 0, "Initial Numerator should be 0");

        vault.setN(user, newNumerator);
        uint256 updatedNumerator = vault.N(user);

        assertEq(updatedNumerator, newNumerator, "Updated Numerator should be equal to the new value");
    }
    function testRevertSetDenominatorNotOwner() public {
        uint256 newDenominator = 1000;
        address nonOwner = address(0x123);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vault.setD(newDenominator);
        vm.stopPrank();
    }
    function testRevertSetNumeratorNotOwner() public {
        uint256 newNumerator = 500;
        address nonOwner = address(0x123);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vault.setN(nonOwner, newNumerator);
        vm.stopPrank();
    }
    function testShiftLastTradeTimes() public {
        
        MockERC20 token1 = MockERC20(tokenList[0]);
        MockERC20 token2 = MockERC20(tokenList[1]);
        // uint256 currentTime = block.timestamp; <= this sets to a pointer in memory, sucks
        uint256 currentTime = 1;
        console.log('currentTime', currentTime);
        console.log('lastTime', vault.getOldestTradeTime());

        // Perform 5 trades to fill the lastTradeTimes array
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 8 ether;
        IERC20(tokenList[0]).approve(address(vault), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenList[0];
        path[1] = tokenList[1];
        vault.increaseAllowance(address(path[0]), address(mockRouter), type(uint256).max);
        vault.increaseAllowance(address(path[1]), address(mockRouter), type(uint256).max);

        // Transfer some tokens to the vault
        token1.transfer(address(vault), 500 ether);
        token2.transfer(address(vault), 500 ether);

        for (uint i = 0; i < 5; i++) {
            vm.warp(currentTime + i * 100);
            vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);
            console.log('lastTime', vault.getOldestTradeTime(), currentTime);
        }

        uint256 newOldestTradeTime = vault.getOldestTradeTime();
        console.log('newOldestTradeTime', newOldestTradeTime, currentTime);
        assertEq(newOldestTradeTime, currentTime);

        // Perform another trade to see if the oldest trade time has changed
        vm.warp(currentTime + 600);
        vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);
        console.log('lastTime', vault.getOldestTradeTime());

        newOldestTradeTime = vault.getOldestTradeTime();
        assertEq(newOldestTradeTime, currentTime + 100);
    }
}


