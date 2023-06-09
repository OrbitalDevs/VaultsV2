// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;


import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/SafeERC20.sol";
import "./lib/gnosis/Arithmetic.sol";

import "../interfaces/IV3SwapRouter.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/ISharedV2.sol";

import "./functions.sol";
import "./reentrancyGuard.sol";
import "./GasStation.sol";
import "./Auxil.sol";
import "./ChainlinkInterface.sol";



/**
 * @dev VaultFactory is the contract in charge of deploying new vaults
 * and maintains some global variables, such as the fee charged by the contract owner and 
 * the maximum number of tokens allowed per vault. It also maintains a list of all deployed vaults.
 * During contract deployment, it deploys the VaultManagerV2 contract, the VaultInfo contract, 
 * and the AuxInfo contract.
 */
contract VaultFactoryV2 is Ownable, ReentrancyGuarded {
    uint256 private _feeOwner = 500; //0.5% (units are in millipercent)
    uint256 private constant _feeOwnerMax = 1000; //1% (units are in millipercent)
    uint256 private constant maxFee = 20000; // 20% max total fee
    uint256 private maxTokensPerVault = 2;
    uint256 private constant maxInitialDenominator = 2**127;

    // VaultManagerV2 private immutable VM;
    address immutable vaultManagerAddress;
    address[] private deployedVaultsList;
    mapping (address => bool) private isVaultDeployedMap;

    AuxInfo immutable private AI;
    address immutable private vaultInfoAddress;
    
    uint256 private creationBlock; //for front end use to know when to start scanning for txs

    constructor() {
        // transferOwnership(msg.sender);
        creationBlock = block.number;
        AI = new AuxInfo(msg.sender);
        vaultInfoAddress = address(new VaultInfo(address(this)));
        vaultManagerAddress = address(new VaultManagerV2(msg.sender, AI));
    }
    function getCreationBlock() external view returns(uint256){
        return creationBlock;
    }
    //function needed to set creation block on L2 blockchains.
    //(block.number returns approx L1 block on Arbitrum)
    function setCreationBlock(uint256 creationBlockIn) external onlyOwner {
        creationBlock = creationBlockIn;
    }
    function getVaultManagerAddress() external view returns(address){
        return vaultManagerAddress;
    }
    function getVaultInfoAddress() external view returns(address){
        return vaultInfoAddress;
    }
    function getAuxInfoAddress() external view returns(address){
        return address(AI);
    }
    function getMaxTokensPerVault() external view returns(uint256){
        return maxTokensPerVault;
    }

    event SetMaxTokensPerVault(uint256 maxTokensPerVaultIn);
    function setMaxTokensPerVault(uint256 maxTokensPerVaultIn) external onlyOwner {
        require(maxTokensPerVaultIn >= 2, "> 2");
        maxTokensPerVault = maxTokensPerVaultIn;
        emit SetMaxTokensPerVault(maxTokensPerVaultIn);
    }
    function getFeeOwner() external view returns (uint256) {
        return _feeOwner;
    }
    event SetFeeOwner(uint256 feeOwnerIn);
    function setFeeOwner(uint256 feeOwnerIn) external onlyOwner {
        require(feeOwnerIn <= _feeOwnerMax, "> 1000"); // 1% max
        _feeOwner = feeOwnerIn;
        emit SetFeeOwner(feeOwnerIn);
    }
    function getNumVaults() external view returns (uint256) {
        return deployedVaultsList.length;
    }
    function getVaultAddress(uint256 index) external view returns (address) {
        return deployedVaultsList[index];
    }
    function isVaultDeployed(address vaultAddress) external view returns (bool) {
        return isVaultDeployedMap[vaultAddress];
    }

    event AddNewVault(address newVaultAddress);
    function deploy(ISharedV2.vaultInfoDeploy memory params)
        external nonReentrant returns(address) {
              
        require(_feeOwner + params.feeOperator + params.feeUsers <= maxFee, "too high");
        require(params.tokenList.length >= 2 && params.tokenList.length <= maxTokensPerVault, "invalid length");
        require(AI.areTokensAllowed(params.tokenList));
       
        // uint256 sumDenoms = 0; 
        // for (uint256 i = 0; i < params.tokenList.length; i++) {
        //     sumDenoms += AI.getAllowedTokenInfo(params.tokenList[i]).initialDenominator;
        // }
        // require(sumDenoms > 0 && sumDenoms <= maxInitialDenominator, "invalid sumDenoms");

        //using greatest denominator will be sufficient.
        // uint256[] memory allDenoms = new uint256[](params.tokenList.length);
        // for (uint256 i = 0; i < params.tokenList.length; i++) {
        //     allDenoms[i] = AI.getAllowedTokenInfo(params.tokenList[i]).initialDenominator;
        // }
        // (/*uint greatesIndex*/, uint256 greatest) = functions.indexOfGreatest(allDenoms);        

        address vt = address(new VaultV2(vaultManagerAddress, 
                                 msg.sender,
                                 params.name, 
                                 params.tokenList, 
                                 ISharedV2.fees(_feeOwner, params.feeOperator, params.feeUsers), 
                                 params.allowOtherUsers, 
                                 vaultInfoAddress)
                            );

        isVaultDeployedMap[vt] = true;
        deployedVaultsList.push(vt);
        
        emit AddNewVault(vt);
        return vt;
    }
}

