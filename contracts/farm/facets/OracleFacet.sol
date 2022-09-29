/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../AppStorage.sol";
import "../../libraries/Decimal.sol";
import "../../libraries/PancakeOracleLibrary.sol";

/**
 * @title Oracle tracks the TWAP price of the BUSD/BNB and TopCorn/BNB Pancake pairs.
 **/
contract OracleFacet {
    using Decimal for Decimal.D256;

    AppStorage internal s;

    /// @notice Function that calls capture for tracking the Delta B on the Pancake pool
    /// @return D256 The deltaB of the pool
    function capture() public virtual returns (Decimal.D256 memory, Decimal.D256 memory) {
        require(address(this) == msg.sender, "Oracle: Farmer only");
        if (s.o.initialized) {
            return updateOracle();
        } else {
            initializeOracle();
            return (Decimal.one(), Decimal.one());
        }
    }

    /// @notice Internal function for initializing the pool oracle by calculating the cumulative balances within the pool.
    function initializeOracle() internal {
        uint256 priceCumulative = s.index == 0 ? IPancakePair(s.c.pair).price0CumulativeLast() : IPancakePair(s.c.pair).price1CumulativeLast();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IPancakePair(s.c.pair).getReserves();

        if (reserve0 != 0 && reserve1 != 0 && blockTimestampLast != 0) {
            s.o.cumulative = priceCumulative;
            s.o.timestamp = blockTimestampLast;
            s.o.initialized = true;
            (uint256 peg_price0Cumulative, uint256 peg_price1Cumulative, uint32 peg_blockTimestamp) = PancakeOracleLibrary.currentCumulativePrices(s.c.pegPair);
            uint256 peg_priceCumulative = s.pegIndex == 0 ? peg_price0Cumulative : peg_price1Cumulative;
            s.o.pegCumulative = peg_priceCumulative;
            s.o.pegTimestamp = peg_blockTimestamp;
        }
    }

    function updateOracle() internal returns (Decimal.D256 memory, Decimal.D256 memory) {
        (Decimal.D256 memory topcorn_price, Decimal.D256 memory busd_price) = updatePrice();
        return (topcorn_price, busd_price);
    }

    function updatePrice() private returns (Decimal.D256 memory, Decimal.D256 memory) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PancakeOracleLibrary.currentCumulativePrices(s.c.pair);
        (uint256 peg_price0Cumulative, uint256 peg_price1Cumulative, uint32 peg_blockTimestamp) = PancakeOracleLibrary.currentCumulativePrices(s.c.pegPair);
        uint256 priceCumulative = s.index == 0 ? price0Cumulative : price1Cumulative;
        uint256 peg_priceCumulative = s.pegIndex == 0 ? peg_price0Cumulative : peg_price1Cumulative;

        uint32 timeElapsed = blockTimestamp - s.o.timestamp; // overflow is desired
        uint32 pegTimeElapsed = peg_blockTimestamp - s.o.pegTimestamp; // overflow is desired

        uint256 price1 = (priceCumulative - s.o.cumulative) / timeElapsed;
        uint256 price2 = (peg_priceCumulative - s.o.pegCumulative) / pegTimeElapsed;

        Decimal.D256 memory topcorn_price = Decimal.ratio(price1, 2**112);
        Decimal.D256 memory busd_price = Decimal.ratio(price2, 2**112);

        s.o.timestamp = blockTimestamp;
        s.o.pegTimestamp = peg_blockTimestamp;

        s.o.cumulative = priceCumulative;
        s.o.pegCumulative = peg_priceCumulative;

        return (topcorn_price, busd_price);
    }

    function getTWAPPrices() external view returns (uint256, uint256) {
        if (s.o.timestamp == 0) return (1e18, 1e18);
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PancakeOracleLibrary.currentCumulativePrices(s.c.pair);
        (uint256 peg_price0Cumulative, uint256 peg_price1Cumulative, uint32 peg_blockTimestamp) = PancakeOracleLibrary.currentCumulativePrices(s.c.pegPair);
        uint256 priceCumulative = s.index == 0 ? price0Cumulative : price1Cumulative;
        uint256 peg_priceCumulative = s.pegIndex == 0 ? peg_price0Cumulative : peg_price1Cumulative;

        uint32 timeElapsed = blockTimestamp - s.o.timestamp; // overflow is desired
        uint32 pegTimeElapsed = peg_blockTimestamp - s.o.pegTimestamp; // overflow is desired

        uint256 topcornPrice;
        uint256 busdPrice;
        if (timeElapsed > 0) {
            uint256 price1 = (priceCumulative - s.o.cumulative) / timeElapsed;
            topcornPrice = Decimal.ratio(price1, 2**112).mul(1e18).asUint256();
        } else {
            (uint256 reserve0, uint256 reserve1, ) = IPancakePair(s.c.pair).getReserves();
            topcornPrice = 1e18 * (s.index == 0 ? reserve1 / reserve0 : reserve0 / reserve1);
        }
        if (pegTimeElapsed > 0) {
            uint256 price2 = (peg_priceCumulative - s.o.pegCumulative) / pegTimeElapsed;
            busdPrice = Decimal.ratio(price2, 2**112).mul(1e18).asUint256();
        } else {
            (uint256 reserve0, uint256 reserve1, ) = IPancakePair(s.c.pegPair).getReserves();
            // We assume that the index of BUSD is 0 in this instance - no, need peg_index.
            busdPrice = 1e18 * (s.pegIndex == 0 ? reserve1 / reserve0 : reserve0 / reserve1);
        }
        return (topcornPrice, busdPrice);
    }

    function getOracleStorage() external view returns (Storage.Oracle memory) {
        return s.o;
    }
}
