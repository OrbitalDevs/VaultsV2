// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

// import "../interfaces/IRouter.sol";
// import "@openzeppelin450/contracts/access/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";

contract AuxInfo is Ownable {
    struct routerInfo {
        bool allowed;
        uint256 listPosition;
        address routerInfoContractAddress;
    }
    struct tokenInfo {
        bool allowed;
        uint256 listPosition;
        // uint256 minDepositAmt;
        uint256 initialDenominator;
    }

    mapping(address => tokenInfo) public allowedTokensMap;
    address[] public allowedTokensList; 

    mapping(address => routerInfo) private allowedRoutersMap; //returns address of RouterInfo Object
    address[] private allowedRoutersList;

    constructor(address ownerIn) {
        transferOwnership(ownerIn);
    }

    //Allowed Tokens Section
    function getNumAllowedTokens() external view returns (uint256) {
        return allowedTokensList.length;
    }
    function getAllowedToken(uint256 index) external view returns (address) {
        return allowedTokensList[index];
    }
    function getAllowedTokens() external view returns (address[] memory) {
        return allowedTokensList;
    }
    function getAllowedTokenInfo(address token) external view returns (tokenInfo memory) {
        return (allowedTokensMap[token]);
    }
    // function setAllowedTokenInfo(address token, uint256 minDepositAmt, uint256 initialDenominator) external onlyOwner {
    function setAllowedTokenInfo(address token, uint256 initialDenominator) external onlyOwner {
        require(allowedTokensMap[token].allowed, "token not allowed");
        // allowedTokensMap[token].minDepositAmt = minDepositAmt;
        allowedTokensMap[token].initialDenominator = initialDenominator;
    }
    function allowToken(address token, uint256 initialDenominator) external onlyOwner {
        require(!allowedTokensMap[token].allowed, "token already allowed");
        allowedTokensList.push(token);
        // allowedTokensMap[token] = tokenInfo(true, allowedTokensList.length - 1, minDepAmt, initialDenominator);
        allowedTokensMap[token] = tokenInfo(true, allowedTokensList.length - 1, initialDenominator);
    }
    function disallowToken(address token) external onlyOwner {
        tokenInfo memory info = allowedTokensMap[token];
        require(info.allowed, "token not allowed");
        uint256 lastTokenIndex = allowedTokensList.length - 1;
        address lastToken = allowedTokensList[lastTokenIndex];
        allowedTokensList[info.listPosition] = lastToken;
        allowedTokensMap[lastToken].listPosition = info.listPosition;
        allowedTokensList.pop();
        delete allowedTokensMap[token];
    }
    function isTokenAllowed(address token) external view returns (bool) {
        return allowedTokensMap[token].allowed;
    }
    function areTokensAllowed(address[] memory tokens) public view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!allowedTokensMap[tokens[i]].allowed) {
                return false;
            }
        }
        return true;
    }
    //Allowed Routers Section
    function getNumAllowedRouters() external view returns (uint256) {
        return allowedRoutersList.length;
    }
    function getAllowedRouter(uint256 index) external view returns (address routerAddress) {
        routerAddress = allowedRoutersList[index];
    }
    function getRouterInfo(address routerAddress) external view returns (routerInfo memory) {
        return (allowedRoutersMap[routerAddress]);
    }
    function isRouterAllowed(address routerAddress) external view returns (bool) {
        return allowedRoutersMap[routerAddress].allowed;
    }
    function allowRouter(address routerAddress, string calldata nameIn, uint256 routerType) external onlyOwner 
        returns (address routerInfoContractAddress){
        require(!allowedRoutersMap[routerAddress].allowed, "router allowed");
        require(routerType == 0 || routerType == 1, "must be 0 or 1");
        allowedRoutersList.push(routerAddress);

        RouterInfo ri = new RouterInfo(owner(), nameIn, routerAddress, routerType);

        allowedRoutersMap[routerAddress] = routerInfo(true, 
                                                allowedRoutersList.length - 1,  
                                                address(ri));
        
        return address(ri);
        
    }
    function disallowRouter(address routerAddress) external onlyOwner {
        routerInfo memory info = allowedRoutersMap[routerAddress];
        require(info.allowed, "router not allowed");
        uint256 lastRouterIndex = allowedRoutersList.length - 1;
        address lastRouter = allowedRoutersList[lastRouterIndex];
        allowedRoutersList[info.listPosition] = lastRouter;
        allowedRoutersMap[lastRouter].listPosition = info.listPosition;
        allowedRoutersList.pop();
        delete allowedRoutersMap[routerAddress];
    }
}