/**
 *@dev Vault Manager is in charge of deposits, withdrawals, and trades for each deployed vault.
 * During deployment, it deploys the GasStation contract. It relies on the AuxInfo contract to 
 * maintain a list of allowed tokens, allowed routers.
 */
contract VaultManagerV2 is Ownable, ReentrancyGuarded {
    using SafeERC20 for IERC20;

    uint256 immutable private creationBlock;

    address private _ownerFeesDest;
    address private _autoTrader;

    VaultFactoryV2 immutable private VF;
    GasStation private GS;
    AuxInfo private AI;
    ChainlinkInterface private CLI;

    bool private useGasStation = false;
    uint256 private gasStationParam = 850_000;
    uint256 private constant gasStationParamMax = 1_000_000;
    uint256 private trade5MinTime = 60*60; //5 trades per hour max
    // uint256 private constant maxInitialDenominator = 2**127;
    bool private protocolPaused = false;
    uint256 private constant initDenom = type(uint128).max;

    mapping (address => bool) private isExcludedMap; //excluded from fees

    constructor(address ownerIn, AuxInfo AIIn) {
        transferOwnership(ownerIn);
        _autoTrader = ownerIn;
        _ownerFeesDest = ownerIn;
        creationBlock = block.number;
        VF = VaultFactoryV2(msg.sender);
        GS = new GasStation();
        // CLI = new ChainlinkInterface(ownerIn);
        AI = AIIn;
    }

    function isExcluded(address user) public view returns (bool) {
        return isExcludedMap[user];
    }

    event SetExcluded(address user, bool excluded);
    function setExcluded(address user, bool excluded) external onlyOwner {
        isExcludedMap[user] = excluded;
        emit SetExcluded(user, excluded);
    }

    function getProtocolPaused() external view returns (bool) {
        return protocolPaused;
    }
    function setProtocolPaused(bool protocolPausedIn) external onlyOwner {
        protocolPaused = protocolPausedIn;
    }

    function getChainlinkInterface() external view returns (address) {
        return address(CLI);
    }

    function setChainlinkInterface(address CLIIn) external onlyOwner {
        CLI = ChainlinkInterface(CLIIn);
    }

    function getAutoTrader() external view returns (address) {
        return _autoTrader;
    }

    event SetAutoTrader(address newAutoTrader);
    function setAutoTrader(address autoTraderIn) external onlyOwner {
        require(autoTraderIn != address(0), "0");
        _autoTrader = autoTraderIn;
        emit SetAutoTrader(autoTraderIn);
    }

    function getGasStationParam() external view returns (uint256) {
        return gasStationParam;
    }

    event SetGasStationParam(uint256 gasStationParamIn);
    function setGasStationParam(uint256 gasStationParamIn) external onlyOwner {
        require(gasStationParamIn <= gasStationParamMax, "too high");
        gasStationParam = gasStationParamIn;
        emit SetGasStationParam(gasStationParamIn);
    }

    function getTrade5MinTime() external view returns (uint256) {
        return trade5MinTime;
    }

    event SetTrade5MinTime(uint256 trade5MinTimeIn);
    function setTrade5MinTime(uint256 trade5MinTimeIn) external onlyOwner {
        require(trade5MinTimeIn >= 60*10, "0"); //5 trades in 10 min absolute limit
        trade5MinTime = trade5MinTimeIn;
        emit SetTrade5MinTime(trade5MinTimeIn);
    }

    function getUseGasStation() external view returns (bool) {
        return useGasStation;
    }
    //set whether the operator must deposit gas into the gas station contract to allow for Autotrading.
    //If set to false, the protol will pay for Gas.
    event SetUseGasStation(bool useGasStationIn);
    function setUseGasStation(bool useGasStationIn) external onlyOwner {
        useGasStation = useGasStationIn;
        emit SetUseGasStation(useGasStationIn);
    }

    function getCreationBlock() external view returns (uint256) {
        return creationBlock;
    }

    function getGasStationAddress() external view returns (address) {
        return address(GS);
    }

    function getOwnerFeesDest() external view returns (address) {
        return _ownerFeesDest;
    }

    event SetOwnerFeesDest(address newOwnerFeesDest);
    function setOwnerFeesDest(address newOwnerFeesDest) external onlyOwner {
        require(newOwnerFeesDest != address(0), "0 address");
        _ownerFeesDest = newOwnerFeesDest;
        emit SetOwnerFeesDest(newOwnerFeesDest);
    }

    //function missing before audit!
    function deactivateVault(address vaultAddress) external onlyOwner {
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        VaultV2 vlt = VaultV2(vaultAddress);
        require(vlt.isActive(), "already inactive");
        vlt.deactivate();
    }

    function increaseAllowanceIfNeeded(VaultV2 vlt, address token, uint256 amt) private {
        uint allowance = IERC20(token).allowance(address(vlt), address(this));
        if (allowance < amt) { //probably never used
            vlt.increaseAllowance(token, type(uint96).max - allowance);
        }
    }

    event Deposit(address vaultAddress, address user, uint256[] amts);
    //Vault stores user balances as ratio of the total. The vault has a single Denominator, vlt.D(), 
    //which is always equal to the sum of the Numerators.
    function deposit(address vaultAddress, uint256[] memory amts) external nonReentrant {
        //prechecks
        require(!protocolPaused, "paused");
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        
        VaultV2 vlt = VaultV2(vaultAddress);
        uint256[] memory balancesTracked = vlt.getBalanceTracked();
        address[] memory tkns = vlt.getTokens();

        //input checks
        require(vlt.isActive() && (vlt.allowOtherUsers() || msg.sender==vlt.operator()), "can't deposit");

        //ensure deposits are in the same ratios as the vault's "Tracked Balances".
        //current balances not used to prevent "Donation Skew Attack" as well as "Donation DOS Attack".
        require(functions.ratiosMatch(balancesTracked, amts), "ratios don't match");

        ////values before transfer
        //"Virtual Total Balance" as of the last snapshot.
        //Is required to prevent "Donation Skew Attack".
        // uint256 T = functions.listSum(balancesTracked) + 1; 
        uint256 T = functions.listSum(balancesTracked);
        uint256[] memory balancesBeforeDeposit = vlt.balances();

        //transfer
        for (uint256 i = 0; i < tkns.length; i++) {
            if (amts[i] > 0) {
                IERC20(tkns[i]).safeTransferFrom(msg.sender, vaultAddress, amts[i]);
            }
        }

        //vaules after transfer
        uint256[] memory amtsActual = functions.listDiff(vlt.balances(), balancesBeforeDeposit);
        uint256 amt = functions.listSum(amtsActual);

        //enforce reasonable deposit size
        require(amt > 0 && amt < type(uint128).max, "too much"); 

        //update N and D
        uint256 D = vlt.D();

        if (D == 0){
            vlt.setN(msg.sender, initDenom);
            vlt.setD(initDenom);
        } else {
            if (functions.willOverflowWhenMultiplied(amt, D)) {
                require(T > amt || T > D, "overflow");
            }
            uint256 deltaN = Arithmetic.overflowResistantFraction(amt, D, T);
            vlt.setN(msg.sender,  vlt.N(msg.sender) + deltaN);
            vlt.setD(D + deltaN); //D always kept = sum of all Ns
        }


        //update balancesTracked
        if (msg.sender == vlt.operator()) { //ok to let operator take snapshot (no incentive to DOS attack)
            vlt.takeBalanceSnapshot();
        } else {
            vlt.setBalanceTracked(functions.listAdd(balancesTracked, amtsActual)); //safer option can't alter ratios via Donation attack
        }
        

        emit Deposit(vaultAddress, msg.sender, amts);
    }

    event Withdraw(address vaultAddress, address user, 
                   uint256[] balancesBefore, 
                   uint256 deltaN, 
                   ISharedV2.fees deltaNFees, 
                   uint256 DBefore);

    //Needed to break up withdraw function to prevent stack too deep error
    function _withdraw(VaultV2 vlt, uint256 deltaN) private returns (bool isFinalWithdrawal){
        uint256 D = vlt.D();
        // bool isLastUser = (vlt.N(msg.sender) == D - vlt.initD());
        bool isLastUser = vlt.isLastUser(msg.sender);

        //caclulate fees
        ISharedV2.fees memory deltaNFees = ISharedV2.fees(0, 0, 0);
        if (!(msg.sender==vlt.operator() || isExcluded(msg.sender))) { //not exempt from fees
            ISharedV2.fees memory feeRate = vlt.getFees();

            deltaNFees.owner = Arithmetic.overflowResistantFraction(deltaN, feeRate.owner, 100_000); //overflow protection
            deltaNFees.operator = Arithmetic.overflowResistantFraction(deltaN, feeRate.operator, 100_000);
            
            if (!(isLastUser)) { //User fees not due if last user
                deltaNFees.users = Arithmetic.overflowResistantFraction(deltaN, feeRate.users, 100_000);
            }
        } 
        

        //calculate amounts out
        address[] memory tkns = vlt.getTokens();
        uint256[] memory balancesForWithdrawal;
        // uint256[] memory amtsOutCaller = new uint256[](tkns.length);
        // uint256[] memory amtsOutOwner = new uint256[](tkns.length);

        //transfer tokens
        isFinalWithdrawal = (isLastUser && deltaN == vlt.N(msg.sender) && deltaNFees.operator==0 && deltaNFees.users==0);
        if (isFinalWithdrawal) {
            //ok to use real balances for final withdrawal. DOS attack won't work in this case anyway becasue ratios get set to zero.
            balancesForWithdrawal = vlt.balances(); 
            for (uint256 i = 0; i < tkns.length; i++) {
                uint256 thisBalance = balancesForWithdrawal[i];
                // amtsOutOwner[i] = Arithmetic.overflowResistantFraction(virtualBalance, deltaNFees.owner, D);
                // amtsOutCaller[i] = balancesForWithdrawal[i] - amtsOutOwner[i]; //last out gets the dust
                uint256 amtOutOwner = Arithmetic.overflowResistantFraction(thisBalance, deltaNFees.owner, D);
                uint256 amtOutCaller = thisBalance - amtOutOwner; //last out gets the dust
                
                increaseAllowanceIfNeeded(vlt, tkns[i], amtOutCaller + amtOutOwner);
                if (amtOutOwner > 0) {
                    IERC20(tkns[i]).safeTransferFrom(address(vlt), _ownerFeesDest, amtOutOwner);
                }
                if (amtOutCaller > 0) {
                    IERC20(tkns[i]).safeTransferFrom(address(vlt), msg.sender, amtOutCaller);
                }
            }
        } else {
            uint256 deltaNLeftover = deltaN - deltaNFees.owner - deltaNFees.operator - deltaNFees.users; //withdrawal for msg.sender
            //use tracked balances to prevent Donation DOS attack.
            balancesForWithdrawal = vlt.getBalanceTracked(); 
            for (uint256 i = 0; i < tkns.length; i++) {
                uint256 thisBalance = balancesForWithdrawal[i];
                // amtsOutOwner[i] = Arithmetic.overflowResistantFraction(virtualTrackedBalance, deltaNFees.owner, D);
                // amtsOutCaller[i] = Arithmetic.overflowResistantFraction(virtualTrackedBalance, deltaNLeftover, D);
                uint256 amtOutOwner = Arithmetic.overflowResistantFraction(thisBalance, deltaNFees.owner, D);
                uint256 amtOutCaller = Arithmetic.overflowResistantFraction(thisBalance, deltaNLeftover, D);

                increaseAllowanceIfNeeded(vlt, tkns[i], amtOutCaller + amtOutOwner);
                if (amtOutOwner > 0) {
                    IERC20(tkns[i]).safeTransferFrom(address(vlt), _ownerFeesDest, amtOutOwner);
                }
                if (amtOutCaller > 0) {
                    IERC20(tkns[i]).safeTransferFrom(address(vlt), msg.sender, amtOutCaller);
                }
            }
        }
        

        //variables set after transfer
        if (isFinalWithdrawal) {
            vlt.setN(msg.sender, 0);
            vlt.setD(0);
        } else {
            vlt.setN(msg.sender, vlt.N(msg.sender) - deltaN);
            vlt.setN(vlt.operator(), vlt.N(vlt.operator()) + deltaNFees.operator);
            vlt.setD(D - deltaN + deltaNFees.operator);
        }

        emit Withdraw(address(vlt), 
                      msg.sender, 
                      balancesForWithdrawal,
                      deltaN, 
                      deltaNFees,
                      D);
    }
    function withdraw(address vaultAddress, uint256 percentage) external nonReentrant {
        //Do not check for protocol paused here. If protocol is paused, users can still withdraw their funds.
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        require(percentage > 0 && percentage <= 100, "invalid");
        
        VaultV2 vlt = VaultV2(vaultAddress);

        bool isOperator = (msg.sender == vlt.operator());

        //operator allowed to take snapshot before withdrawal
        if (isOperator) {
            vlt.takeBalanceSnapshot();
        }
        
        //values before transfer
        uint256[] memory balancesBefore = vlt.balances();


        uint256 deltaN = Arithmetic.overflowResistantFraction(vlt.N(msg.sender), percentage, 100);
        require(deltaN > 0, "no balance");

        //withdraw
        bool isFinalWithdrawal = _withdraw(vlt, deltaN);


        //find real amounts out
        uint256[] memory amtsOut = functions.listDiff(balancesBefore, vlt.balances());


        //take snapshot
        if (isOperator || isFinalWithdrawal) {
            vlt.takeBalanceSnapshot();
        } else {
            vlt.setBalanceTracked(functions.listDiff(vlt.getBalanceTracked(), amtsOut));
        }
    }

    event Trade(address spendToken, 
                address receiveToken,
                uint256 spendTokenTotalBefore, 
                uint256 receiveTokenTotalBefore, 
                uint256 spendAmt, 
                uint256 receiveAmt);

    function _trade(VaultV2 vlt, ISharedV2.tradeInput memory TI) private returns (uint256 receiveAmt) {
        AuxInfo.routerInfo memory RI = AI.getRouterInfo(TI.routerAddress);
        
        require(RI.allowed, "invalid router");

        RouterInfo rtrInf = RouterInfo(RI.routerInfoContractAddress);

        require(rtrInf.getNumAllowedPaths(TI.spendToken, TI.receiveToken) > TI.pathIndex, "invalid path index" );


        bytes memory pathMiddle = rtrInf.getAllowedPath(TI.spendToken, TI.receiveToken, TI.pathIndex);
        bytes memory path = abi.encodePacked(TI.spendToken, pathMiddle, TI.receiveToken);

        if (rtrInf.getRouterType() == 0) { //Uniswap V2 type router
            address[] memory pathArray = functions.decodeAddresses(path);
            receiveAmt = vlt.tradeV2(TI.routerAddress, 
                                     TI.spendAmt,
                                     TI.receiveAmtMin,
                                     pathArray
                                     );
        } else { //Uniswap V3 type router
            receiveAmt = vlt.tradeV3(TI.routerAddress, 
                                    IV3SwapRouter.ExactInputParams({
                                        path: path,
                                        recipient: address(vlt),
                                        amountIn: TI.spendAmt,
                                        amountOutMinimum: TI.receiveAmtMin})
                                    );
        }
    }

    function trade(address vaultAddress, ISharedV2.tradeInput memory params) external nonReentrant returns (uint256 receiveAmt) {
        uint256 gasStart = gasleft();
        require(!protocolPaused, "paused");
        //check for dirty inputs
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        require(params.spendToken != params.receiveToken, "same token");
        require(params.spendAmt > 0, "spnd amt 0");

        // ISharedV2.vaultInfo memory VI = vaults[vaultAddress];
        VaultV2 vlt = VaultV2(vaultAddress);
        
        //check for restrictions
        require(vlt.isActive(), "not active");
        require((!vlt.autotradeActive() && msg.sender == vlt.operator()) || (vlt.autotradeActive() && msg.sender == _autoTrader) , "auto/op");
        // require((!vlt.autotradeActive() && msg.sender == vlt.operator()) || (msg.sender == _autoTrader) , "auto/op"); //allow autotrade to be called any time, for limit orders
        
        
        require(block.timestamp - vlt.getOldestTradeTime() >= trade5MinTime, "too soon");
        require(vlt.isTokenAllowed(params.spendToken) && vlt.isTokenAllowed(params.receiveToken), "token not allowed");

        //check slippage with chainlink oracle
        uint256 maxSlippage = AI.getPairMaxSlippage(params.spendToken, params.receiveToken);
        require(CLI.getMinReceived(params.spendToken, params.receiveToken, params.spendAmt, maxSlippage) <= params.receiveAmtMin, "rec min too low");

        uint256 balSpendToken = vlt.balance(params.spendToken);
        uint256 balReceiveToken = vlt.balance(params.receiveToken);
        require(params.spendAmt <= balSpendToken, "not enough spend token");

        //make sure router can spend vault's spend token
        uint256 currentAllowance = IERC20(params.spendToken).allowance(vaultAddress, params.routerAddress);
        if (currentAllowance < params.spendAmt)
            vlt.increaseAllowance(params.spendToken, params.routerAddress, type(uint96).max - currentAllowance);

        receiveAmt = _trade(vlt, params);

        //verify trade
        require(receiveAmt >= params.receiveAmtMin, "increase slippage");
        require(balSpendToken - vlt.balance(params.spendToken)== params.spendAmt, "spd tk bal");
        require(vlt.balance(params.receiveToken) - balReceiveToken == receiveAmt, "rcv tk bal");

        vlt.takeBalanceSnapshot();

        emit Trade(params.spendToken, params.receiveToken, balSpendToken, balReceiveToken, params.spendAmt, receiveAmt);
        
        if (useGasStation && (msg.sender == _autoTrader) && (_autoTrader != vlt.operator())) { //operator pays gas to _autoTrader for auto trades
            uint256 gasPrice = functions.min(tx.gasprice, block.basefee*2);
            if (gasPrice == 0){
                gasPrice = 1;
            }
            uint256 fee = gasPrice * (gasStart - gasleft() + gasStationParam);
            GS.removeGas(fee, payable(_autoTrader), vlt.operator());
        }
    }
}

