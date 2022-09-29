/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../interfaces/pancake/IPancakeRouter02.sol";
import "../interfaces/pancake/IPancakePair.sol";
import "../interfaces/ITopcorn.sol";
import "../interfaces/IWBNB.sol";
import "./LibMarket.sol";
import "./LibAppStorage.sol";
import "./LibMath.sol";

/**
 * @title Lib Convert
 **/
library LibConvert {
    function sellToPegAndAddLiquidity(uint256 topcorns, uint256 minLP) internal returns (uint256 lp, uint256 topcornsConverted) {
        (uint256 bnbReserve, uint256 topcornReserve) = reserves();
        uint256 maxSellTopcorns = topcornsToPeg(bnbReserve, topcornReserve);
        require(maxSellTopcorns > 0, "Convert: P must be > 1.");
        uint256 sellTopcorns = calculateSwapInAmount(topcornReserve, topcorns);
        if (sellTopcorns > maxSellTopcorns) sellTopcorns = maxSellTopcorns;

        (uint256 TopcornsSold, uint256 wbnbBought) = LibMarket._sell(sellTopcorns, 1, address(this));
        (topcornsConverted, , lp) = LibMarket._addLiquidityWBNB(wbnbBought, topcorns - TopcornsSold, 1, 1);
        require(lp >= minLP, "Convert: Not enough LP.");
        topcornsConverted = topcornsConverted + TopcornsSold;
    }

    function removeLPAndBuyToPeg(uint256 lp, uint256 minTopcorns) internal returns (uint256 topcorns, uint256 lpConverted) {
        lpConverted = lpToPeg();
        require(lpConverted > 0, "Convert: P must be < 1.");
        if (lpConverted > lp) lpConverted = lp;

        (uint256 topcornsRemoved, uint256 bnbRemoved) = removeLiquidityToFarm(lpConverted);
        (, uint256 boughtTopcorns) = LibMarket._buyWithWBNB(1, bnbRemoved, address(this));
        topcorns = topcornsRemoved + boughtTopcorns;
        require(topcorns >= minTopcorns, "Convert: Not enough Topcorns.");
    }

    function removeLiquidityToFarm(uint256 liquidity) private returns (uint256 topcornAmount, uint256 bnbAmount) {
        LibMarket.DiamondStorage storage ds = LibMarket.diamondStorage();
        (topcornAmount, bnbAmount) = IPancakeRouter02(ds.router).removeLiquidity(ds.topcorn, ds.wbnb, liquidity, 1, 1, address(this), block.timestamp);
    }

    function topcornsToPeg(uint256 bnbTopcornPool, uint256 topcornsTopcornPool) internal view returns (uint256 topcorns) {
        (uint256 bnbBUSDPool, uint256 busdBUSDPool) = pegReserves();

        uint256 newTopcorns = LibMath.sqrt((bnbTopcornPool * topcornsTopcornPool * busdBUSDPool) / bnbBUSDPool);
        if (newTopcorns <= topcornsTopcornPool) return 0;
        topcorns = newTopcorns - topcornsTopcornPool;
        topcorns = (topcorns * 100000) / 99875;
    }

    /// @notice lpToPeg solves for the maximum amount ofDeposited  LP that can be converted into Deposited Topcorns
    /// @return lp - the quantity of LP that can be removed such that the bnb recieved
    /// from removing the LP is the exact amount to buy the TopCorn price back to its peg.
    function lpToPeg() internal view returns (uint256 lp) {
        /*
         * lpToPeg solves for the quantity of LP that can be removed such that the bnb recieved from removing the LP
         * is the exact amount to buy the Topcorn price back to its peg.
         * If the Topcorn price is the Topcorn:BNB Pancake V2 Pair is > $1, it will return 0
         * lpToPeg solves the follow system of equations for lp:
         *   lp = bnb * totalLP / e
         *   f * bnb = sqrt((e - bnb) * (b - topcorns) * y/x) - (e - bnb)
         * such that
         *   e / b = (e - bnb) / (b - topcorns)
         * given
         *   e, b - the BNB, Topcorn reserves in the BNB:Topcorn Pancake V2 Pair
         *   y, x - the BNB, USDC reserves in the BNB:USDC Pancake V2 Pair
         *   f - is the inverse of the 1 sided fee on Pancake (1 / 0.99875)
         *   totaLP is the total supply of LP tokens
         * where
         *   bnb, topcorns are the assets returned from removing lp liquidity token from the BNB:Topcorn Pancake V2 Pair
         *
         * The solution can be reduced to:
         *   lp = bnb * totalLP / e
         *   bnb = e (c - 1) / (c + f - 1)
         * such that
         *   c = sqrt((y * b) / (x * e))
         *
         *   0.99875 = 1 - 0.125%
         */

        (uint256 e, uint256 b) = reserves();
        (uint256 y, uint256 x) = pegReserves();
        uint256 c = LibMath.sqrt((y * b * 1e18) / (x * e)) * 1e9;
        if (c <= 1e18) return 0;
        uint256 num = e * (c - 1e18);
        uint256 denom = c - 1251564455569461; // 0.1251564455569461 ~= f - 1 = (1 / 0.99875 - 1)
        uint256 bnb = num / denom;
        return (bnb * totalLP()) / e;
    }

    /**
     * Shed
     **/

    function calculateSwapInAmount(uint256 reserveIn, uint256 amountIn) private pure returns (uint256) {
        return (LibMath.sqrt(reserveIn * (amountIn * 399000000 + reserveIn * 399000625)) - (reserveIn * 19975)) / 19950;
    }

    function totalLP() private view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return IPancakePair(s.c.pair).totalSupply();
    }

    // (BNB, topcorns)
    function reserves() private view returns (uint256, uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(s.c.pair).getReserves();
        return s.index == 0 ? (reserve1, reserve0) : (reserve0, reserve1);
    }

    // (BNB, BUSD)
    function pegReserves() private view returns (uint256, uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(s.c.pegPair).getReserves();
        return s.pegIndex == 0 ? (reserve1, reserve0) : (reserve0, reserve1);
    }
}
