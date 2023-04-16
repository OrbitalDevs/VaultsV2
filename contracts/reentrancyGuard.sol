// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;

contract ReentrancyGuarded {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
    }

    function readGuardCounter() public view returns (uint256) {
        return _guardCounter;
    }
}
