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
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockUniswapV2Router02} from "../mocks/MockUniswap.sol";
import {MockUniswapV3Router} from "../mocks/MockUniswap.sol";


contract TestVaultV2 is DSTest {
    VaultFactoryV2 fac;
    VaultManagerV2 vaultManager;
    VaultInfo vi;
    AuxInfo ai;
    VaultV2 vault;
    MockUniswapV2Router02 mockRouter;
    MockUniswapV2Router02 mockV3Router;
    
    // Variables for constructor
    address facOwner = address(this);
    address ownerIn;
    address operatorIn = address(0x123);
    string nameIn = "MyVault";
    address[] tokenList = new address[](2);
    uint256 initD = 1_000_000_000;
    
    ISharedV2.fees fees = ISharedV2.fees({owner: 1000, operator: 1000, users: 1000});
    bool allowOtherUsersIn = true;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);


    function setUp() public {
        MockERC20 token1 = new MockERC20("Token1", "TK1", 2000 ether, 18);
        MockERC20 token2 = new MockERC20("Token2", "TK2", 2000 ether, 18);

        // console.log("token1: %s", address(token1), 
        //             token1.balanceOf(address(this)), 
        //             token1.balanceOf(ownerIn));

        // address[] memory tokensIn = new address[](2);
        tokenList[0] = address(token1);
        tokenList[1] = address(token2);

        // tokenList.push(address(0x3));
        // console.log("tokenList: HELLOO");
        
        fac = new VaultFactoryV2();
        fac.setFeeOwner(fees.owner);

        ai = AuxInfo(fac.getAuxInfoAddress());
        vaultManager = VaultManagerV2(fac.getVaultManagerAddress());
        ownerIn = address(vaultManager);

        token1.increaseAllowance(ownerIn, 10000);
        token2.increaseAllowance(ownerIn, 10000);

        vi = VaultInfo(fac.getVaultInfoAddress());

        ai.allowToken(address(token1), 1000);
        ai.allowToken(address(token2), 1000);


        vm.startPrank(operatorIn);

        ISharedV2.vaultInfoDeploy memory vid = ISharedV2.vaultInfoDeploy({
            name: nameIn,
            tokenList: tokenList,
            feeOperator: fees.operator,
            feeUsers: fees.users,
            allowOtherUsers: true
        });
        address vAddress = fac.deploy(vid);

        vault = VaultV2(vAddress);

        vm.stopPrank();

        uint[] memory amts = new uint[](2);
        amts[0] = 1000;
        amts[1] = 1000;
        vaultManager.deposit(address(vault), amts);

        // console.log('setUp complete');
    }

    function testSetup() public {
        address owner = vault.owner();
        address operator = vault.operator();
        console.log("owner: %s", owner, operator);
        assertEq(owner, ownerIn);
        assertEq(operator, operatorIn);
        assertEq(owner, address(vaultManager));
    }

    function testTransferOwnership() public {
        vm.prank(ownerIn);
        vault.transferOwnership(operatorIn);
        //vm.stopPrank();
        assertEq(vault.owner(), operatorIn);
    }
    function testRevertTransferOwnershipNotOwner() public {
        vm.prank(operatorIn);
        vm.expectRevert();
        vault.transferOwnership(ownerIn);
        //vm.stopPrank();
    }

    // // Test that only the owner or operator can deactivate the vault
    function testDeactivateOperator() public {
        bool active = vault.isActive();
        assertTrue(active);

        vm.startPrank(operatorIn);
        vault.deactivate();
        //vm.stopPrank();

        active = vault.isActive();
        assertTrue(!active);
        console.log('testDeactivate complete');
    }

    function testDeactiveVaultManager() public {
        bool active = vault.isActive();
        assertTrue(active);

        vaultManager.deactivateVault(address(vault));

        active = vault.isActive();
        assertTrue(!active);
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

        //vm.stopPrank();
    }

    // Test that only the operator can set the strategy
    function testRevertSetStrategyNotOperator() public {
        address nonOperator = address(0x456);
        string memory newStrategy = "NewStrategy";
        vm.startPrank(nonOperator);
        vm.expectRevert();
        vault.setStrategy(newStrategy);
        //vm.stopPrank();
    }
    // Test that the setAutotrade function sets the autotradeActive state variable correctly
    function testSetAutotrade() public {
        bool currentAutotradeStatus = vault.autotradeActive();
        assertTrue(!currentAutotradeStatus);

        vm.startPrank(operatorIn);
        vault.setAutotrade(true);
        currentAutotradeStatus = vault.autotradeActive();

        assertTrue(currentAutotradeStatus);
        //vm.stopPrank();
    }

    // Test that only the operator can call setAutotrade
    function testRevertSetAutotradeNotOperator() public {
        address nonOperator = address(0x789);
        vm.startPrank(nonOperator);
        vm.expectRevert();
        vault.setAutotrade(true);

        //vm.stopPrank();
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
        //vm.stopPrank();
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
        //vm.stopPrank();
    }

    // Test that the setAllowOtherUsers function can be called by the operator and sets the allowOtherUsers state variable correctly
    function testSetAllowOtherUsers() public {
        bool currentAllowOtherUsers = vault.allowOtherUsers();
        assertTrue(currentAllowOtherUsers);

        vm.startPrank(operatorIn);
        vault.setAllowOtherUsers(false);
        currentAllowOtherUsers = vault.allowOtherUsers();

        assertTrue(!currentAllowOtherUsers);
        //vm.stopPrank();
    }

    // Test that only the operator can call setAllowOtherUsers
    function testRevertSetAllowOtherUsersNotOperator() public {
        address nonOperator = address(0xABC);
        vm.prank(nonOperator);

        vm.expectRevert();
        vault.setAllowOtherUsers(false);
        //vm.stopPrank();
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

        uint256 allowanceIncrease = 1000 ether;

        vm.startPrank(ownerIn);
        vault.increaseAllowance(address(token1), spender, allowanceIncrease);
        //vm.stopPrank();

        uint256 newAllowance = token1.allowance(address(vault), spender);
        assertEq(newAllowance, allowanceIncrease+initialAllowance);
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

        //vm.stopPrank();
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
        // uint256 initialDenominator = vault.D();
        uint256 newDenominator = 1000;

        // assertEq(initialDenominator, 0, "Initial Denominator should be 0");

        vm.startPrank(ownerIn);
        vault.setD(newDenominator);
        //vm.stopPrank();
        uint256 updatedDenominator = vault.D();

        assertEq(updatedDenominator, newDenominator, "Updated Denominator should be equal to the new value");
    }

    function testGetAndSetNumerator() public {
        address user = address(0x123);
        uint256 initialNumerator = vault.N(user);
        uint256 newNumerator = 500;

        assertEq(initialNumerator, 0, "Initial Numerator should be 0");

        vm.startPrank(ownerIn);
        vault.setN(user, newNumerator);
        //vm.stopPrank();

        uint256 updatedNumerator = vault.N(user);

        assertEq(updatedNumerator, newNumerator, "Updated Numerator should be equal to the new value");
    }
    function testRevertSetDenominatorNotOwner() public {
        uint256 newDenominator = 1000;
        address nonOwner = operatorIn;

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vault.setD(newDenominator);
        //vm.stopPrank();
    }
    function testRevertSetNumeratorNotOwner() public {
        uint256 newNumerator = 500;
        address nonOwner = address(0x123);

        vm.startPrank(nonOwner);
        vm.expectRevert();
        vault.setN(nonOwner, newNumerator);
        //vm.stopPrank();
    }
    // function testShiftLastTradeTimes() public {
        
    //     MockERC20 token1 = MockERC20(tokenList[0]);
    //     MockERC20 token2 = MockERC20(tokenList[1]);
    //     // uint256 currentTime = block.timestamp; <= this sets to a pointer in memory, sucks
    //     uint256 currentTime = 1;
    //     console.log('currentTime', currentTime);
    //     console.log('lastTime', vault.getOldestTradeTime());

    //     // Perform 5 trades to fill the lastTradeTimes array
    //     uint256 amountIn = 10 ether;
    //     uint256 amountOutMin = 8 ether;
    //     IERC20(tokenList[0]).approve(address(vault), amountIn);

    //     address[] memory path = new address[](2);
    //     path[0] = tokenList[0];
    //     path[1] = tokenList[1];
    //     vault.increaseAllowance(address(path[0]), address(mockRouter), type(uint256).max);
    //     vault.increaseAllowance(address(path[1]), address(mockRouter), type(uint256).max);

    //     // Transfer some tokens to the vault
    //     token1.transfer(address(vault), 500 ether);
    //     token2.transfer(address(vault), 500 ether);

    //     for (uint i = 0; i < 5; i++) {
    //         vm.warp(currentTime + i * 100);
    //         vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);
    //         console.log('lastTime', vault.getOldestTradeTime(), currentTime);
    //     }

    //     uint256 newOldestTradeTime = vault.getOldestTradeTime();
    //     console.log('newOldestTradeTime', newOldestTradeTime, currentTime);
    //     assertEq(newOldestTradeTime, currentTime);

    //     // Perform another trade to see if the oldest trade time has changed
    //     vm.warp(currentTime + 600);
    //     vault.tradeV2(address(mockRouter), amountIn, amountOutMin, path);
    //     console.log('lastTime', vault.getOldestTradeTime());

    //     newOldestTradeTime = vault.getOldestTradeTime();
    //     assertEq(newOldestTradeTime, currentTime + 100);
    // }
}