//This functionality would be in the VaultV2 contract, but the deployment memory contraint prevents it.
//This contract is deployed only once, by the VaultFactoryV2 contract.
contract VaultInfo {
    VaultFactoryV2 private immutable VF;
    uint256 private numAlerts = 0;
    uint256 private lastAlertBlock;
    uint256 private lastAlertTimestamp;
    address private lastAlertVault;

    constructor(address vaultFactoryAddress) {
        VF = VaultFactoryV2(vaultFactoryAddress);
    }

    //NEEDED A QUICK WAY TO CHECK IF VAULT AUTOTRADE STATUS CHANGED.
    //CALLED ONLY BY DEPLOYED VAULTS WHENEVER AUTOTRADE STATUS OR STRATEGY CHANGES.
    event Alert(uint256 numAlerts, uint256 lastAlertBlock, uint256 lastAlertTimestamp, address lastAlertVault);
    function autotradeAlert() external {
        require(VF.isVaultDeployed(msg.sender), "wrong caller");
        numAlerts = numAlerts + 1;
        lastAlertBlock = block.number;
        lastAlertTimestamp = block.timestamp;
        lastAlertVault = msg.sender;

        emit Alert(numAlerts, lastAlertBlock, lastAlertTimestamp, lastAlertVault);
    }
    function getAlertInfo() external view returns (uint256, uint256, uint256, address) {
        return (numAlerts, lastAlertBlock, lastAlertTimestamp, lastAlertVault);
    }


    //an overview of the vault, for front end use
    function getVaultInfo(address vaultAddress) external view returns (ISharedV2.vaultInfoOut memory) {
        require(VF.isVaultDeployed(vaultAddress), "nt dplyd");
        VaultV2 vlt = VaultV2(vaultAddress);
        return ISharedV2.vaultInfoOut(
                vlt.name(),
                vlt.operator(),
                vlt.creationTime(),
                vlt.getTokens(), 
                vlt.getFees(),
                vlt.balances(),
                vlt.D(),
                vlt.strategy(),
                vlt.isActive(),
                vlt.autotradeActive(),
                vlt.allowOtherUsers(),
                vlt.getOldestTradeTime());
    }
    //can be used by front end to find correct ratios if desired
    function getAmtsNeededForDeposit(address vaultAddress, uint256 indexOfReferenceToken, uint256 amtIn) public view returns (uint256 requestCode, uint256[] memory amtsNeeded) {
        VaultV2 vlt = VaultV2(vaultAddress);
        require(indexOfReferenceToken < vlt.numTokens(), "invalid index");
        uint256[] memory balances = vlt.balances();
        return functions.getAmtsNeededForDeposit(indexOfReferenceToken, amtIn, balances);
    }
    //moved this function to the Vault contract. Kept here for front end use.
    function getUserBalances(address vaultAddress, address userAddress) external view returns (uint256[] memory bals) {
        require(VF.isVaultDeployed(vaultAddress), "nt dplyd");
        VaultV2 vlt = VaultV2(vaultAddress);
        return vlt.getUserBalances(userAddress);
    }
}

