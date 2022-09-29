/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/ConvertFacet/ConvertFacet.sol";
import "../../libraries/LibMath.sol";

contract MockConvertFacet is ConvertFacet {
    // see https://blog.alphaventuredao.io/onesideduniswap/
    function calculateSwapInAmountPancake(uint256 amtA, uint256 resA) external pure returns (uint256) {
        return (LibMath.sqrt(amtA * (resA * 399000000 + amtA * 399000625)) - (amtA * 19975)) / 19950;
    }

    function calculateSwapInAmountUniswap(uint256 reserveIn, uint256 amountIn) external pure returns (uint256) {
        return (LibMath.sqrt(reserveIn * (amountIn * 3988000 + reserveIn * 3988009)) - (reserveIn * 1997)) / 1994;
    }
}
