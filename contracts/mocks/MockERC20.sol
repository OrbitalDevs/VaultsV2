// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

import "../lib/openzeppelin-contracts@4.5.0/contracts/ERC20.sol";


contract MockERC20 is ERC20 {

    uint8 dec = 18;

    constructor(string memory name, string memory symbol, uint256 initSupply, uint8 decimalsIn) ERC20(name, symbol) {
        dec = decimalsIn;
        _mint(msg.sender, initSupply*10**decimalsIn);
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }

}