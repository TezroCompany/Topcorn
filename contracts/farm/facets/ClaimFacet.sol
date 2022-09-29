/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../AppStorage.sol";
import "../../libraries/LibCheck.sol";
import "../../libraries/LibInternal.sol";
import "../../libraries/LibMarket.sol";
import "../../libraries/LibClaim.sol";
import "../ReentrancyGuard.sol";

/**
 * @title Claim handles claiming TopCorn and LP withdrawals, harvesting plots and claiming BNB.
 **/
contract ClaimFacet is ReentrancyGuard {
    event TopcornClaim(address indexed account, uint32[] withdrawals, uint256 topcorns);
    event LPClaim(address indexed account, uint32[] withdrawals, uint256 lp);
    event BnbClaim(address indexed account, uint256 bnb);
    event Harvest(address indexed account, uint256[] plots, uint256 topcorns);
    event TopcornAllocation(address indexed account, uint256 topcorns);

    function claim(LibClaim.Claim calldata c) external payable nonReentrant returns (uint256 topcornsClaimed) {
        topcornsClaimed = LibClaim.claim(c);
        LibMarket.claimRefund(c);
        LibCheck.balanceCheck();
    }

    function claimAndUnwrapTopcorns(LibClaim.Claim calldata c, uint256 amount) external payable nonReentrant returns (uint256 topcornsClaimed) {
        topcornsClaimed = LibClaim.claim(c);
        topcornsClaimed = topcornsClaimed + (_unwrapTopcorns(amount));
        LibMarket.claimRefund(c);
        LibCheck.balanceCheck();
    }

    function claimTopcorns(uint32[] calldata withdrawals) external {
        uint256 topcornsClaimed = LibClaim.claimTopcorns(withdrawals);
        ITopcorn(s.c.topcorn).transfer(msg.sender, topcornsClaimed);
        LibCheck.topcornBalanceCheck();
    }

    function claimLP(uint32[] calldata withdrawals) external {
        LibClaim.claimLP(withdrawals);
        LibCheck.lpBalanceCheck();
    }

    function removeAndClaimLP(
        uint32[] calldata withdrawals,
        uint256 minTopcornAmount,
        uint256 minBNBAmount
    ) external nonReentrant {
        LibClaim.removeAndClaimLP(withdrawals, minTopcornAmount, minBNBAmount);
        LibCheck.balanceCheck();
    }

    function harvest(uint256[] calldata plots) external {
        uint256 topcornsHarvested = LibClaim.harvest(plots);
        ITopcorn(s.c.topcorn).transfer(msg.sender, topcornsHarvested);
        LibCheck.topcornBalanceCheck();
    }

    function claimBnb() external {
        LibClaim.claimBnb();
    }

    function unwrapTopcorns(uint256 amount) external returns (uint256 topcornsToWallet) {
        return _unwrapTopcorns(amount);
    }

    function _unwrapTopcorns(uint256 amount) private returns (uint256 topcornsToWallet) {
        if (amount == 0) return topcornsToWallet;
        uint256 wTopcorns = s.a[msg.sender].wrappedTopcorns;

        if (amount > wTopcorns) {
            ITopcorn(s.c.topcorn).transfer(msg.sender, wTopcorns);
            topcornsToWallet = s.a[msg.sender].wrappedTopcorns;
            s.a[msg.sender].wrappedTopcorns = 0;
        } else {
            ITopcorn(s.c.topcorn).transfer(msg.sender, amount);
            s.a[msg.sender].wrappedTopcorns = wTopcorns - (amount);
            topcornsToWallet = amount;
        }
    }

    function wrapTopcorns(uint256 amount) external {
        ITopcorn(s.c.topcorn).transferFrom(msg.sender, address(this), amount);
        s.a[msg.sender].wrappedTopcorns = s.a[msg.sender].wrappedTopcorns + (amount);
    }

    function wrappedTopcorns(address user) external view returns (uint256) {
        return s.a[user].wrappedTopcorns;
    }
}
