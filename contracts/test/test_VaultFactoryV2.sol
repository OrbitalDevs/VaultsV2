// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockUniswapV2Router02} from "../mocks/MockUniswap.sol";
import {MockUniswapV3Router} from "../mocks/MockUniswap.sol";

import "../vaultV2.sol";
import "../Auxil.sol";
import "../../interfaces/ISharedV2.sol";
import "../../interfaces/IV3SwapRouter.sol";


contract TestVaultFactoryV2 is DSTest {
    Utilities internal utils;
    address payable[] internal users;
    address user1;
    address user2;
    address owner;

    MockERC20[10] tokens;

    VaultFactoryV2 vaultFactory;
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
            tokens[i] = new MockERC20("mockToken", "TK", 1000*10**18, 18);
        }

        vm.startPrank(owner);
        vaultFactory = new VaultFactoryV2();

        auxInfo = AuxInfo(address(vaultFactory.getAuxInfoAddress()));

        auxInfo.allowToken(address(tokens[0]), 10000);
        auxInfo.allowToken(address(tokens[1]), 10000);

        creationBlock = block.number;
        vm.stopPrank();
    }

    function testTransferOwnership() public {
        vm.startPrank(owner);
        vaultFactory.transferOwnership(user1);
        vm.stopPrank();
        assertEq(vaultFactory.owner(), user1);
    }
    function testRevertTransferOwnershipNotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        vaultFactory.transferOwnership(user2);
        vm.stopPrank();
        assertEq(vaultFactory.owner(), owner);
    }

    function testGetCreationBlock() public {
        assertEq(vaultFactory.getCreationBlock(), creationBlock);
    }
    function testSetMaxTokensPerVault() public {
        uint256 currentMaxTokensPerVault = vaultFactory.getMaxTokensPerVault();
        assertEq(currentMaxTokensPerVault, 2);

        uint256 maxTokensPerVault = 10;
        vm.startPrank(owner);
        vaultFactory.setMaxTokensPerVault(maxTokensPerVault);
        
        assertEq(vaultFactory.getMaxTokensPerVault(), maxTokensPerVault);
        vm.stopPrank();
    }
    function testRevertSetMaxTokensPerVault() public {
        uint256 currentMaxTokensPerVault = vaultFactory.getMaxTokensPerVault();
        assertEq(currentMaxTokensPerVault, 2);

        vm.startPrank(owner);

        vm.expectRevert();
        vaultFactory.setMaxTokensPerVault(1);

        assertEq(vaultFactory.getMaxTokensPerVault(), currentMaxTokensPerVault);

        vm.stopPrank();
    }
    function testRevertNonOwnerSetMaxTokensPerVault() public {
        uint256 currentMaxTokensPerVault = vaultFactory.getMaxTokensPerVault();
        assertEq(currentMaxTokensPerVault, 2);

        uint256 maxTokensPerVault = 10;

        vm.startPrank(user1);
        vm.expectRevert();
        vaultFactory.setMaxTokensPerVault(maxTokensPerVault);
        
        assertEq(vaultFactory.getMaxTokensPerVault(), currentMaxTokensPerVault);
        vm.stopPrank();
    }
    function testSetFeeOwner() public {
        uint256 currentFeeOwner = vaultFactory.getFeeOwner();
        assertEq(currentFeeOwner, 500);

        uint256 newFeeOwner = 400; // 0.4%
        vm.startPrank(owner);
        vaultFactory.setFeeOwner(newFeeOwner);
        
        assertEq(vaultFactory.getFeeOwner(), newFeeOwner);
        vm.stopPrank();
    }

    function testRevertSetFeeOwner() public {
        uint256 currentFeeOwner = vaultFactory.getFeeOwner();
        assertEq(currentFeeOwner, 500);

        uint256 tooHighFeeOwner = 1001; // 1.001%

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.setFeeOwner(tooHighFeeOwner);

        assertEq(vaultFactory.getFeeOwner(), currentFeeOwner);
        vm.stopPrank();
    }

    function testRevertNonOwnerSetFeeOwner() public {
        uint256 currentFeeOwner = vaultFactory.getFeeOwner();
        assertEq(currentFeeOwner, 500);

        uint256 newFeeOwner = 400; // 0.4%

        vm.startPrank(user1);
        vm.expectRevert();
        vaultFactory.setFeeOwner(newFeeOwner);
        
        assertEq(vaultFactory.getFeeOwner(), currentFeeOwner);
        vm.stopPrank();
    }
    function testDeployVault() public {
        uint256 numVaultsBefore = vaultFactory.getNumVaults();

        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 10000; // 10%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        address newVaultAddress = vaultFactory.deploy(params);
        vm.stopPrank();

        uint256 numVaultsAfter = vaultFactory.getNumVaults();
        assertEq(numVaultsAfter, numVaultsBefore + 1);

        assertTrue(vaultFactory.isVaultDeployed(newVaultAddress));
    }

    function testRevertDeployVaultWithInvalidFee() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 19500; // 19.5% (too high)
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
        vm.stopPrank();
    }


    function testRevertDeployVaultWithInvalidTokenListLength() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](1);
        params.tokenList[0] = address(tokens[0]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 5000; // 5%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
        vm.stopPrank();
    }

    function testRevertDeployVaultWithDisallowedTokens() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[2]); // Disallowed token
        params.tokenList[1] = address(tokens[3]); // Disallowed token
        params.feeOperator = 1000; // 1%
        params.feeUsers = 5000; // 5%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
        vm.stopPrank();
    }

    function testDeployVaultWithValidParameters() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        address newVaultAddress = vaultFactory.deploy(params);
        assertTrue(vaultFactory.isVaultDeployed(newVaultAddress));
        vm.stopPrank();
    }
    function testGetNumVaultsAfterDeployingVaults() public {
        uint256 initialNumVaults = vaultFactory.getNumVaults();
        assertEq(initialNumVaults, 0);

        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vaultFactory.deploy(params);
        uint256 numVaultsAfterDeploy = vaultFactory.getNumVaults();
        assertEq(numVaultsAfterDeploy, 1);
        vm.stopPrank();
    }
    function testGetVaultAddressAfterDeployingVaults() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        address newVaultAddress = vaultFactory.deploy(params);
        address vaultAddressFromGetVault = vaultFactory.getVaultAddress(0);
        assertEq(newVaultAddress, vaultAddressFromGetVault);
        vm.stopPrank();
    }
    // function testRevertDeployVaultWithUnsortedTokenList() public {
    //     // Set up the required parameters for deploy() function
    //     ISharedV2.vaultInfoDeploy memory params;
    //     params.name = "Test Vault";
    //     params.tokenList = new address[](2);
    //     params.tokenList[0] = address(tokens[1]); // Swapping the tokens to make the list unsorted
    //     params.tokenList[1] = address(tokens[0]);
    //     params.feeOperator = 1000; // 1%
    //     params.feeUsers = 1000; // 1%
    //     params.allowOtherUsers = true;

    //     vm.startPrank(owner);
    //     vm.expectRevert();
    //     vaultFactory.deploy(params);
    //     vm.stopPrank();
    // }
    function testRevertDeployVaultWithLessThanTwoTokens() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](1);
        params.tokenList[0] = address(tokens[0]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
        vm.stopPrank();
    }
    function testRevertDeployVaultWithMoreThanMaxTokensPerVault() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](3);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.tokenList[2] = address(tokens[2]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
        vm.stopPrank();
    }
    function testDeployVaultWithValidTokenList() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[0]);
        params.tokenList[1] = address(tokens[1]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        address vaultAddress = vaultFactory.deploy(params);
        vm.stopPrank();

        assertTrue(vaultAddress != address(0));
        VaultV2 vault = VaultV2(vaultAddress);

        // Check if the vault's parameters are set correctly
        assertEq(vault.name(), params.name);
        assertEq(vault.getTokens()[0], params.tokenList[0]);
        assertEq(vault.getTokens()[1], params.tokenList[1]);
        ISharedV2.fees memory vaultFees = vault.getFees();
        assertEq(vaultFees.operator, params.feeOperator);
        assertEq(vaultFees.users, params.feeUsers);
        assertTrue(vault.allowOtherUsers() == params.allowOtherUsers);
    }
    function testRevertDeployVaultWithInvalidTokenList() public {
        // Set up the required parameters for deploy() function
        ISharedV2.vaultInfoDeploy memory params;
        params.name = "Test Vault";
        params.tokenList = new address[](2);
        params.tokenList[0] = address(tokens[2]);
        params.tokenList[1] = address(tokens[3]);
        params.feeOperator = 1000; // 1%
        params.feeUsers = 1000; // 1%
        params.allowOtherUsers = true;

        vm.startPrank(owner);
        vm.expectRevert();
        vaultFactory.deploy(params);
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

