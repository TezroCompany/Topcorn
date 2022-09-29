/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../interfaces/pancake/IPancakePair.sol";
import "../interfaces/pancake/IPancakeRouter02.sol";
import "../interfaces/ITopcorn.sol";
import "../interfaces/IWBNB.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockPancakeswapV2Pair.sol";
import "../mocks/MockPancakeV2Router.sol";
import {AppStorage} from "../farm/AppStorage.sol";
import {LibMarket} from "../libraries/LibMarket.sol";
import "../C.sol";

/**
 * @title Mock Init Diamond
 **/
contract MockInitDiamond {
    event Incentivization(address indexed account, uint256 topcorns);

    AppStorage internal s;

    function init(
        address topcorn,
        address pair,
        address mockRouter
    ) external {
        s.c.topcorn = topcorn;
        s.c.pair = pair;
        s.c.pegPair = address(new MockPancakeswapV2Pair(s.c.wbnb));
        MockPancakeV2Router(mockRouter).setPair(s.c.pair);
        s.c.wbnb = IPancakeRouter02(mockRouter).WETH();

        ITopcorn(s.c.topcorn).approve(mockRouter, type(uint256).max);
        IPancakePair(s.c.pair).approve(mockRouter, type(uint256).max);
        IWBNB(s.c.wbnb).approve(mockRouter, type(uint256).max);

        s.cases = s.cases = [
            // Dsc, Sdy, Inc, nul
            int8(3),
            1,
            0,
            0, // Exs Low: P < 1
            -1,
            -3,
            -3,
            0, //          P > 1
            3,
            1,
            0,
            0, // Rea Low: P < 1
            -1,
            -3,
            -3,
            0, //          P > 1
            3,
            3,
            1,
            0, // Rea Hgh: P < 1
            0,
            -1,
            -3,
            0, //          P > 1
            3,
            3,
            1,
            0, // Exs Hgh: P < 1
            0,
            -1,
            -3,
            0 //          P > 1
        ];
        s.w.yield = 1;

        s.refundStatus = 1;
        s.topcornRefundAmount = 1;
        s.bnbRefundAmount = 1;

        s.season.current = 1;
        s.season.withdrawSeasons = 25;
        s.season.start = block.timestamp;
        s.season.timestamp = block.timestamp;
        s.season.rewardMultiplier = C.getRewardMultiplier();
        s.season.maxTimeMultiplier = C.getMaxTimeMultiplier();
        // ~ gas limit for sunrice function
        s.season.costSunrice = 250000;

        s.index = (IPancakePair(s.c.pair).token0() == s.c.topcorn) ? 0 : 1;
        LibMarket.initMarket(s.c.topcorn, s.c.wbnb, mockRouter);
    }
}
