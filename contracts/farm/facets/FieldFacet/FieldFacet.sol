/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "./TopcornDibbler.sol";
import "../../../libraries/LibClaim.sol";

/**
 * @title Field sows Topcorns.
 **/
contract FieldFacet is TopcornDibbler {
    using Decimal for Decimal.D256;

    /**
     * Sow
     **/

    // Claim and Sow Topcorns

    /// @notice Performs a claim, then transfers allocates the topcorns to the user wallet, then sows the desired number of topcorns ()
    /// @param amount amount of topcorns to sow
    /// @param claim parameters struct for claiming tokens withdrawn from the silo
    /// @return pods amount of pods that were received
    function claimAndSowTopcorns(uint256 amount, LibClaim.Claim calldata claim) external nonReentrant returns (uint256 pods) {
        return _claimAndSowTopcornsWithMin(amount, amount, claim);
    }

    function claimAndSowTopcornsWithMin(
        uint256 amount,
        uint256 minAmount,
        LibClaim.Claim calldata claim
    ) external nonReentrant returns (uint256 pods) {
        return _claimAndSowTopcornsWithMin(amount, minAmount, claim);
    }

    function _claimAndSowTopcornsWithMin(
        uint256 amount,
        uint256 minAmount,
        LibClaim.Claim calldata claim
    ) private returns (uint256 pods) {
        amount = getSowAmount(amount, minAmount);
        allocateTopcorns(claim, amount);
        pods = _sowTopcorns(amount, false);
        LibMarket.claimRefund(claim);
    }

    // Claim, Buy and Sow Topcorns

    /// @notice Performs a claim, then transfers allocates the topcorns to the user wallet. Subsequently, it buys the specified number of topcorns and immediately deposits those topcorns in the silo, then sows the desired number of topcorns
    /// @param amount amount of topcorns to sow
    /// @param buyAmount amount of topcorns to buy
    /// @param claim parameters struct for claiming tokens withdrawn from the silo
    /// @return pods amount of pods that were received
    function claimBuyAndSowTopcorns(
        uint256 amount,
        uint256 buyAmount,
        LibClaim.Claim calldata claim
    ) external payable nonReentrant returns (uint256 pods) {
        return _claimBuyAndSowTopcornsWithMin(amount, buyAmount, amount + buyAmount, claim);
    }

    function claimBuyAndSowTopcornsWithMin(
        uint256 amount,
        uint256 buyAmount,
        uint256 minAmount,
        LibClaim.Claim calldata claim
    ) external payable nonReentrant returns (uint256 pods) {
        return _claimBuyAndSowTopcornsWithMin(amount, buyAmount, minAmount, claim);
    }

    function _claimBuyAndSowTopcornsWithMin(
        uint256 amount,
        uint256 buyAmount,
        uint256 minAmount,
        LibClaim.Claim calldata claim
    ) private returns (uint256 pods) {
        uint256 bnbAmount;
        (amount, buyAmount, bnbAmount) = getBuyAndSowAmount(amount, buyAmount, minAmount, msg.value);
        allocateTopcorns(claim, amount);
        uint256 boughtAmount = LibMarket.buyAndSow(buyAmount, bnbAmount);
        pods = _sowTopcorns(boughtAmount + amount, false);
        LibMarket.refund();
    }

    // Sow Topcorns

    /// @notice Sows the specified number of topcorns
    /// @param amount amount of topcorns to sow
    /// @return uint256 amount of pods that were received
    function sowTopcorns(uint256 amount) external returns (uint256) {
        return sowTopcornsWithMin(amount, amount);
    }

    function sowTopcornsWithMin(uint256 amount, uint256 minAmount) public returns (uint256) {
        amount = getSowAmount(amount, minAmount);
        return _sowTopcorns(amount, true);
    }

    // Buy and Sow Topcorns

    /// @notice Buys the specified number of topcorns and immediately deposits those topcorns in the silo, then sows the desired number of topcorns.
    /// @param amount amount of topcorns to sow
    /// @param buyAmount amount of topcorns to buy
    /// @return pods amount of pods that were received
    function buyAndSowTopcorns(uint256 amount, uint256 buyAmount) external payable nonReentrant returns (uint256 pods) {
        return _buyAndSowTopcornsWithMin(amount, buyAmount, amount + buyAmount);
    }

    function buyAndSowTopcornsWithMin(
        uint256 amount,
        uint256 buyAmount,
        uint256 minAmount
    ) external payable nonReentrant returns (uint256 pods) {
        return _buyAndSowTopcornsWithMin(amount, buyAmount, minAmount);
    }

    function _buyAndSowTopcornsWithMin(
        uint256 amount,
        uint256 buyAmount,
        uint256 minAmount
    ) private returns (uint256 pods) {
        uint256 bnbAmount;
        (amount, buyAmount, bnbAmount) = getBuyAndSowAmount(amount, buyAmount, minAmount, msg.value);
        uint256 boughtAmount = LibMarket.buyAndSow(buyAmount, bnbAmount);
        if (amount > 0) topcorn().transferFrom(msg.sender, address(this), amount);
        pods = _sowTopcorns(boughtAmount + amount, false);
        LibMarket.refund();
    }

    // Helpers

    /// @notice Performs a claim. It then allocates the desired number of topcorns to the users wallet.
    /// @param c parameters struct for claiming tokens withdrawn from the silo
    /// @param transferTopcorns number of topcorns to allocate to the user wallet
    function allocateTopcorns(LibClaim.Claim calldata c, uint256 transferTopcorns) private {
        LibClaim.claim(c);
        LibMarket.allocateTopcorns(transferTopcorns);
    }

    function getSowAmount(uint256 amount, uint256 minAmount) private view returns (uint256 maxSowAmount) {
        maxSowAmount = s.f.soil;
        require(maxSowAmount >= minAmount && amount >= minAmount && minAmount > 0, "Field: Sowing below min or 0 pods.");
        if (amount < maxSowAmount) return amount;
    }

    function getBuyAndSowAmount(
        uint256 amount,
        uint256 buyAmount,
        uint256 minAmount,
        uint256 bnbAmount
    )
        private
        view
        returns (
            uint256 maxSowAmount,
            uint256 sowBuyAmount,
            uint256 sowBNBAmount
        )
    {
        maxSowAmount = s.f.soil;
        require(maxSowAmount >= minAmount && amount + buyAmount >= minAmount && minAmount > 0, "Field: Sowing below min or 0 pods.");
        if (amount + buyAmount <= maxSowAmount) return (amount, buyAmount, bnbAmount);
        if (amount < maxSowAmount) {
            sowBuyAmount = maxSowAmount - amount;
            sowBNBAmount = ((bnbAmount - 1) * sowBuyAmount) / buyAmount + 1;
            return (amount, sowBuyAmount, sowBNBAmount);
        }
    }
}
