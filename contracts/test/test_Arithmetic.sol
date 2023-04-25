// SPDX-License-Identifier: MIT
// pragma solidity >=0.4.24 <0.6.0;
pragma solidity=0.8.16;


import "../lib/gnosis/Arithmetic.sol";

//Dummy contract for testing out the gnosis Arithmetic library in python. (See testArithmetic.py in the scripts folder)
//(Needs to be done in python to check Big Integer Arithmetic. No way to do this in Foundry that I know of.)
contract Arith {
    constructor() {
        
    }

    function mul256By256(uint a, uint b)
        public pure
        returns (uint, uint, uint)
    {
        return Arithmetic.mul256By256(a, b);

    }

    function div256_128By256(uint a21, uint a0, uint b)
        public pure
        returns (uint, uint)
    {
        return Arithmetic.div256_128By256(a21, a0, b);
    }

    function overflowResistantFraction(uint a, uint b, uint divisor)
        public pure
        returns (uint)
    {
        return Arithmetic.overflowResistantFraction(a, b, divisor);
    }
}