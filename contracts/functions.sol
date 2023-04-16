// SPDX-License-Identifier: MIT
pragma solidity=0.8.16;
// pragma abicoder v2;
import "./lib/gnosis/Arithmetic.sol";

/**
 *@dev Shared functions used in VaultFactory and VaultManager
 */
library functions {
    // function sorted(address token0, address token1) internal pure returns (address, address) {
    //     return token0 < token1 ? (token0, token1) : (token1, token0);
    // }
    // function isSortedAddresses(address[] memory addressList) internal pure returns (bool){
    //     for (uint256 i = 0; i < addressList.length - 1; i++) {
    //         if (addressList[i] > addressList[i + 1]) {
    //             return false;
    //         }
    //     }
    //     return true;
    // }
    function listSum(uint256[] memory list) internal pure returns (uint256){
        uint256 sum = 0;
        for (uint256 i = 0; i < list.length; i++) {
            sum += list[i];
        }
        return sum;
    }
    function indexOfGreatest(uint256[] memory list) internal pure returns (uint256 greatestIndex, uint256 greatest){
        greatest = 0;
        greatestIndex = 0;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] > greatest) {
                greatest = list[i];
                greatestIndex = i;
            }
        }
    }
    function ratiosMatch(uint256[] memory sourceRatios, uint256[] memory targetRatios) internal pure returns (bool){
        if (sourceRatios.length != targetRatios.length) {
            return false;
        }
        (uint256 greatestIndex, uint256 greatest) = indexOfGreatest(sourceRatios);
        if (greatest == 0) {
            return true;
        }
        for (uint256 i = 0; i < sourceRatios.length; i++) {
            // if (targetRatios[i] != (targetRatios[greatestIndex] * sourceRatios[i]) / greatest) {
            if (targetRatios[i] != Arithmetic.overflowResistantFraction(targetRatios[greatestIndex], sourceRatios[i], greatest)) {
                return false;
            }
        }
        return true;
    }
    function getAmtsNeededForDeposit(uint256 indexOfReferenceToken, uint256 amtIn, uint256[] memory balances) public pure 
        returns (uint256 requestCode, uint256[] memory amtsNeeded) {
        require(indexOfReferenceToken < balances.length && amtIn > 0, "invalid");
        amtsNeeded = new uint256[](balances.length);
        (, uint256 greatest) = indexOfGreatest(balances);
        if (greatest == 0) {
            requestCode = 0;  // initial Deposit, anything is ok
            return (requestCode, amtsNeeded);
        } else if (balances[indexOfReferenceToken] == 0) {
            requestCode = 1; //invalid reference token. Balance must be > 0
            return (requestCode, amtsNeeded);
        }
        requestCode = 2; // normal deposit
        for (uint256 i = 0; i < balances.length; i++) {
            if (i == indexOfReferenceToken) {
                amtsNeeded[i] = amtIn;
            } else {
                // amtsNeeded[i] = (amtIn * balances[i]) / balances[indexOfReferenceToken];
                amtsNeeded[i] = Arithmetic.overflowResistantFraction(amtIn, balances[i], balances[indexOfReferenceToken]);
            }
        }
        return (requestCode, amtsNeeded);
    }

    function decodeAddresses(bytes memory data) internal pure returns (address[] memory) {
        require(data.length % 20 == 0, "Invalid data length");

        uint256 numAddresses = data.length / 20;
        address[] memory addresses = new address[](numAddresses);

        assembly ("memory-safe") {
            let dataPtr := add(data, 0x14)
            // let dataPtr := add(data, 0x0)
            for {let i := 0} lt(i, numAddresses) {i := add(i, 1)} {
                mstore(
                    add(addresses, mul(add(i,1), 0x20)), 
                    mload(add(dataPtr, mul(i, 0x14)))
                )
            }
        }
        return addresses;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

        
}
