// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "./reentrancyGuard.sol";

// import "@openzeppelin450/contracts/access/Ownable.sol";
import "./lib/openzeppelin-contracts@4.5.0/contracts/Ownable.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin450/contracts/token/ERC20/utils/SafeERC20.sol";

contract GasStation is Ownable, ReentrancyGuarded {
    mapping (address => uint256) private gasBalances;

    constructor() {
        transferOwnership(msg.sender);
    }

    function balanceOf(address account) external view returns (uint256) {
        return gasBalances[account];
    }
    //called by user to deposit gas
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "must be > than 0");
        gasBalances[msg.sender] += msg.value;
    }

    //called by user to withdraw gas
    function withdraw(uint256 amount) external nonReentrant {
        require(gasBalances[msg.sender] >= amount && amount > 0, "insufficient balance");
        gasBalances[msg.sender] -= amount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    //called by VaultManager to withdraw gas
    function removeGas(uint256 amount, address payable recipient, address payer) external onlyOwner nonReentrant {
        require(gasBalances[payer] >= amount, "insufficient balance");
        gasBalances[payer] -= amount;
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}