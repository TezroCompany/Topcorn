/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/SiloFacet/SiloFacet.sol";
import "../MockPancakeswapV2Pair.sol";

/**
 * @title Mock Silo Facet
 **/
contract MockSiloFacet is SiloFacet {
    function depositSiloAssetsE(
        address account,
        uint256 base,
        uint256 amount
    ) public {
        updateSilo(account);
        LibSilo.depositSiloAssets(account, base, amount);
    }

    function incrementDepositedLPE(uint256 amount) public {
        LibLPSilo.incrementDepositedLP(amount);
        MockPancakeswapV2Pair(s.c.pair).faucet(address(this), amount);
    }

    function incrementDepositedTopcornsE(uint256 amount) public {
        s.topcorn.deposited = s.topcorn.deposited + amount;
    }

    function withdrawSiloAssetsE(
        address account,
        uint256 base,
        uint256 amount
    ) public {
        updateSilo(account);
        LibSilo.withdrawSiloAssets(account, base, amount);
    }

    function balanceOfDepositedTopcorns(address account) public view returns (uint256) {
        uint256 topcorns = 0;
        for (uint32 i; i <= season(); i++) {
            topcorns = topcorns + s.a[account].topcorn.deposits[i];
        }
        return topcorns;
    }

    function balanceOfDepositedLP(address account) public view returns (uint256) {
        uint256 topcorns = 0;
        for (uint32 i; i <= season(); i++) {
            topcorns = topcorns + s.a[account].lp.deposits[i];
        }
        return topcorns;
    }

    function balanceOfRootStalk(address account) public view returns (uint256) {
        if (s.s.roots == 0) return 0;
        return (s.a[account].roots * s.s.stalk) / s.s.roots;
    }

    function balanceOfRawStalk(address account) public view returns (uint256) {
        return s.a[account].s.stalk;
    }

    function topcornDeposits(address account) public view returns (uint32[] memory seasons, uint256[] memory crates) {
        uint256 numberCrates = 0;
        for (uint32 i; i <= season(); i++) {
            if (topcornDeposit(account, i) > 0) numberCrates += 1;
        }
        seasons = new uint32[](numberCrates);
        crates = new uint256[](numberCrates);
        numberCrates = 0;
        for (uint32 i; i <= season(); i++) {
            if (topcornDeposit(account, i) > 0) {
                seasons[numberCrates] = i;
                crates[numberCrates] = topcornDeposit(account, i);
                numberCrates += 1;
            }
        }
        return (seasons, crates);
    }

    function lpDeposits(address account)
        public
        view
        returns (
            uint32[] memory seasons,
            uint256[] memory crates,
            uint256[] memory seedCrates
        )
    {
        uint256 numberCrates;
        for (uint32 i; i <= season(); i++) {
            if (s.a[account].lp.deposits[i] > 0) numberCrates += 1;
        }
        seasons = new uint32[](numberCrates);
        crates = new uint256[](numberCrates);
        seedCrates = new uint256[](numberCrates);
        numberCrates = 0;
        for (uint32 i; i <= season(); i++) {
            if (s.a[account].lp.deposits[i] > 0) {
                seasons[numberCrates] = i;
                crates[numberCrates] = s.a[account].lp.deposits[i];
                seedCrates[numberCrates] = s.a[account].lp.depositSeeds[i];
                numberCrates += 1;
            }
        }
        return (seasons, crates, seedCrates);
    }

    function topcornWithdrawals(address account) public view returns (uint32[] memory seasons, uint256[] memory crates) {
        uint256 numberCrates;
        for (uint32 i; i <= season() + 25; i++) {
            if (s.a[account].topcorn.withdrawals[i] > 0) numberCrates += 1;
        }
        seasons = new uint32[](numberCrates);
        crates = new uint256[](numberCrates);
        numberCrates = 0;
        for (uint32 i; i <= season() + 25; i++) {
            if (s.a[account].topcorn.withdrawals[i] > 0) {
                seasons[numberCrates] = i;
                crates[numberCrates] = s.a[account].topcorn.withdrawals[i];
                numberCrates += 1;
            }
        }
        return (seasons, crates);
    }

    function lpWithdrawals(address account) public view returns (uint32[] memory seasons, uint256[] memory crates) {
        uint256 numberCrates;
        for (uint32 i; i <= season() + 25; i++) {
            if (s.a[account].lp.withdrawals[i] > 0) numberCrates += 1;
        }
        seasons = new uint32[](numberCrates);
        crates = new uint256[](numberCrates);
        numberCrates = 0;
        for (uint32 i; i <= season() + 25; i++) {
            if (s.a[account].lp.withdrawals[i] > 0) {
                seasons[numberCrates] = i;
                crates[numberCrates] = s.a[account].lp.withdrawals[i];
                numberCrates += 1;
            }
        }
        return (seasons, crates);
    }

    function uniswapLPToTopcorn(uint256 amount) external view returns (uint256) {
        return LibTopcornBnb.lpToLPTopcorns(amount);
    }

    function mockRefund(uint256 topcorn) external payable {
        LibMarket.allocateBNBRefund(msg.value, 0, false);
        ITopcorn(s.c.topcorn).transferFrom(msg.sender, address(this), topcorn);
        LibMarket.allocateTopcornRefund(topcorn, 0);
        LibMarket.refund();
    }
}
