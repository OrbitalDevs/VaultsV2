// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

interface IGasStation {
    function owner() external view returns (address);
    function renounceOwnership() external;
    function transferOwnership(address newOwner) external;
    function balanceOf(address account) external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function removeGas(uint256 amount, address payable recipient, address payer) external;
}
