/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../../../libraries/Silo/LibSilo.sol";
import "../../ReentrancyGuard.sol";
import "../../../libraries/Silo/LibTopcornSilo.sol";
import "../../../libraries/Silo/LibLPSilo.sol";
import "../../../libraries/LibCheck.sol";
import "../../../libraries/LibMarket.sol";
import "../../../C.sol";
import "../../../libraries/LibTopcornBnb.sol";

/**
 * @title TopCorn Silo
 **/
contract ConvertSilo is ReentrancyGuard {
    event LPDeposit(address indexed account, uint256 season, uint256 lp, uint256 seeds);
    event LPRemove(address indexed account, uint32[] crates, uint256[] crateLP, uint256 lp, uint256 stalkRemoved, uint256 seedsRemoved);
    event TopcornRemove(address indexed account, uint32[] crates, uint256[] crateTopcorns, uint256 topcorns, uint256 stalkRemoved, uint256 seedsRemoved);

    struct WithdrawState {
        uint256 newLP;
        uint256 topcornsAdded;
        uint256 topcornsTransferred;
        uint256 topcornsRemoved;
        uint256 stalkRemoved;
        uint256 i;
    }

    function _convertAddAndDepositLP(
        uint256 lp,
        LibMarket.AddLiquidity calldata al,
        uint32[] memory crates,
        uint256[] memory amounts
    ) internal {
        WithdrawState memory w;
        if (topcorn().balanceOf(address(this)) < al.topcornAmount) {
            w.topcornsTransferred = al.topcornAmount - s.topcorn.deposited;
            topcorn().transferFrom(msg.sender, address(this), w.topcornsTransferred);
        }
        (w.topcornsAdded, w.newLP) = LibMarket.addLiquidity(al); // w.topcornsAdded is topcorns added to LP
        require(w.newLP > 0, "Silo: No LP added.");
        (w.topcornsRemoved, w.stalkRemoved) = _withdrawTopcornsForConvert(crates, amounts, w.topcornsAdded); // w.topcornsRemoved is topcorns removed from Silo
        require(w.topcornsAdded >= w.topcornsRemoved, "Silo: Removed too many Topcorns.");
        uint256 amountFromWallet = w.topcornsAdded - w.topcornsRemoved;

        if (amountFromWallet < w.topcornsTransferred) {
            topcorn().transfer(msg.sender, w.topcornsTransferred - amountFromWallet);
        } else if (w.topcornsTransferred < amountFromWallet) {
            uint256 transferAmount = amountFromWallet - w.topcornsTransferred;
            LibMarket.allocateTopcorns(transferAmount);
        }

        require(LibTopcornBnb.lpToLPTopcorns(lp + w.newLP) > 0, "Silo: No LP Topcorns.");
        w.i = w.stalkRemoved / (LibTopcornBnb.lpToLPTopcorns(lp + w.newLP));
        uint32 depositSeason = season() - uint32(w.i / C.getSeedsPerLP());

        if (lp > 0) pair().transferFrom(msg.sender, address(this), lp);

        lp = lp + w.newLP;
        _depositLP(lp, LibTopcornBnb.lpToLPTopcorns(lp), depositSeason);
        LibSilo.updateBalanceOfRainStalk(msg.sender);
        LibMarket.refund();
        LibCheck.balanceCheck();
    }

    /**
     * Internal LP
     **/
    function _depositLP(
        uint256 amount,
        uint256 lpb,
        uint32 _s
    ) internal {
        require(lpb > 0, "Silo: No Topcorns under LP.");
        LibLPSilo.incrementDepositedLP(amount);
        uint256 seeds = lpb * C.getSeedsPerLP();
        if (season() == _s) LibSilo.depositSiloAssets(msg.sender, seeds, lpb * C.getStalkPerTopcorn());
        else LibSilo.depositSiloAssets(msg.sender, seeds, (lpb * C.getStalkPerTopcorn()) + (uint256(season() - _s) * (seeds)));

        LibLPSilo.addLPDeposit(msg.sender, _s, amount, lpb * (C.getSeedsPerLP()));
    }

    function _withdrawLPForConvert(
        uint32[] memory crates,
        uint256[] memory amounts,
        uint256 maxLP
    ) internal returns (uint256 lpRemoved, uint256 stalkRemoved) {
        require(crates.length == amounts.length, "Silo: Crates, amounts are diff lengths.");
        uint256 seedsRemoved;
        uint256 depositLP;
        uint256 depositSeeds;
        uint256 i = 0;
        while ((i < crates.length) && (lpRemoved < maxLP)) {
            if (lpRemoved + amounts[i] < maxLP) (depositLP, depositSeeds) = LibLPSilo.removeLPDeposit(msg.sender, crates[i], amounts[i]);
            else (depositLP, depositSeeds) = LibLPSilo.removeLPDeposit(msg.sender, crates[i], maxLP - lpRemoved);
            lpRemoved = lpRemoved + depositLP;
            seedsRemoved = seedsRemoved + depositSeeds;
            stalkRemoved = stalkRemoved + (depositSeeds * (C.getStalkPerLPSeed()) + (LibSilo.stalkReward(depositSeeds, season() - crates[i])));
            i++;
        }
        if (i > 0) amounts[i - 1] = depositLP;
        while (i < crates.length) {
            amounts[i] = 0;
            i++;
        }
        LibLPSilo.decrementDepositedLP(lpRemoved);
        LibSilo.withdrawSiloAssets(msg.sender, seedsRemoved, stalkRemoved);
        stalkRemoved = stalkRemoved - (seedsRemoved * C.getStalkPerLPSeed());
        emit LPRemove(msg.sender, crates, amounts, lpRemoved, stalkRemoved, seedsRemoved);
    }

    /**
     * Internal TopCorn
     **/

    function _depositTopcorns(uint256 amount, uint32 _s) internal {
        require(amount > 0, "Silo: No topcorns.");
        LibTopcornSilo.incrementDepositedTopcorns(amount);
        uint256 stalk = amount * C.getStalkPerTopcorn();
        uint256 seeds = amount * C.getSeedsPerTopcorn();
        if (_s < season()) stalk = stalk + (LibSilo.stalkReward(seeds, season() - _s));
        LibSilo.depositSiloAssets(msg.sender, seeds, stalk);
        LibTopcornSilo.addTopcornDeposit(msg.sender, _s, amount);
    }

    function _withdrawTopcornsForConvert(
        uint32[] memory crates,
        uint256[] memory amounts,
        uint256 maxTopcorns
    ) internal returns (uint256 topcornsRemoved, uint256 stalkRemoved) {
        require(crates.length == amounts.length, "Silo: Crates, amounts are diff lengths.");
        uint256 crateTopcorns;
        uint256 i = 0;
        while ((i < crates.length) && (topcornsRemoved < maxTopcorns)) {
            if (topcornsRemoved + amounts[i] < maxTopcorns) crateTopcorns = LibTopcornSilo.removeTopcornDeposit(msg.sender, crates[i], amounts[i]);
            else crateTopcorns = LibTopcornSilo.removeTopcornDeposit(msg.sender, crates[i], maxTopcorns - topcornsRemoved);
            topcornsRemoved = topcornsRemoved + crateTopcorns;
            stalkRemoved = stalkRemoved + (crateTopcorns * C.getStalkPerTopcorn() + (LibSilo.stalkReward(crateTopcorns * C.getSeedsPerTopcorn(), season() - crates[i])));
            i++;
        }
        if (i > 0) amounts[i - 1] = crateTopcorns;
        while (i < crates.length) {
            amounts[i] = 0;
            i++;
        }
        LibTopcornSilo.decrementDepositedTopcorns(topcornsRemoved);
        uint256 seedsRemoved = topcornsRemoved * C.getSeedsPerTopcorn();
        LibSilo.withdrawSiloAssets(msg.sender, seedsRemoved, stalkRemoved);
        stalkRemoved = stalkRemoved - (topcornsRemoved * C.getStalkPerTopcorn());
        emit TopcornRemove(msg.sender, crates, amounts, topcornsRemoved, stalkRemoved, seedsRemoved);
        return (topcornsRemoved, stalkRemoved);
    }

    function reserves() internal view returns (uint256, uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair().getReserves();
        return s.index == 0 ? (reserve1, reserve0) : (reserve0, reserve1);
    }

    function pair() internal view returns (IPancakePair) {
        return IPancakePair(s.c.pair);
    }

    function topcorn() internal view returns (ITopcorn) {
        return ITopcorn(s.c.topcorn);
    }

    function season() internal view returns (uint32) {
        return s.season.current;
    }
}
