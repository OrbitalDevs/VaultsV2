// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import "forge-std/Test.sol";
// import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
// import {console} from "./utils/Console.sol";
// import "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import { FoundryRandom } from "foundry-random/FoundryRandom.sol";


// import {MockERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockERC20.sol";
// import {MockUniswapV2Router02} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";
// import {MockUniswapV3Router} from "../lib/openzeppelin-contracts@4.5.0/contracts/MockUniswap.sol";
// import {IERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/IERC20.sol";
import {ERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts@4.5.0/contracts/SafeERC20.sol";
import {IWETH} from "../lib/openzeppelin-contracts@4.5.0/contracts/IWETH.sol";

import "../mocks/MockAggregatorV3.sol";

import "../vaultV2.sol";
import "../Auxil.sol";
import "../GasStation.sol";
import "../ChainlinkInterface.sol";
import "../../interfaces/ISharedV2.sol";
import "../../interfaces/IV3SwapRouter.sol";
import "../../interfaces/IUniswapV2Router02.sol";
// import "../../interfaces/IWETH.sol";

contract TestIntegration is Test, FoundryRandom {
    using stdStorage for StdStorage;
    // using SafeERC20 for ERC20;

    Utilities internal utils;
    address payable[] internal users;
    uint256 numUsers = 5;

    mapping(address => uint256[10]) userBalancesBefore;
    mapping(address => uint256[10]) userBalancesAfter;
    mapping(address => uint256[10]) walletBalancesBefore;
    mapping(address => uint256[10]) walletBalancesAfter;
    mapping(address => uint256[10]) vaultBalancesBefore;

    address user1;
    address user2;
    address owner;
    address autoTradeAccount;
    address ownerFeeDest;

    ERC20 weth;
    ERC20 usdc;
    // ERC20 usdt;
    ERC20 dai;
    ERC20 wbtc;
    ERC20 link;
    // ERC20 paxg;
    ERC20[] tokens;
    mapping(address => uint256) tokenIndex;

    VaultFactoryV2 vaultFactory;
    VaultManagerV2 vaultManager;
    GasStation gasStation;

    AuxInfo auxInfo;
    RouterInfo[] routerInfo = new RouterInfo[](2);
    VaultInfo vaultInfo;
    ChainlinkInterface chainlinkInterface;

    mapping(address => address) mockAggregators;

    address[] vaultsList;
    mapping(address => bool) selectedTokens;

    IUniswapV2Router02 uniswapV2Router;
    IV3SwapRouter uniswapV3Router;

    uint256 creationBlock;
    uint256 desiredWithdrawalError;
    //declared in forge-std/src/Base.sol
    // Vm internal immutable vm = Vm(HEVM_ADDRESS);
    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }
    function writeBalances() public {
        for (uint256 i = 0; i < numUsers; i++) {
            writeTokenBalance(users[i], address(usdc), (1_00_000)*10**usdc.decimals());
            writeTokenBalance(users[i], address(dai), (1_00_000)*10**dai.decimals());
            writeTokenBalance(users[i], address(weth), (100)*10**weth.decimals());
            writeTokenBalance(users[i], address(wbtc), (20)*10**(wbtc.decimals()-1));
            writeTokenBalance(users[i], address(link), (100_000)*10**link.decimals());
            // writeTokenBalance(users[i], address(paxg), (20)*10**paxg.decimals());
        }
    }
    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(numUsers);
        user1 = users[3];
        user2 = users[4];
        owner = users[0];
        autoTradeAccount = users[2];
        ownerFeeDest = users[1];

        console.log("SETUP users", users.length);
        


        console.log("SETUP vm");
        vm.startPrank(owner);

        address v3Address = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
        address v2Address = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        uniswapV2Router = IUniswapV2Router02(v2Address);
        uniswapV3Router = IV3SwapRouter(v3Address);

        usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        mockAggregators[address(usdc)] = address(new MockAggregatorV3(8, 1*10**8)); //set USD price for mock
        
        dai = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        mockAggregators[address(dai)] = address(new MockAggregatorV3(8, 1*10**8));

        weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        mockAggregators[address(weth)] = address(new MockAggregatorV3(8, 1906*10**8));

        wbtc = ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        mockAggregators[address(wbtc)] = address(new MockAggregatorV3(8, 27225*10**8));
        // paxg = ERC20(0x45804880De22913dAFE09f4980848ECE6EcbAf78);
        link = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
        mockAggregators[address(link)] = address(new MockAggregatorV3(8, 645*10**6));

        tokens = [usdc, dai, weth, wbtc, link];
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenIndex[address(tokens[i])] = i;
        }

        console.log("SETUP tokens", tokens.length);

        writeBalances();

        vaultFactory = new VaultFactoryV2();
        auxInfo = AuxInfo(address(vaultFactory.getAuxInfoAddress()));
        vaultManager = VaultManagerV2(vaultFactory.getVaultManagerAddress());
        gasStation = GasStation(vaultManager.getGasStationAddress());
        chainlinkInterface = ChainlinkInterface(vaultManager.getChainlinkInterface());

        for (uint256 i = 0; i < tokens.length; i++) {
            console.log(address(tokens[i]));
            console.log(tokens[i].name());
            chainlinkInterface.addPriceFeed(address(tokens[i]), mockAggregators[address(tokens[i])]);
        }
        

        vaultInfo = VaultInfo(vaultFactory.getVaultInfoAddress());
        console.log("SETUP vaultFactory", address(vaultFactory));

        vaultFactory.setMaxTokensPerVault(tokens.length);
        vaultManager.setOwnerFeesDest(ownerFeeDest);
        vaultManager.setAutoTrader(autoTradeAccount);

        routerInfo[0] = RouterInfo(auxInfo.allowRouter(address(uniswapV2Router), "v2 router", 0));
        routerInfo[1] = RouterInfo(auxInfo.allowRouter(address(uniswapV3Router), "v3 router", 1));


        allowToken(usdc, 100_000_0000);
        allowToken(dai, 100_000_000);
        allowToken(weth, 1_000_000);
        allowToken(wbtc, 100_000);
        allowToken(link, 1_000_000);
        // allowToken(paxg, 100_000);

        //set slippages
        for (uint256 i = 0; i < tokens.length-1; i++) {
            for (uint256 j=i+1; j<tokens.length; j++) {
                auxInfo.setPairMaxSlippage(address(tokens[i]), address(tokens[j]), 10_000);
            }
        }

        auxInfo.setPairMaxSlippage(address(usdc), address(dai), 100);
        auxInfo.setPairMaxSlippage(address(usdc), address(weth), 10_000);

        allowPaths();

        creationBlock = block.number;

        vm.stopPrank();
    }
    function allowToken(ERC20 token,  
                        uint256 maxExpectedAmtFloat) public {

        uint256 initDenominator;
        initDenominator = tokenSetupParams(token,  
                                            maxExpectedAmtFloat);
        auxInfo.allowToken(address(token), initDenominator);
    }
    function tokenSetupParams(ERC20 token, 
                              uint256 maxExpectedAmtFloat) 
        private view returns (uint256 initDenominator){
        
        // minDepAmt = (minDepositAmtFloat_MilliUnits * 10**token.decimals())/1000;
        uint256 maxExpectedAmt = (maxExpectedAmtFloat * 10**token.decimals());
        // initDenominator = (desiredWithdrawalError * maxExpectedAmt)/minDepAmt + 1;
        initDenominator = maxExpectedAmt;
        //checks
        // require(minDepAmt > desiredError, "minDepAmt must be > desiredError");
        require(initDenominator < 2**120, "init denom too big");

    }
    function allowPaths() public {
        address[] memory path0 = new address[](0);
        address[] memory path1 = new address[](1);
        address middle = address(weth);
        path1[0] = middle;

        uint24[] memory feesList1 = new uint24[](1);
        feesList1[0] = 3000;

        address[] memory primaries = new address[](2);
        primaries[0] = address(usdc);
        primaries[1] = address(dai);

        address[] memory secondaries = new address[](3);
        secondaries[0] = address(weth);
        secondaries[1] = address(wbtc);
        secondaries[2] = address(link);

        for (uint256 i = 0; i < primaries.length; i++) {
            for (uint256 j = 0; j < secondaries.length; j++) {
                allowPathV2(routerInfo[0], primaries[i], secondaries[j], path0);
                if (primaries[i] != middle && secondaries[j] != middle) {
                    allowPathV2(routerInfo[0], primaries[i], secondaries[j], path1);
                }
                allowPathV3(routerInfo[1], primaries[i], secondaries[j], path0, feesList1);
            }
        }

        // allowPathV2(routerInfo[0], address(usdc), address(paxg), path0);
        // allowPathV2(routerInfo[0], address(usdc), address(paxg), path1);
        // allowPathV2(routerInfo[0], address(weth), address(paxg), path0);
    }
    function pathToBytes(address[] memory path) internal pure returns (bytes memory) {
        bytes memory bytesPath;
        for (uint256 i = 0; i < path.length; i++) {
            bytesPath = abi.encodePacked(bytesPath, path[i]);
        }
        return bytesPath;
    }
    function allowPathV2(RouterInfo ri, address t0, address t1, address[] memory path) internal {
        // bytes memory bytesPath = abi.encodePacked(path);
        bytes memory bytesPath = pathToBytes(path);
        console.log('bytesPath', path.length,  bytesPath.length);

        address[] memory pathReversed = new address[](path.length);
        for(uint256 i = 0; i < path.length; i++){
            pathReversed[i] = path[path.length - i - 1];
        }
        bytes memory bytesPathReversed = pathToBytes(pathReversed); //abi.encodePacked(pathReversed);
        ri.allowPath(t0, t1, bytesPath);
        ri.allowPath(t1, t0, bytesPathReversed);
    }
    // function toBytes3(uint256 x) internal pure returns (bytes memory b) {
    //     b = new bytes(3);
    //     assembly ("memory-safe") { mstore(add(b, 32), x) }
    // }
    function allowPathV3(RouterInfo ri, address t0, address t1, address[] memory path, uint24[] memory feesList) internal {
        bytes memory bytesPath;
        require(feesList.length >= 1, 'low feesList length');
        for (uint256 i = 0; i < feesList.length; i++) {
            bytes memory b = abi.encodePacked(feesList[i]);//toBytes3(feesList[i]);
            console.log('allow V3:', feesList[i], b.length);
            bytesPath = abi.encodePacked(bytesPath, b);
            if (i > 0) {
                bytesPath = abi.encodePacked(bytesPath, path[i]);
            }
        }
        ri.allowPath(t0, t1, bytesPath);
        address[] memory pathReversed = new address[](path.length);
        uint24[] memory feesListReversed = new uint24[](feesList.length);

        for(uint256 i = 0; i < path.length; i++){
            pathReversed[i] = path[path.length - i - 1];
        }
        for(uint256 i = 0; i < feesList.length; i++){
            feesListReversed[i] = feesList[feesList.length - i - 1];
        }

        bytes memory bytesPathReversed;
        for (uint256 i = 0; i < feesListReversed.length; i++) {
            bytes memory b = abi.encodePacked(feesListReversed[i]);//toBytes3(feesListReversed[i]);
            bytesPathReversed = abi.encodePacked(bytesPathReversed, b);
            if (i > 0) {
                bytesPathReversed = abi.encodePacked(bytesPathReversed, pathReversed[i]);
            }
        }
        ri.allowPath(t1, t0, bytesPathReversed);
    }
    function createVault(address user, string memory name, ERC20[] memory tokensIn, 
                                uint256 feeOperator, uint256 feeUsers, 
                                bool isPublic) public returns (address vaultAddress) {
        // console.log("user: ", user);

        address[] memory tokenAddresses = new address[](tokensIn.length);
        for (uint256 i = 0; i < tokensIn.length; i++) {
            tokenAddresses[i] = address(tokensIn[i]);
        }

        ISharedV2.vaultInfoDeploy memory vaultInfoDeploy = ISharedV2.vaultInfoDeploy({
            name: name,
            tokenList: tokenAddresses,
            feeOperator: feeOperator,
            feeUsers: feeUsers,
            allowOtherUsers: isPublic
        });

        // Start pranking
        vm.startPrank(user);
        vaultAddress = vaultFactory.deploy(vaultInfoDeploy);
        // Stop pranking
        vm.stopPrank();

        VaultV2 vault = VaultV2(vaultAddress);
                
        // Check vault properties
        assertEq(vault.name(), name);
        assertEq(vault.owner(), address(vaultManager));
        assertEq(vault.operator(), user);
        assertTrue(vault.isActive());
        assertTrue(vault.allowOtherUsers());

        // Check fees
        ISharedV2.fees memory vaultFees = vault.getFees();
        assertEq(vaultFees.operator, feeOperator);
        assertEq(vaultFees.users, feeUsers);
        assertEq(vaultFees.owner, vaultFactory.getFeeOwner());
        
        // Check tokens
        address[] memory vaultTokens = vault.getTokens();
        assertEq(vaultTokens.length, tokensIn.length);
        for (uint256 i = 0; i < tokensIn.length; i++) {
            assertEq(vaultTokens[i], address(tokensIn[i]));
        }
    }

    function approveTokens(address user, address[] memory tokensIn) public {
        // Approve tokens for deposit
        vm.startPrank(user);
        for (uint256 i = 0; i < tokensIn.length; i++) {
            ERC20 thisToken = ERC20(tokensIn[i]);
            uint256 allowance = thisToken.allowance(user, address(vaultManager));
            if (allowance < type(uint256).max) {
                thisToken.approve(address(vaultManager), type(uint256).max);
            }
        }
        vm.stopPrank();
    }
    function depositIntoVault(address user, address vaultAddress, uint256[] memory depositAmounts) public {
        VaultV2 vault = VaultV2(vaultAddress);
        // VaultManagerV2 vm = VaultManagerV2(vault.owner());
        // Initialize VaultInfo contract
        // VaultInfo vi = new VaultInfo(address(vaultFactory));
        VaultInfo vi = vaultInfo;
        // Check if the vault is valid and active
        require(vault.isActive(), "Vault is not active");
        require(vault.allowOtherUsers() || user == vault.operator(), "User not allowed to deposit");

        // Store initial user balances
        // uint256[] memory initialUserBalances = vi.getUserBalances(vaultAddress, user);
        uint256[] memory initialVaultBalances = vault.balances();

        // Approve tokens for deposit
        
        bool sufficientBalances = true;
        address[] memory tokenAddresses = vault.getTokens();
        // console.log('tokenAddresses.length: ', tokenAddresses.length);
        approveTokens(user, tokenAddresses);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            ERC20 thisToken = ERC20(tokenAddresses[i]);
            // console.log('approving', thisToken.symbol(), depositAmounts[i]);
            // uint256 allowance = thisToken.allowance(user, address(vaultManager));
            // if (allowance < depositAmounts[i]) {
            //     thisToken.safeApprove(address(vaultManager), type(uint256).max);
            //     // thisToken.approve(address(vaultManager), type(uint256).max);
            // }
            if (thisToken.balanceOf(user) < depositAmounts[i]) {
                sufficientBalances = false;
            }
            // console.log('approval done');
        }
        refreshBalances(vaultAddress);

        vm.startPrank(user);
        bool expectRevert = false;
        if (functions.listSum(depositAmounts) == 0 || !sufficientBalances) {
            expectRevert = true;
            vm.expectRevert();
        }
        console.log("depositing...expectRevert: ", expectRevert);
        // printNumList(depositAmounts);
        vaultManager.deposit(vaultAddress, depositAmounts);
        // console.log("depositing...done");
        // Stop pranking
        vm.stopPrank();

        // Verify updated user balances
        // uint256[] memory newUserBalances = vi.getUserBalances(vaultAddress, user);
        
        for (uint i=0; i<users.length; i++){
            address thisUser = users[i];
            uint256[] memory newUserBalances = vi.getUserBalances(vaultAddress, thisUser);
            // uint256[] memory balances = vaultInfo.getUserBalances(vaultAddress, thisUser);
            for (uint256 j = 0; j < tokenAddresses.length; j++) {
                // uint transFee = 0; //units in millipercent 
                uint depAmt = expectRevert ? 0 : depositAmounts[j];
                
                uint depAmtMin;
                if (depAmt <= 1) {
                    depAmtMin = 0;
                } else {
                    depAmtMin = depAmt - 2;
                }
                uint depAmtMax = depAmt + 1;
                // if (tokenAddresses[i] == address(paxg)){
                //     transFee = 20;  // 0.02%
                //     depAmtMin = (depAmt * (100_000 - (transFee + 0)))/100_000;
                //     depAmtMax = depAmt;
                //     // depAmtMax = (depAmt * (100_000 - (transFee - 1)))/100_000;
                    
                // } userBalancesBefore[users[i]][j]
                // if (newUserBalances[j] > userBalancesBefore[thisUser][j] + depAmtMax){
                //     console.log('token', ERC20(tokenAddresses[j]).symbol());
                //     console.log('deposit', expectRevert, depAmt, depositAmounts[j]);
                //     console.log('userBalances', initialUserBalances[j], newUserBalances[j]);
                //     console.log('vaultBalances', initialVaultBalances[j], newVaultBalances[j]);
                // }
                if (thisUser == user){
                    assertLe(newUserBalances[j], userBalancesBefore[thisUser][j] + depAmtMax,  "LE Incorrect user token balance after deposit");
                    assertGe(newUserBalances[j], userBalancesBefore[thisUser][j] + depAmtMin,  "GE Incorrect user token balance after deposit");
                
                } else {
                    assertLe(userBalancesBefore[thisUser][j], newUserBalances[j]+2, "Other user token balance changed");
                    assertGe(userBalancesBefore[thisUser][j]+2, newUserBalances[j], "Other user token balance changed");
                }
                // assertLe(newUserBalances[j], initialUserBalances[j] + depAmtMax,  "LE Incorrect user token balance after deposit");
                // assertGe(newUserBalances[j], initialUserBalances[j] + depAmtMin,  "GE Incorrect user token balance after deposit");
            }
        }
        uint256[] memory newVaultBalances = vault.balances();
        for (uint i=0; i<tokenAddresses.length; i++){
            if (expectRevert){
                assertEq(newVaultBalances[i], initialVaultBalances[i], "Incorrect vault token balance after deposit");
            } else {
                assertEq(newVaultBalances[i], initialVaultBalances[i] + depositAmounts[i], "LE Incorrect vault token balance after deposit");
                // assertGe(newVaultBalances[i], initialVaultBalances[i] + depositAmounts[i], "GE Incorrect vault token balance after deposit");
            }  
        }
        checkTotals(vaultAddress);
    }
    function refreshBalances(address vaultAddress) public {
        address[] memory tokenList = VaultV2(vaultAddress).getTokens();
        for (uint i=0; i<users.length; i++){
            uint256[] memory balances = vaultInfo.getUserBalances(vaultAddress, users[i]);
            for (uint j=0; j<tokenList.length; j++){ 
                userBalancesBefore[users[i]][j] = balances[j];
                walletBalancesBefore[users[i]][j] = ERC20(tokenList[j]).balanceOf(users[i]);
            }
        }
    }

    function withdrawFromVault(address user, address vaultAddress, uint256 percentage) public {
        require(percentage > 0 && percentage <= 100);

        console.log("withdrawFromVault: ", user, vaultAddress, percentage);

        VaultV2 vault = VaultV2(vaultAddress);
        ISharedV2.vaultInfoOut memory vio = vaultInfo.getVaultInfo(vaultAddress);

        address[] memory tokenList = vio.tokenList;
        uint256 numTokens = tokenList.length;

        ISharedV2.fees memory feesActual = vio.feeRate;

        uint256 deltaN = vault.N(user);
        uint256 D = vault.D();

        if (user == vio.operator || user == vaultManager.owner() || user == vaultManager.getOwnerFeesDest()) {
            feesActual = ISharedV2.fees(0, 0, 0);
            // if (deltaN == D) {
            //     feesActual.users = 0; //Last user in the vault. No user fees
            // }
        } else if (deltaN == D - vault.initD()) {
            feesActual.users = 0; //Last user in the vault. No user fees
        }

        uint i;
        uint j = 0;
        uint tol = 4;

        refreshBalances(vaultAddress);

        uint256[] memory withdrawAmtsTotal = new uint256[](numTokens);

        for(i=0; i<numTokens; i++){
            withdrawAmtsTotal[i] = (userBalancesBefore[user][i] * percentage) / 100;
        }

        uint256[] memory ownerFees = new uint256[](numTokens);
        uint256[] memory operatorFees = new uint256[](numTokens);
        uint256[] memory userFees = new uint256[](numTokens);

        for(i=0; i<numTokens; i++){
            ownerFees[i] = (withdrawAmtsTotal[i] * feesActual.owner) / 100_000;
            operatorFees[i] = (withdrawAmtsTotal[i] * feesActual.operator) / 100_000;
            userFees[i] = (withdrawAmtsTotal[i] * feesActual.users) / 100_000;
        }

        // Perform the withdrawal
        vm.startPrank(user);
        if (deltaN == 0){
            vm.expectRevert();
        } 
        vaultManager.withdraw(vaultAddress, percentage);
        vm.stopPrank();

        
        // uint dwe = desiredWithdrawalError;
        for (i=0; i<users.length; i++){
            // console.log('checking user', i, users[i]);
            uint256[] memory balances = vaultInfo.getUserBalances(vaultAddress, users[i]);
            for (j=0; j<numTokens; j++){ 
                uint userFeePortion = 0;
                if (vault.D() > 0){
                    userFeePortion = ((userFees[j]+1) * vault.N(users[i]))/vault.D();
                }
                
                if (users[i] == user) { //the user making the withdrawal...
                    //vault balances
                    uint expectedVaultReduction = withdrawAmtsTotal[j] - userFeePortion;
                    uint actualVaultReduction = userBalancesBefore[users[i]][j] - balances[j];

                    myAssertLe(absDiff(actualVaultReduction, expectedVaultReduction), tol, 0);

                    //wallet balances...
                    uint expectedWalletIncrease = withdrawAmtsTotal[j] - ownerFees[j] - operatorFees[j] - userFees[j];
                    uint actualWalletIncrease = ERC20(tokenList[j]).balanceOf(users[i]) - walletBalancesBefore[users[i]][j];

                    myAssertLe(absDiff(actualWalletIncrease, expectedWalletIncrease), tol, 1);
                } else if (users[i] == vio.operator || users[i] == ownerFeeDest) {
                    //vault balances
                    uint expectedVaultIncrease = userFeePortion;
                    if (users[i] == vio.operator) {
                        expectedVaultIncrease += operatorFees[j];
                    } 
                    uint actualVaultIncrease = balances[j] - userBalancesBefore[users[i]][j];

                    // console.log('diff2: %s', actualVaultIncrease, expectedVaultIncrease);
                    assertLe(absDiff(actualVaultIncrease, expectedVaultIncrease), tol, "withdraw owner or operator vault balance");

                    //wallet balances...
                    if (users[i] == ownerFeeDest){
                        //wallet balances...
                        uint expectedWalletIncrease = ownerFees[j];
                        uint actualWalletIncrease = ERC20(tokenList[j]).balanceOf(users[i]) - walletBalancesBefore[users[i]][j];

                        // console.log('diff4: %s', absDiff(actualWalletIncrease, expectedWalletIncrease));
                        uint ad = absDiff(actualWalletIncrease, expectedWalletIncrease);
                        if (ad > tol){
                            ERC20 thisToken = ERC20(tokenList[j]);
                            console.log('withdraw own error', thisToken.symbol(), expectedWalletIncrease, actualWalletIncrease);
                        }
                        assertLe(absDiff(actualWalletIncrease, expectedWalletIncrease), tol, "withdraw owner wall balance");
                    } else {
                        if (ERC20(tokenList[j]).balanceOf(users[i]) != walletBalancesBefore[users[i]][j]){
                            console.log(user, vio.operator, ownerFeeDest);
                            console.log('diff3: %s', ERC20(tokenList[j]).balanceOf(users[i]), walletBalancesBefore[users[i]][j]);
                        }
                        assertEq(ERC20(tokenList[j]).balanceOf(users[i]), walletBalancesBefore[users[i]][j], "witdraw op wall bal"); //no change expected
                    }
                } else { //other users

                    // //vault balances
                    uint expectedVaultIncrease = userFeePortion;
                    uint actualVaultIncrease = balances[j] - userBalancesBefore[users[i]][j];

                    // console.log('diff5: %s', absDiff(actualVaultIncrease, expectedVaultIncrease));
                    assertLe(absDiff(actualVaultIncrease, expectedVaultIncrease), tol, "withdraw other vault balance");

                    // //wallet balances...
                    assertEq(ERC20(tokenList[j]).balanceOf(users[i]), walletBalancesBefore[users[i]][j], 'withdraw other wall balance'); //no change expected
                }
            }
        }
        checkTotals(vaultAddress);
        console.log('withdrawal done');
    }
    function emptyVault(address vaultAddress) public {
        VaultV2 thisVault = VaultV2(vaultAddress);
        console.log('BEGIN EMPTY VAULT', vaultAddress, thisVault.operator());

        address[] memory tkns = thisVault.getTokens();

        console.log('this vault tokens');
        for (uint i=0; i<tkns.length; i++){
            console.log(ERC20(tkns[i]).symbol());
        }

        for (uint i=0; i<users.length; i++){
            // withdraw(vaultAddress, users[i], 100);
            if (users[i] != thisVault.operator()){
                console.log('calling withdraw from vault', i);
                withdrawFromVault(users[i], vaultAddress, 100);
            }
        }

        uint nBefore = thisVault.N(thisVault.operator());
        uint dBefore = thisVault.D();

        withdrawFromVault(thisVault.operator(), vaultAddress, 100);

        uint nAfter = thisVault.N(thisVault.operator());
        uint dAfter = thisVault.D();

        uint[] memory vaultBalances = thisVault.balances();
        for (uint i=0; i<vaultBalances.length; i++){
            if (vaultBalances[i] > 1){
                console.log('ERROR debug', nBefore, dBefore, thisVault.initD());
                console.log('ERROR debug', nAfter, dAfter, thisVault.initD());
            }
            assertEq(vaultBalances[i], 0, 'empty vault balance check');
        }
        // console.log('empty vault D', thisVault.D());
        assertEq(thisVault.D(), thisVault.initD(), 'empty vault D');
        for (uint i=0; i<users.length; i++){
            assertEq(thisVault.N(users[i]), 0, 'empty vault N');
        }
        console.log('END EMPTY VAULT');
    }
    function checkTotals(address vaultAddress) public {
        VaultV2 vault = VaultV2(vaultAddress);
        uint256[] memory vaultBalances = vault.balances();

        address[] memory tokenList = vault.getTokens();

        uint256[] memory totalBalances = new uint256[](tokenList.length);

        for (uint i=0; i<users.length; i++){
            uint[] memory userBalances = vaultInfo.getUserBalances(vaultAddress, users[i]);
            for (uint j=0; j<tokenList.length; j++){
                totalBalances[j] += userBalances[j];
            }
        }
        uint tolerance = users.length;
        for (uint j=0; j<tokenList.length; j++){
            assertLe(totalBalances[j], vaultBalances[j], 'LE check totals');
            assertGe(totalBalances[j] + tolerance, vaultBalances[j], 'GE check totals');
        }
    }
    function trade(address user, address vaultAddress, ISharedV2.tradeInput memory TI) public returns (uint recAmt){
        bool canTrade = vaultFactory.isVaultDeployed(vaultAddress);
        uint spendtokenBalanceBefore = 0;
        uint recTokenBalanceBefore = 0;
        VaultV2 vault;

        if (canTrade){
            vault = VaultV2(vaultAddress);
            spendtokenBalanceBefore = vault.balance(TI.spendToken);
            recTokenBalanceBefore = vault.balance(TI.receiveToken);
        }
        
        uint trade5MinTime = vaultManager.getTrade5MinTime();
        uint oldestTradeTime = vault.getOldestTradeTime();

        canTrade = canTrade && 
                    (block.timestamp - oldestTradeTime > trade5MinTime) &&
                    spendtokenBalanceBefore > 0 &&
                    vault.isActive() && 
                    ((!vault.autotradeActive() && user == vault.operator()) || (vault.autotradeActive() && user == vaultManager.getAutoTrader()));

        ERC20 st = ERC20(TI.spendToken);
        ERC20 rt = ERC20(TI.receiveToken);
        vm.startPrank(user);
        if (!canTrade){
            console.log('trading expect revert:', TI.spendAmt, st.symbol(), rt.symbol());
            console.log('user', user, vault.operator());
            vm.expectRevert();
            recAmt = vaultManager.trade(vaultAddress, TI);
            recAmt = 0;
        } else {
            
            console.log('trading:', TI.spendAmt, st.symbol(), rt.symbol());
            recAmt = vaultManager.trade(vaultAddress, TI);
            console.log('received:', recAmt);
        }
        
        vm.stopPrank();

        if (canTrade){
            assertEq(vault.balance(TI.spendToken), spendtokenBalanceBefore - TI.spendAmt);
            assertEq(vault.balance(TI.receiveToken), recTokenBalanceBefore + recAmt);
        }


        checkTotals(vaultAddress);
        return recAmt;
        
    }
    function createRandomVault(address vaultOperator) public returns (address) {
        address[] memory allowedTokens = auxInfo.getAllowedTokens();
        uint numTokesTotal = allowedTokens.length;
        uint numTokes = randomNumber(2, numTokesTotal);

        ERC20[] memory tokes = new ERC20[](numTokes);

        for (uint i=0; i<numTokes; i++){
            uint index = randomNumber(0, numTokesTotal - 1);
            while (selectedTokens[allowedTokens[index]]){
                index = randomNumber(0, numTokesTotal - 1);
            }
            selectedTokens[allowedTokens[index]] = true;
            tokes[i] = ERC20(allowedTokens[index]);
        }

        for (uint i=0; i<numTokes; i++){
            selectedTokens[address(tokes[i])] = false;
        }

        uint feeOwner = randomNumber(0, 1000);
        vm.startPrank(owner);
        vaultFactory.setFeeOwner(feeOwner);
        vm.stopPrank();

        
        uint feeOperator = randomNumber(0, 20000 - feeOwner);
        uint feeUsers = randomNumber(0, 20000 - feeOwner - feeOperator);

        // address vaultOperator = users[randomNumber(0, users.length - 1)];

        // vm.startPrank(vaultOperator);
        address newVault = createVault(vaultOperator, "testVault", tokes, feeOperator, feeUsers, true);
        vaultsList.push(newVault);
        return newVault;
    }
    function printNumList(uint256[] memory L) public view {
        for (uint i=0; i<L.length; i++){
            console.log(i, L[i]);
        }
    }
    function printNumLists(uint256[] memory L, uint256[] memory L2) public view {
        for (uint i=0; i<L.length; i++){
            console.log(i, L[i], L2[i]);
        }
    }
    function testSimple() public {
        address[] memory allowedTokens = auxInfo.getAllowedTokens();
        uint numTokesTotal = allowedTokens.length;
        uint numTokes = 2;

        ERC20[] memory tokes = new ERC20[](numTokes);

        tokes[0] = weth;
        tokes[1] = usdc;

        uint feeOwner = 1000;
        uint feeOperator = 1000;
        uint feeUsers = 10000;

        vm.startPrank(owner);
        vaultFactory.setFeeOwner(feeOwner);
        vm.stopPrank();


        address vaultOperator = users[0];

        // vm.startPrank(vaultOperator);
        address newVault = createVault(vaultOperator, "testVault", tokes, feeOperator, feeUsers, true);

        // address thisUser = user1;
        // address otherUser = user2;
        VaultV2 thisVault = VaultV2(newVault);

        uint256[] memory depositAmounts = new uint256[](2);


        for (uint256 i = 0; i < depositAmounts.length; i++) {
            // depositAmounts[i] = minDepAmts[i];
            depositAmounts[i] = 1000;
        }
        
        address[] memory toTrack = new address[](4);
        toTrack[0] = vaultManager.getOwnerFeesDest();
        toTrack[1] = vaultOperator;
        toTrack[2] = user1;
        toTrack[3] = user2;

        trackUsers(newVault, toTrack);

        console.log('DEPOSITING INTO VAULT');
        depositIntoVault(user1, newVault, depositAmounts);
        console.log('DEPOSIT COMPLETE');

        trackUsers(newVault, toTrack);

        console.log('DEPOSITING INTO VAULT');
        depositIntoVault(user2, newVault, depositAmounts);
        console.log('DEPOSIT COMPLETE');

        trackUsers(newVault, toTrack);

        console.log('WITHDRAWING FROM VAULT');
        withdrawFromVault(user1, newVault, 50);
        console.log('WITHDRAW COMPLETE');

        trackUsers(newVault, toTrack);
    }
    function trackUsers(address vltAdd, address[] memory toTrack) public view {
        VaultV2 vlt = VaultV2(vltAdd);
        uint[] memory balsT = vlt.balances();
        console.log('VLT', balsT[0], ',', balsT[1]);
        for (uint256 i = 0; i < toTrack.length; i++) {
            console.log('USER:', i);
            uint[] memory bals = vlt.getUserBalances(toTrack[i]);
            console.log('\t', bals[0], ',', bals[1]);
        }
    }
    function testSystem() public { 
        createRandomVault(users[0]);
        
        uint256 numActions = 300;
        console.log('');
        console.log('');
        for (uint action=0; action<numActions; action++) {
            vm.warp(block.timestamp + randomNumber(1, 1000));
            uint thisAction = randomNumber(0, 5);
            // thisAction = action;
            
            address thisUser = users[randomNumber(0, users.length - 1)];
            // address thisUser = users[0];
            address thisVaultAddress = vaultsList[randomNumber(0, vaultsList.length - 1)];
            VaultV2 thisVault = VaultV2(thisVaultAddress);

            console.log('action:', action, thisAction, thisUser);

            uint numtokens = thisVault.numTokens();

            // uint[] memory balancesBefore = thisVault.balances();
            console.log('balancesBefore:');
            printNumLists(thisVault.balances(), thisVault.getUserBalances(thisUser));
            console.log('begin action');
            ERC20[] memory tokes = new ERC20[](numtokens);
            for (uint i=0; i<numtokens; i++){
                tokes[i] = ERC20(thisVault.getToken(i));
            }

            if (thisAction == 0) { //deposit into vault
                if (thisUser != autoTradeAccount && thisUser != ownerFeeDest) {
                    uint[] memory bals = thisVault.balances();
                    uint[] memory thisWalletBalances = new uint[](bals.length);
                    for (uint i=0; i<bals.length; i++){
                        thisWalletBalances[i] = ERC20(tokes[i]).balanceOf(thisUser);
                    }
                    uint256[] memory depositAmounts = new uint256[](bals.length);

                    if (thisVault.D() == thisVault.initD()) { //initial deposit
                        console.log('DEPOSIT DEBUG:', "INITIAL DEPOSIT");
                        printNumList(bals);
                        for (uint256 i = 0; i < depositAmounts.length; i++) {
                            // depositAmounts[i] = minDepAmts[i];
                            if (thisWalletBalances[i] >= 100 ){
                                depositAmounts[i] = randomNumber(1, thisWalletBalances[i]/1000);
                            }
                        }
                    } else {
                        (uint indx, uint grt) = functions.indexOfGreatest(bals);
                        // uint amtAtIndex = minDepAmts[indx];
                        if (thisWalletBalances[indx] > 1) {
                            uint amtAtIndex = randomNumber(1, thisWalletBalances[indx]);
                            (uint256 reqCode, uint[] memory depositAmountsRet) = functions.getAmtsNeededForDeposit(indx, amtAtIndex, bals);

                            for(uint256 i = 0; i < depositAmountsRet.length; i++) {
                                depositAmounts[i] = depositAmountsRet[i];
                            }

                            console.log('DEPOSIT DEBUG:', indx, grt, reqCode);
                            console.log(amtAtIndex, thisWalletBalances[indx]);
                            printNumLists(bals, depositAmounts);
                        }
                    }
                    console.log('DEPOSITING INTO VAULT', thisVaultAddress);
                    // for (uint i=0; i<depositAmounts.length; i++){
                    //     console.log('depositing:', depositAmounts[i], tokes[i].symbol());
                    // }
                    printNumList(depositAmounts);
                    depositIntoVault(thisUser, thisVaultAddress, depositAmounts);
                }

                // console.log('DEPOSIT COMPLETE');
            } else if (thisAction == 1) { //withdraw
                if (thisVault.N(thisUser) > 0) { //only withdraw if user has a balance
                    uint percent = randomNumber(1, 100);
                    console.log('WITHDRAWING FROM VAULT', thisUser, thisVaultAddress, percent);
                    withdrawFromVault(thisUser, thisVaultAddress, percent);
                }

            } else if (thisAction == 2) {  //trade
                address spendToken = address(tokes[randomNumber(0, tokes.length - 1)]);
                address recToken = spendToken;
                int j=0;
                while (recToken == spendToken && j < 20) {
                    recToken = address(tokes[randomNumber(0, tokes.length - 1)]);
                    j++;
                }
                console.log(ERC20(spendToken).symbol(), '->', ERC20(recToken).symbol());
                RouterInfo ri = routerInfo[randomNumber(0, routerInfo.length - 1)];
                uint numPaths = ri.getNumAllowedPaths(spendToken, recToken);
                uint spendAmt = randomNumber(0, thisVault.balance(spendToken));
                console.log('numPaths:', numPaths, 'spendAmt:', spendAmt);
                if (numPaths > 0 && spendAmt > 0){
                    uint pathIndex = randomNumber(0, numPaths - 1);
                    // uint nomReceived = chainlinkInterface.getMinReceived(spendToken, recToken, spendAmt, 0);
                    uint minReceived = chainlinkInterface.getMinReceived(spendToken, recToken, spendAmt, 5_000);
                    ISharedV2.tradeInput memory TI = ISharedV2.tradeInput({
                        spendToken: spendToken,
                        receiveToken: recToken,
                        spendAmt: spendAmt,
                        receiveAmtMin: minReceived,
                        routerAddress: ri.routerAddress(),
                        pathIndex: pathIndex
                    });
                    console.log('TRADING', thisUser, thisVaultAddress);
                    console.log(ERC20(spendToken).symbol(), '->', ERC20(recToken).symbol());
                    console.log('spendAmt:', spendAmt, 'minReceived:', minReceived);
                    trade(thisUser, thisVaultAddress, TI);
                }   
            } else if (thisAction == 3) { //create new vault
                if (thisUser != autoTradeAccount && thisUser != ownerFeeDest) {
                    console.log('CREATING NEW VAULT');
                    createRandomVault(thisUser);
                }
            } else if (thisAction == 4) {
                if (thisVault.D() > 0){
                    console.log('EMPTYING VAULT', thisVaultAddress);
                    emptyVault(thisVaultAddress);
                }
            } else if (thisAction == 5) {
                //toggle autoTrade
                
                if (thisVault.totalBalance() > 0) {
                    bool autotradeState = thisVault.autotradeActive();
                    address operator = thisVault.operator();
                    vm.startPrank(operator);
                    console.log('TOGGLING AUTOTRADE');
                    thisVault.setAutotrade(!autotradeState);
                    vm.stopPrank();
                    assertEq(thisVault.autotradeActive(), !autotradeState);
                }
            }
            console.log('balancesAfter:');
            printNumLists(thisVault.balances(), thisVault.getUserBalances(thisUser));
            console.log('');
        }
        console.log('num vaults: %s', vaultsList.length);
    }


    function testSetup() public {
        assertEq(creationBlock, vaultFactory.getCreationBlock());
        assertEq(creationBlock, vaultManager.getCreationBlock());
        assertTrue(auxInfo.isTokenAllowed(address(usdc)));
        assertTrue(auxInfo.isTokenAllowed(address(dai)));
        assertTrue(auxInfo.isTokenAllowed(address(weth)));
        assertTrue(auxInfo.isTokenAllowed(address(wbtc)));
        // assertTrue(auxInfo.isTokenAllowed(address(paxg)));
        assertTrue(auxInfo.isRouterAllowed(address(uniswapV2Router)));
        assertTrue(auxInfo.isRouterAllowed(address(uniswapV3Router)));
    }
    function absDiff(uint a, uint b) internal pure returns (uint) {
        if (a > b) {
            return a - b;
        } else {
            return b - a;
        }
    }
    function myAssertEq(uint256 a, uint256 b, uint code) internal {
        if (a != b) {
            console.log("Assert failed: %s == %s", a, b, code);
        }
        assertEq(a, b);
    }
    function myAssertLe(uint256 a, uint256 b, uint code) internal {
        if (a > b) {
            console.log("Assert failed: %s <= %s", a, b, code);
        }
        assertLe(a, b);
    }
    function myAssertGe(uint256 a, uint256 b, uint code) internal {
        if (a < b) {
            console.log("Assert failed: %s >= %s", a, b, code);
        }
        assertGe(a, b);
    }
}


