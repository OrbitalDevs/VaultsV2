// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "./lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";


contract Orbital is ERC20 {
    constructor() ERC20("Orbital", "OAI") {
        _mint(msg.sender, 1_000_000_000*10**18);
    }
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

