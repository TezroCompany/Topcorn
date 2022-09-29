/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import {AppStorage} from "../AppStorage.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IDiamondCut} from "../../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../../interfaces/IERC173.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibMarket} from "../../libraries/LibMarket.sol";
import "../../C.sol";
import "../../interfaces/ITopcorn.sol";
import "../../interfaces/IWBNB.sol";
import "../../interfaces/pancake/IPancakePair.sol";
import "../../interfaces/pancake/IPancakeFactory.sol";
import "../../interfaces/pancake/IPancakeRouter02.sol";
import "../../TopCorn.sol";
import "../../mocks/MockToken.sol";

/**
 * @title Init Diamond initializes the Farmer Diamond.
 **/
contract InitDiamond {
    event FirstIncentivization(address indexed account, uint256 topcorns);

    AppStorage internal s;

    function init() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        address FACTORY = C.getFactory();
        address ROUTER = C.getRouter();
        address BUSD = C.getBUSD();

        s.c.topcorn = address(new TopCorn());
        s.c.wbnb = IPancakeRouter02(ROUTER).WETH();
        s.c.pair = address(IPancakeFactory(FACTORY).createPair(s.c.topcorn, s.c.wbnb));
        s.c.pegPair = C.getPegPair();

        ITopcorn(s.c.topcorn).approve(ROUTER, type(uint256).max);
        IPancakePair(s.c.pair).approve(ROUTER, type(uint256).max);
        IWBNB(s.c.wbnb).approve(ROUTER, type(uint256).max);

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

        s.season.rewardMultiplier = C.getRewardMultiplier();
        s.season.maxTimeMultiplier = C.getMaxTimeMultiplier();
        // ~ gas limit for sunrice function
        s.season.costSunrice = 400000;
        s.season.current = 1;
        s.season.withdrawSeasons = 25;
        s.season.period = C.getSeasonPeriod();
        s.season.timestamp = block.timestamp;
        s.season.start = s.season.period > 0 ? (block.timestamp / s.season.period) * s.season.period : block.timestamp;

        s.index = (IPancakePair(s.c.pair).token0() == s.c.topcorn) ? 0 : 1;
        s.pegIndex = (IPancakePair(s.c.pegPair).token0() == BUSD) ? 0 : 1;
        LibMarket.initMarket(s.c.topcorn, s.c.wbnb, ROUTER);

        ITopcorn(s.c.topcorn).mint(msg.sender, C.getAdvanceIncentive());
        emit FirstIncentivization(msg.sender, C.getAdvanceIncentive());
    }
}