//Primary Vault contract. This contract is deployed by the VaultFactoryV2 contract by thew Vault Operator each
//time a new vault is created. 
contract VaultV2 is Ownable { //Note: ReentrancyGaurd removed! Auditor please take note.
    using SafeERC20 for IERC20;

    struct listInfo {
        bool isAllowed;
        uint256 index;
    }

    VaultInfo private immutable VI;

    string public name;
    ISharedV2.fees private fees;
    uint256 public immutable creationTime;
    address[] private tokens;
    uint256[] private balanceTracked;
    uint256 public immutable numTokens;
    mapping(address => listInfo) private tokenAllowedMapping;

    uint256 private Denominator = 0;
    // uint256 public immutable initD;
    mapping(address => uint256) private numerators;
    address public operator;
    string public strategy = "";
    bool public isActive = true;
    bool public autotradeActive = false;
    bool public allowOtherUsers;
    
    uint256[5] private lastTradeTimes = [0,0,0,0,0];


    //constructor called by VaultFactoryV2. It will set the owner to VaultManagerV2
    constructor(address ownerIn, 
                address operatorIn,
                string memory nameIn, 
                address[] memory tokensIn, 
                ISharedV2.fees memory feesIn, 
                bool allowOtherUsersIn, 
                address vaultInfoAddress) {
        //vault manager will be the owner.
        if (ownerIn != msg.sender) {
            transferOwnership(ownerIn);
        }
        operator = operatorIn;
        
        name = nameIn;
        
        tokens = new address[](tokensIn.length);
        balanceTracked = new uint256[](tokensIn.length);
        for (uint i = 0; i < tokensIn.length; i++) {
            require(tokenAllowedMapping[tokensIn[i]].isAllowed == false, "dup token"); //check for duplicate tokens
            tokens[i] = tokensIn[i];
            tokenAllowedMapping[tokensIn[i]] = listInfo(true, i);
        }
        fees = feesIn;

        for (uint i = 0; i < tokens.length; i++) {
            //allow vault manager to withdraw tokens
            IERC20(tokens[i]).safeIncreaseAllowance(ownerIn, type(uint96).max); 
        }
        numTokens = tokens.length;
        allowOtherUsers = allowOtherUsersIn;
        creationTime = block.timestamp;

        VI = VaultInfo(vaultInfoAddress);
        // initD = initDIn;
        // Denominator = initD;
    }

    //for use with WITHDRAW function. This function will be called by the VaultManagerV2 contract
    function increaseAllowance(address token, uint256 amt) external onlyOwner {
        require(tokenAllowedMapping[token].isAllowed, "nt allwd");
        IERC20(token).safeIncreaseAllowance(owner(), amt);
    }

    function D() public view returns (uint256) {
        return Denominator;
    }
    function setD(uint256 DIn) external onlyOwner {
        Denominator = DIn;
    }
    function N(address user) public view returns (uint256) {
        return numerators[user];
    }
    function setN(address user, uint256 NIn) external onlyOwner {
        numerators[user] = NIn;
    }
    function isTokenAllowed(address token) external view returns (bool) {
        return tokenAllowedMapping[token].isAllowed;
    }
    function shiftLastTradeTimes() private {
        for (uint i = 0; i < 4; i++) {
            lastTradeTimes[i] = lastTradeTimes[i+1];
        }
        lastTradeTimes[4] = block.timestamp;
    }
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }
    function getOldestTradeTime() external view returns (uint256) {
        return lastTradeTimes[0];
    }
    function getFees() external view returns (ISharedV2.fees memory) {
        return fees;
    }
    event Deactivate(address sender);
    function deactivate() external {
        //owner reserves the right to deactivate a vault (thru the vault manager)
        require(msg.sender == owner() || msg.sender == operator, "only own/op");
        isActive = false;
        VI.autotradeAlert();
        emit Deactivate(msg.sender);
    }

    event SetOperator(address operatorIn);
    function setOperator(address operatorIn) external {
        require(msg.sender == operator, "only op");
        operator = operatorIn;
        emit SetOperator(operatorIn);
    }

    event SetAllowOtherUsers(bool allow);
    function setAllowOtherUsers(bool allow) external {
        require(msg.sender == operator, "only op");
        allowOtherUsers = allow;
        emit SetAllowOtherUsers(allow);
    }

    // event SetStrategy(string strategy);
    // function setStrategy(string calldata stratString) external {
    //     require((msg.sender == operator) && isActive, "only op");
    //     strategy = stratString;
    //     VI.autotradeAlert();
    //     emit SetStrategy(stratString);
    // }

    event SetStrategyAndActivate(string stratString, bool activate);
    function setStrategyAndActivate(string calldata stratString, bool activate) external {
        require((msg.sender == operator) && isActive, "only op");
        strategy = stratString;
        if (activate) {
            require(totalBalance() > 0);
        }
        autotradeActive = activate;
        VI.autotradeAlert();
        emit SetStrategyAndActivate(stratString, activate);
    }

    event SetAutotrade(bool activate);
    function setAutotrade(bool activate) external {
        require((msg.sender == operator) && isActive, "only op");
        if (activate) {
            require(totalBalance() > 0, "no bal");
        }
        autotradeActive = activate;
        VI.autotradeAlert();
        emit SetAutotrade(activate);
    }
    function balance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    function balances() public view returns (uint256[] memory) {
        uint256[] memory bals = new uint256[](numTokens);
        for (uint i = 0; i < numTokens; i++) {
            bals[i] = balance(tokens[i]);
        }
        return bals;
    }

    function totalBalance() public view returns (uint256) {
        uint256 bal = 0;
        for (uint i = 0; i < numTokens; i++) {
            // bal += balance(tokens[i]);
            bal += balanceTracked[i];
        }
        return bal;
    }

    function takeBalanceSnapshot() public onlyOwner {
        balanceTracked = balances();
    }

    function setBalanceTracked(uint256[] memory bals) public onlyOwner {
        balanceTracked = bals;
    }

    function getBalanceTracked() external view returns (uint256[] memory) {
        return balanceTracked;
    }

    function getUserBalances(address userAddress) external view returns (uint256[] memory bals) {        
        uint256 numerator = N(userAddress);
        bals = new uint256[](numTokens);

        // uint256[] memory vbs = virtualBalances();
        // uint256 thisVirtualBalance;

        if (numerator == 0) {
            return bals;
        } else {
            for (uint256 i = 0; i < numTokens; i++) {
            // bals[i] = (vaultBalances[i] * vlt.N(userAddress))/D;
            // thisVirtualBalance = balance(tokens[i]) + 1;
            // thisVirtualBalance = balanceTracked[i] + 1;
            // bals[i] = Arithmetic.overflowResistantFraction(thisVirtualBalance, numerator, Denominator);
                bals[i] = Arithmetic.overflowResistantFraction(balanceTracked[i], numerator, Denominator);
            }
        }
    }

    function isLastUser(address userAddress) external view returns (bool) {
        uint n = numerators[userAddress];
        return (n > 0 && n == Denominator);
    }

    function increaseAllowance(address token, address spenderAddress, uint256 value) external onlyOwner {
        IERC20(token).safeIncreaseAllowance(spenderAddress, value);
    }
    function tradeV2(address routerAddress, uint amountIn, uint amountOutMin, address[] calldata path) external onlyOwner returns (uint256 receiveAmt) {
        shiftLastTradeTimes();
        IUniswapV2Router02 routerV2 = IUniswapV2Router02(routerAddress);
        uint256[] memory recAmts;
        address to = address(this);
        recAmts = routerV2.swapExactTokensForTokens(amountIn, amountOutMin, path, to, block.timestamp);
        receiveAmt = recAmts[recAmts.length - 1];
    }
    function tradeV3(address routerAddress, IV3SwapRouter.ExactInputParams calldata params) external onlyOwner returns (uint256 receiveAmt) {
        shiftLastTradeTimes();
        IV3SwapRouter routerV3 = IV3SwapRouter(routerAddress);
        receiveAmt = routerV3.exactInput(params);
    }
}
