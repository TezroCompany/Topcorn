/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/SeasonFacet/SeasonFacet.sol";
import "../../libraries/Decimal.sol";
import "../MockToken.sol";
import "../../libraries/LibIncentive.sol";

/**
 * @title Mock Season Facet
 **/
contract MockSeasonFacet is SeasonFacet {
    using Decimal for Decimal.D256;

    function reentrancyGuardTest() public nonReentrant {
        reentrancyGuardTest2();
    }

    function reentrancyGuardTest2() public nonReentrant {}

    function siloSunrise(uint256 amount) public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        mockStepSilo(amount);
    }

    function mockStepSilo(uint256 amount) public {
        if ((s.s.seeds == 0 && s.s.stalk == 0)) {
            stepSilo(0);
            return;
        }
        mintToSilo(amount);
        stepSilo(amount);
    }

    function rainSunrise() public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        handleRain(4);
    }

    function rainSiloSunrise(uint256 amount) public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        handleRain(4);
        mockStepSilo(amount);
    }

    function droughtSiloSunrise(uint256 amount) public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        handleRain(3);
        mockStepSilo(amount);
    }

    function sunSunrise(
        uint256 topcornPrice,
        uint256 busdPrice,
        uint256 divisor
    ) public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        uint256 siloReward = stepSun(Decimal.ratio(topcornPrice, divisor), Decimal.ratio(busdPrice, divisor));
        s.topcorn.deposited = s.topcorn.deposited + siloReward;
    }

    function lightSunrise() public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
    }

    function teleportSunrise(uint32 _s) public {
        s.season.current = _s;
    }

    function siloSunrises(uint256 number) public {
        require(!paused(), "Season: Paused.");
        for (uint256 i; i < number; i++) {
            s.season.current += 1;
            stepSilo(0);
        }
    }

    function governanceSunrise(uint256 amount) public {
        require(!paused(), "Season: Paused.");
        siloSunrise(amount);
    }

    function governanceSunrises(uint256 number) public {
        require(!paused(), "Season: Paused.");
        for (uint256 i; i < number; i++) {
            governanceSunrise(0);
        }
    }

    function farmSunrise() public {
        require(!paused(), "Season: Paused.");
        s.season.current += 1;
        s.season.timestamp = block.timestamp;
    }

    function farmSunrises(uint256 number) public {
        require(!paused(), "Season: Paused.");
        for (uint256 i; i < number; i++) {
            s.season.current += 1;
            s.season.timestamp = block.timestamp;
        }
    }

    function halfWeekSunrise() public {
        teleportSunrise(84);
        decrementWithdrawSeasons();
    }

    function weekSunrise() public {
        teleportSunrise(168);
        decrementWithdrawSeasons();
    }

    function decrementSunrise(uint256 week) public {
        for (uint256 i; i < week; i++) {
            weekSunrise();
        }
    }

    function setYieldE(uint32 number) public {
        s.w.yield = number;
    }

    function getRewardMultiplier() public view returns (uint256) {
        return s.season.rewardMultiplier;
    }

    function getMaxTimeMultiplier() public view returns (uint256) {
        return s.season.maxTimeMultiplier;
    }

    function setStartSoilE(uint256 number) public {
        s.w.startSoil = number;
    }

    function setLastDSoilE(uint256 number) public {
        s.w.lastDSoil = number;
    }

    function setNextSowTimeE(uint32 time) public {
        s.w.nextSowTime = time;
    }

    function setLastSowTimeE(uint32 number) public {
        s.w.lastSowTime = number;
    }

    function setSoilE(uint256 amount) public returns (int256) {
        return setSoil(amount);
    }

    function minSoil(uint256 amount) public view returns (uint256) {
        return getMinSoil(amount);
    }

    function setPodsE(uint256 amount) external {
        s.f.pods = amount;
    }

    function resetAccount(address account) public {
        uint32 _s = season();
        for (uint32 j; j <= _s; j++) {
            if (s.a[account].field.plots[j] > 0) s.a[account].field.plots[j];
            if (s.a[account].topcorn.deposits[j] > 0) delete s.a[account].topcorn.deposits[j];
            if (s.a[account].lp.deposits[j] > 0) delete s.a[account].lp.deposits[j];
            if (s.a[account].lp.depositSeeds[j] > 0) delete s.a[account].lp.depositSeeds[j];
            if (s.a[account].topcorn.withdrawals[j + C.getSiloWithdrawSeasons()] > 0) delete s.a[account].topcorn.withdrawals[j + C.getSiloWithdrawSeasons()];
            if (s.a[account].lp.withdrawals[j + C.getSiloWithdrawSeasons()] > 0) delete s.a[account].lp.withdrawals[j + C.getSiloWithdrawSeasons()];
        }
        delete s.a[account];
    }

    function resetState() public {
        uint32 _s = season();
        for (uint32 j; j <= _s; j++) delete s.sops[j];
        resetStateNoSeason();
    }

    function resetStateNoSeason() public {
        delete s.f;
        delete s.topcorn;
        delete s.lp;
        delete s.s;
        delete s.w;
        s.w.lastSowTime = type(uint32).max;
        s.w.nextSowTime = type(uint32).max;

        delete s.r;
        delete s.season;
        s.season.start = block.timestamp;
        s.season.timestamp = uint32(block.timestamp % 2**32);
        delete s.sop;
        s.s.stalk = 0;
        s.s.seeds = 0;
        s.season.withdrawSeasons = 25;
        s.season.current = 1;
        s.paused = false;
        topcorn().burn(topcorn().balanceOf(address(this)));
        ITopcorn(s.c.wbnb).burn(ITopcorn(s.c.wbnb).balanceOf(address(this)));
    }

    function stepWeatherE(uint256 intPrice, uint256 endSoil) external {
        stepWeather(intPrice * 1e16, endSoil);
    }

    function incentivizeReward(address account, uint256 price, uint256 incentiveTime, uint256 gasprice) external returns (uint256) {
        uint256 rewardMultiplier = s.season.rewardMultiplier;
        if (rewardMultiplier > 100) rewardMultiplier = 100;
        uint256 incentive = LibIncentive.fracExp(rewardMultiplier * 1e18, 100, incentiveTime, 1);
        uint256 feeInBnb = gasprice * s.season.costSunrice;
        uint256 amount = ((feeInBnb * 1e18) / price) + incentive;
        mintToAccount(account, amount);
        return amount;
    }

    function stepWeatherWithParams(
        uint256 pods,
        uint256 lastDSoil,
        uint256 startSoil,
        uint256 endSoil,
        uint256 intPrice,
        bool raining,
        bool rainRoots
    ) public {
        s.r.raining = raining;
        s.r.roots = rainRoots ? 1 : 0;
        s.f.pods = pods;
        s.w.lastDSoil = lastDSoil;
        s.w.startSoil = startSoil;
        stepWeather(intPrice * 1e16, endSoil);
    }
}