contract RouterInfo is Ownable {
    struct listInfo {
        bool allowed;
        uint256 listPosition;
    }
    struct pair {
        address token0;
        address token1;
        uint256 numPathsAllowed;
    }

    string public name;
    address public immutable routerAddress;
    uint256 public immutable routerType; //0 = V2, 1 = V3

    mapping(address => mapping(address => listInfo)) private allowedPairsMap;
    pair[] private allowedPairsList;

    mapping(address => mapping(address => bytes[])) private allowedPathsMap;
    
    constructor(address ownerIn, string memory _name, address _routerAddress, uint256 _routerType) {
        transferOwnership(ownerIn);
        name = _name;
        routerAddress = _routerAddress;
        routerType = _routerType; //0 = V2, 1 = V3
    }

    function getName() external view returns (string memory){
        return name;
    }
    function getRouterAddress() external view returns (address){
        return routerAddress;
    }
    function getRouterType() external view returns (uint256){
        return routerType;
    }
    function getInfo() external view returns (string memory, address, uint256){
        return (name, routerAddress, routerType);
    }

    //allowed pairs functions. Setting a new allowed pair happens automatically when a new path is added
    function getNumAllowedPairs() external view returns (uint256){
        return allowedPairsList.length;
    }

    function getAllowedPair(uint256 index) external view returns (pair memory pairInfo){
        require(allowedPairsList.length > index, "RouterInfo: index out of bounds");
        return allowedPairsList[index];
    }

    function isPairAllowed(address token0, address token1) external view returns (bool){
        return allowedPairsMap[token0][token1].allowed;
    }

    //allowed paths for each pair
    function getNumAllowedPaths(address token0, address token1) external view returns (uint256){
        return allowedPathsMap[token0][token1].length;
    }

    function getAllowedPath(address token0, address token1, uint256 pathIndex) external view returns (bytes memory){
        require(allowedPathsMap[token0][token1].length > pathIndex, "RouterInfo: pathIndex out of bounds");
        return allowedPathsMap[token0][token1][pathIndex];
    }
    function _increasePairPaths(address token0, address token1) private {
        listInfo storage LI = allowedPairsMap[token0][token1];
        if (!LI.allowed){
            LI.allowed = true;
            LI.listPosition = allowedPairsList.length;
            allowedPairsList.push(pair(token0, token1, 0));
        }
        allowedPairsList[LI.listPosition].numPathsAllowed++;
    }
    function _decreasePairPaths(address token0, address token1) private {
        listInfo storage LI = allowedPairsMap[token0][token1];
        require(LI.allowed, "RouterInfo: pair not allowed");
        allowedPairsList[LI.listPosition].numPathsAllowed--;
        if (allowedPairsList[LI.listPosition].numPathsAllowed == 0){
            allowedPairsList[LI.listPosition] = allowedPairsList[allowedPairsList.length - 1];
            allowedPairsList.pop();
            LI.allowed = false;
        }
    }
    //Does not check if path already allowed. Owner must be smart.
    function allowPath(address token0, address token1, bytes memory path) external onlyOwner {
        allowedPathsMap[token0][token1].push(path);
        _increasePairPaths(token0, token1);
    }

    function disallowPath(address token0, address token1, uint256 pathIndex) external onlyOwner {
        require(allowedPathsMap[token0][token1].length > pathIndex, "RouterInfo: pathIndex out of bounds");
        allowedPathsMap[token0][token1][pathIndex] = allowedPathsMap[token0][token1][allowedPathsMap[token0][token1].length - 1];
        allowedPathsMap[token0][token1].pop();
        _decreasePairPaths(token0, token1);
    }
}