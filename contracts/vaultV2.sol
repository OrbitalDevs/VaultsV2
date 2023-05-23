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



/**
 * @dev VaultFactory is the contract in charge of deploying new vaults
 * and maintains some global variables, such as the fee charged by the contract owner and 
 * the maximum number of tokens allowed per vault. It also maintains a list of all deployed vaults.
 * During contract deployment, it deploys the VaultManagerV2 contract, the VaultInfo contract, 
 * and the AuxInfo contract.
 */
contract VaultFactoryV2 is Ownable, ReentrancyGuarded {
    uint256 private _feeOwner = 500; //0.5% (units are in millipercent)
    uint256 private _feeOwnerMax = 1000; //1% (units are in millipercent)
    uint256 private constant maxFee = 20000; // 20% max total fee
    uint256 private maxTokensPerVault = 2;

    // VaultManagerV2 private immutable VM;
    address immutable vaultManagerAddress;
    address[] private deployedVaultsList;
    mapping (address => bool) private isVaultDeployedMap;

    AuxInfo private AI;
    address private vaultInfoAddress;
    
    uint256 immutable private creationBlock;

    constructor() {
        transferOwnership(msg.sender);
        creationBlock = block.number;
        AI = new AuxInfo(msg.sender);
        vaultInfoAddress = address(new VaultInfo(address(this)));
        vaultManagerAddress = address(new VaultManagerV2(msg.sender, AI));
    }
    function getCreationBlock() external view returns(uint256){
        return creationBlock;
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
    function setMaxTokensPerVault(uint256 maxTokensPerVaultIn) external nonReentrant onlyOwner {
        require(maxTokensPerVaultIn >= 2, "> 2");
        maxTokensPerVault = maxTokensPerVaultIn;
    }
    function getFeeOwner() external view returns (uint256) {
        return _feeOwner;
    }
    function setFeeOwner(uint256 feeOwnerIn) external nonReentrant onlyOwner {
        require(feeOwnerIn <= _feeOwnerMax, "> 1000"); // 1% max
        _feeOwner = feeOwnerIn;
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
        // require(functions.isSortedAddresses(params.tokenList), "not sortd"); //keeps things organized.

        // ISharedV2.fees memory feesIn = ISharedV2.fees(_feeOwner, params.feeOperator, params.feeUsers);
        address vt = address(new VaultV2(vaultManagerAddress, 
                                 msg.sender,
                                 params.name, 
                                 params.tokenList, 
                                 ISharedV2.fees(_feeOwner, params.feeOperator, params.feeUsers), 
                                 params.allowOtherUsers)
                            );

        isVaultDeployedMap[vt] = true;
        deployedVaultsList.push(vt);
        
        emit AddNewVault(vt);
        return vt;
    }
}

/**
 *@dev Vault Manager is in charge of deposits, withdrawals, and trades for each deployed vault.
 * During dployment, it deploys the GasStation contract. It relies on the AuxInfo contract to 
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

    bool private useGasStation = false;
    uint256 private gasStationParam = 850_000;
    uint256 private constant gasStationParamMax = 1_000_000;
    uint256 private trade5MinTime = 60*60; //5 trades per hour max
    uint256 private constant maxInitialDenominator = 2**127;

    constructor(address ownerIn, AuxInfo AIIn) {
        transferOwnership(ownerIn);
        _autoTrader = ownerIn;
        _ownerFeesDest = ownerIn;
        creationBlock = block.number;
        VF = VaultFactoryV2(msg.sender);
        GS = new GasStation();
        
        AI = AIIn;
    }

    function getAutoTrader() external view returns (address) {
        return _autoTrader;
    }

    function setAutoTrader(address autoTraderIn) external nonReentrant onlyOwner {
        _autoTrader = autoTraderIn;
    }

    function getGasStationParam() external view returns (uint256) {
        return gasStationParam;
    }

    function setGasStationParam(uint256 gasStationParamIn) external nonReentrant onlyOwner {
        require(gasStationParamIn <= gasStationParamMax, "too high");
        gasStationParam = gasStationParamIn;
    }

    function getTrade5MinTime() external view returns (uint256) {
        return trade5MinTime;
    }

    function setTrade5MinTime(uint256 trade5MinTimeIn) external nonReentrant onlyOwner {
        trade5MinTime = trade5MinTimeIn;
    }

    function getUseGasStation() external view returns (bool) {
        return useGasStation;
    }
    //set whether the operator must deposit gas into the gas station contract to allow for Autotrading.
    //If set to false, the protol will pay for Gas.
    function setUseGasStation(bool useGasStationIn) external nonReentrant onlyOwner {
        useGasStation = useGasStationIn;
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

    function setOwnerFeesDest(address newOwnerFeesDest) external nonReentrant onlyOwner {
        require(newOwnerFeesDest != address(0), "zero address");
        _ownerFeesDest = newOwnerFeesDest;
    }

    event Deposit(address vaultAddress, address user, uint256[] amts);
    //Vault stores user balances as ratio of the total. The vault has a single Denominator, vlt.D(), which is always equal to the sum of the Numerators.
    function deposit(address vaultAddress, uint256[] memory amts) external nonReentrant {
        require(VF.isVaultDeployed(vaultAddress), "invalid");

        VaultV2 vlt = VaultV2(vaultAddress);
        require(vlt.isActive() && (vlt.allowOtherUsers() || msg.sender==vlt.operator()), "can't deposit");

        uint256 amt = functions.listSum(amts);
        require(amt > 0, "must be > 0");

        address[] memory tkns = vlt.getTokens();
        // require(checkMinDeps(tkns, amts), "min deposit not met");
        
        uint256[] memory balances = vlt.balances();
        //ensure deposits are in the same ratios as the vault's current balances
        require(functions.ratiosMatch(balances, amts), "ratios don't match");
        
        // address user = msg.sender;
        uint256 deltaN;
        uint256 T = functions.listSum(balances);
        uint256 D = vlt.D();

        if (D == 0) { //initial deposit
            uint256 sumDenoms = 0; 
            for (uint256 i = 0; i < tkns.length; i++) {
                sumDenoms += AI.getAllowedTokenInfo(tkns[i]).initialDenominator;
            }
            require(sumDenoms > 0 && sumDenoms <= maxInitialDenominator, "invalid sumDenoms");
            deltaN = sumDenoms; //initial numerator and denominator are the same, and are greater than any possible balance in the vault.
                                //this ensures precision in the vault's balances. User Balance = (N*T)/D will have rounding errors always 1 wei or less. 
        } else { 
            // deltaN = (amt * D)/T;
            deltaN = Arithmetic.overflowResistantFraction(amt, D, T);
        }
        // numerators[vaultAddress][msg.sender] += deltaN;
        vlt.setN(msg.sender,  vlt.N(msg.sender) + deltaN);
        
        // VI.D += deltaN;
        vlt.setD(D + deltaN); //D always kept = sum of all Ns

        for (uint256 i = 0; i < tkns.length; i++) {
            if (amts[i] > 0) {
                IERC20(tkns[i]).safeTransferFrom(msg.sender, vaultAddress, amts[i]);
            }
        }
        emit Deposit(vaultAddress, msg.sender, amts);
    }

    event Withdraw(address vaultAddress, address user, 
                   uint256[] balancesBefore, 
                   uint256 deltaN, 
                   ISharedV2.fees deltaNFees, 
                   uint256 DBefore);
    function withdraw(address vaultAddress, uint256 percentage) external nonReentrant {
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        require(percentage > 0 && percentage <= 100, "invalid");

        // ISharedV2.vaultInfo storage VI = vaults[vaultAddress];
        
        VaultV2 vlt = VaultV2(vaultAddress);
        uint256 D = vlt.D();

        address[] memory tkns = vlt.getTokens();
        uint256[] memory balances = vlt.balances();
        ISharedV2.fees memory feeRateActual = vlt.getFees();
        ISharedV2.fees memory deltaNFees = ISharedV2.fees(0, 0, 0);

        // uint256 deltaN = numerators[vaultAddress][msg.sender];
        uint256 deltaN = vlt.N(msg.sender);
        
        
        if (msg.sender == owner() || msg.sender == vlt.operator() || msg.sender == _ownerFeesDest) {
            feeRateActual = ISharedV2.fees(0, 0, 0); //owner/operator exempt from fees
        } else if (deltaN == D) {
            feeRateActual.users = 0; //last user out gives away no user fees, but must pay owner/operator fees
        }
        // deltaN = (deltaN * percentage)/(100);
        deltaN = Arithmetic.overflowResistantFraction(deltaN, percentage, 100);
        require(deltaN > 0, "no balance");


        // deltaNFees.owner = (deltaN * feeRateActual.owner)/100_000; //removed to _ownerFeeDest 
        // deltaNFees.operator = (deltaN * feeRateActual.operator)/100_000; //stays in vault
        // deltaNFees.users = (deltaN * feeRateActual.users)/100_000; //stays in vault
        deltaNFees.owner = Arithmetic.overflowResistantFraction(deltaN, feeRateActual.owner, 100_000); //overflow protection
        deltaNFees.operator = Arithmetic.overflowResistantFraction(deltaN, feeRateActual.operator, 100_000);
        deltaNFees.users = Arithmetic.overflowResistantFraction(deltaN, feeRateActual.users, 100_000);

        uint256 deltaNLeftover = deltaN - deltaNFees.owner - deltaNFees.operator - deltaNFees.users; //withdrawal for msg.sender

        uint256[] memory amtsOutCaller = new uint256[](tkns.length);
        uint256[] memory amtsOutOwner = new uint256[](tkns.length);

        for (uint256 i = 0; i < tkns.length; i++) {
            // amtsOutCaller[i] = (balances[i] * deltaNLeftover)/D; //all outgoing amounts rounded down, to ensure vault solvency
            // amtsOutOwner[i] = (balances[i] * deltaNFees.owner)/D; //all outgoing amounts rounded down, to ensure vault solvency
            amtsOutCaller[i] = Arithmetic.overflowResistantFraction(balances[i], deltaNLeftover, D);
            amtsOutOwner[i] = Arithmetic.overflowResistantFraction(balances[i], deltaNFees.owner, D);
        }

        if (deltaNLeftover == D) { //last out
            // numerators[vaultAddress][msg.sender] = 0;
            vlt.setN(msg.sender, 0);
            // VI.D = 0;
            vlt.setD(0);
        } else {
            // numerators[vaultAddress][msg.sender] -= deltaN;
            // numerators[vaultAddress][VI.operator] += deltaNFees.operator;
            // VI.D = VI.D - deltaN + deltaNFees.operator;
            vlt.setN(msg.sender, vlt.N(msg.sender) - deltaN);
            vlt.setN(vlt.operator(), vlt.N(vlt.operator()) + deltaNFees.operator);
            vlt.setD(D - deltaN + deltaNFees.operator);
        }

        for (uint256 i = 0; i < tkns.length; i++) {
            if (amtsOutOwner[i] > 0) {
                IERC20(tkns[i]).safeTransferFrom(vaultAddress, _ownerFeesDest, amtsOutOwner[i]);
            }
            if (amtsOutCaller[i] > 0) {
                IERC20(tkns[i]).safeTransferFrom(vaultAddress, msg.sender, amtsOutCaller[i]);
            }
        }
        emit Withdraw(vaultAddress, 
                      msg.sender, 
                      balances,
                      deltaN, 
                      deltaNFees,
                      D);
    }

    event Trade(address spendToken, 
                address receiveToken,
                uint256 spendTokenTotalBefore, 
                uint256 receiveTokenTotalBefore, 
                uint256 spendAmt, 
                uint256 receiveAmt);

    function _trade(VaultV2 vlt, ISharedV2.tradeInput memory TI) private returns (uint256 receiveAmt) {
        // VaultFactoryV2.routerInfo memory RI = VF.getRouterInfo(TI.routerAddress);
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
        //check for dirty inputs
        require(VF.isVaultDeployed(vaultAddress), "invalid");
        require(params.spendToken != params.receiveToken, "same token");
        require(params.spendAmt > 0, "spnd amt 0");

        // ISharedV2.vaultInfo memory VI = vaults[vaultAddress];
        VaultV2 vlt = VaultV2(vaultAddress);
        
        //check for restrictions
        require(vlt.isActive(), "not active");
        // require((!vlt.autotradeActive() && msg.sender == vlt.operator()) || (vlt.autotradeActive() && msg.sender == _autoTrader) , "auto/op");
        require((!vlt.autotradeActive() && msg.sender == vlt.operator()) || (msg.sender == _autoTrader) , "auto/op"); //allow autotrade to be called any time, for limit orders
        require(block.timestamp - vlt.getOldestTradeTime() >= trade5MinTime, "too soon");
        
        require(vlt.isTokenAllowed(params.spendToken) && vlt.isTokenAllowed(params.receiveToken), "token not allowed");
        uint256 balSpendToken = vlt.balance(params.spendToken);
        uint256 balReceiveToken = vlt.balance(params.receiveToken);
        require(params.spendAmt <= balSpendToken, "not enough spend token");

        //make sure router can spend vault's spend token
        //alternate idea: transfer tokens to this contract, trade, transfer back
        uint256 currentAllowance = IERC20(params.spendToken).allowance(vaultAddress, params.routerAddress);
        if (currentAllowance < params.spendAmt)
            vlt.increaseAllowance(params.spendToken, params.routerAddress, type(uint256).max - currentAllowance);

        receiveAmt = _trade(vlt, params);

        require(receiveAmt >= params.receiveAmtMin, "increase slippage");

        emit Trade(params.spendToken, params.receiveToken, balSpendToken, balReceiveToken, params.spendAmt, receiveAmt);

        if (useGasStation && (msg.sender == _autoTrader) && (_autoTrader != vlt.operator())) { //operator pays gas to _autoTrader for auto trades
            uint256 gasPrice = tx.gasprice;
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
    constructor(address vaultFactoryAddress) {
        VF = VaultFactoryV2(vaultFactoryAddress);
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
    function getUserBalances(address vaultAddress, address userAddress) external view returns (uint256[] memory bals) {
        require(VF.isVaultDeployed(vaultAddress), "nt dplyd");
        VaultV2 vlt = VaultV2(vaultAddress);
        
        uint256 D = vlt.D();
        bals = new uint256[](vlt.numTokens());
        if (D == 0) {
            for (uint256 i = 0; i < vlt.numTokens(); i++) {
                bals[i] = 0;
            }
        } else {
            uint256[] memory vaultBalances = vlt.balances();
            for (uint256 i = 0; i < vaultBalances.length; i++) {
                // bals[i] = (vaultBalances[i] * vlt.N(userAddress))/D;
                bals[i] = Arithmetic.overflowResistantFraction(vaultBalances[i], vlt.N(userAddress), D);
            }
        }
    }
}

//Primary Vault contract. This contract is deployed by the VaultFactoryV2 contract by thew Vault Operator each
//time a new vault is created.
contract VaultV2 is Ownable, ReentrancyGuarded {
    using SafeERC20 for IERC20;

    struct listInfo {
        bool isAllowed;
        uint256 index;
    }

    string public name;
    ISharedV2.fees private fees;
    uint256 public creationTime;
    address[] private tokens;
    uint256 public numTokens;
    mapping(address => listInfo) private tokenAllowedMapping;

    uint256 private Denominator = 0;
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
                bool allowOtherUsersIn) {
        //vault manager will be the owner.
        if (ownerIn != msg.sender) {
            transferOwnership(ownerIn);
        }
        operator = operatorIn;
        
        name = nameIn;
        
        tokens = new address[](tokensIn.length);
        for (uint i = 0; i < tokensIn.length; i++) {
            tokens[i] = tokensIn[i];
            tokenAllowedMapping[tokensIn[i]] = listInfo(true, i);
        }
        fees = feesIn;
        for (uint i = 0; i < tokens.length; i++) {
            //allow vault manager to withdraw tokens
            IERC20(tokens[i]).safeIncreaseAllowance(ownerIn, type(uint256).max); 
        }
        numTokens = tokens.length;
        allowOtherUsers = allowOtherUsersIn;
        creationTime = block.timestamp;
    }
    function D() external view returns (uint256) {
        return Denominator;
    }
    function setD(uint256 DIn) external onlyOwner {
        Denominator = DIn;
    }
    function N(address user) external view returns (uint256) {
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
    function getToken(uint256 index) external view returns (address) {
        return tokens[index];
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
    function deactivate() external nonReentrant {
        require(msg.sender == owner() || msg.sender == operator, "only own/op");
        isActive = false;
    }

    function setOperator(address operatorIn) external nonReentrant {
        require(msg.sender == owner() || msg.sender == operator, "only ownop");
        operator = operatorIn;
    }

    function setAllowOtherUsers(bool allow) external nonReentrant{
        require(msg.sender == operator, "only op");
        allowOtherUsers = allow;
    }

    function setStrategy(string calldata stratString) external nonReentrant {
        require((msg.sender == operator), "only op");
        strategy = stratString;
    }

    function setStrategyAndActivate(string calldata stratString, bool activate) external nonReentrant {
        require((msg.sender == operator), "only op");
        strategy = stratString;
        autotradeActive = activate;
    }

    function setAutotrade(bool status) external nonReentrant {
        require((msg.sender == operator), "only op");
        autotradeActive = status;
    }
    function balance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    function balances() public view returns (uint256[] memory) {
        uint256[] memory bal = new uint256[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            bal[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
        return bal;
    }

    function increaseAllowance(address token, address spenderAddress, uint256 value) external nonReentrant onlyOwner {
        IERC20(token).safeIncreaseAllowance(spenderAddress, value);
    }
    function tradeV2(address routerAddress, uint amountIn, uint amountOutMin, address[] calldata path) external nonReentrant onlyOwner returns (uint256 receiveAmt) {
        shiftLastTradeTimes();
        IUniswapV2Router02 routerV2 = IUniswapV2Router02(routerAddress);
        uint256[] memory recAmts;
        address to = address(this);
        recAmts = routerV2.swapExactTokensForTokens(amountIn, amountOutMin, path, to, block.timestamp);
        receiveAmt = recAmts[recAmts.length - 1];
    }
    function tradeV3(address routerAddress, IV3SwapRouter.ExactInputParams calldata params) external nonReentrant onlyOwner returns (uint256 receiveAmt) {
        shiftLastTradeTimes();
        IV3SwapRouter routerV3 = IV3SwapRouter(routerAddress);
        receiveAmt = routerV3.exactInput(params);
    }
}
