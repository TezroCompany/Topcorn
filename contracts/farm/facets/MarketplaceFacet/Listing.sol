/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../../../libraries/LibMarket.sol";
import "./PodTransfer.sol";

/**
 * @title Pod Marketplace v1
 **/
contract Listing is PodTransfer {
    struct PodListing {
        address account;
        uint256 index;
        uint256 start;
        uint256 amount;
        uint24 pricePerPod;
        uint256 maxHarvestableIndex;
        bool toWallet;
    }

    event PodListingCreated(address indexed account, uint256 index, uint256 start, uint256 amount, uint24 pricePerPod, uint256 maxHarvestableIndex, bool toWallet);
    event PodListingFilled(address indexed from, address indexed to, uint256 index, uint256 start, uint256 amount);
    event PodListingCancelled(address indexed account, uint256 index);

    /*
     * Create
     */

    /// @notice Internal function for creating a pod listing and properly storing it securely within the Farm ecosystem.
    /// @param index plot id index for storage
    /// @param start starting pod plot spot for this listing
    /// @param amount  	amount of pods to list
    /// @param pricePerPod price per pod
    /// @param maxHarvestableIndex index for maximum amount that is harvestable
    /// @param toWallet optional boolean to transfer pods to wallet or keep as wrapped
    function _createPodListing(
        uint256 index,
        uint256 start,
        uint256 amount,
        uint24 pricePerPod,
        uint256 maxHarvestableIndex,
        bool toWallet
    ) internal {
        uint256 plotSize = s.a[msg.sender].field.plots[index];
        require(plotSize >= start + amount && amount > 0, "Marketplace: Invalid Plot/Amount.");
        require(0 < pricePerPod, "Marketplace: Pod price must be greater than 0.");
        require(s.f.harvestable <= maxHarvestableIndex, "Marketplace: Expired.");

        if (s.podListings[index] != bytes32(0)) _cancelPodListing(msg.sender, index);

        s.podListings[index] = hashListing(start, amount, pricePerPod, maxHarvestableIndex, toWallet);

        emit PodListingCreated(msg.sender, index, start, amount, pricePerPod, maxHarvestableIndex, toWallet);
    }

    /*
     * Fill
     */

    /// @notice Internal function that handles the fill aka completion of pod listings through the transfer of the plots to the list buying account
    /// @param l listing object with the current parameters for this pod listing
    /// @param topcornAmount amount of topcorns for pod listing
    /// @param buyTopcornAmount amount of topcorns to buy and add in pods to pod listing
    function _buyTopcornsAndFillPodListing(
        PodListing calldata l,
        uint256 topcornAmount,
        uint256 buyTopcornAmount
    ) internal {
        uint256 boughtTopcornAmount = LibMarket.buyExactTokensToWallet(buyTopcornAmount, l.account, l.toWallet);
        _fillListing(l, topcornAmount + boughtTopcornAmount);
        LibMarket.refund();
    }

    /// @notice Internal function that handles the security checks for the list filling and calls the appropriate functions for the business logic of updating the storage of the plot listing and plot transferring.
    /// @param l listing object with the current parameters for this pod listing
    /// @param topcornAmount amount of topcorns for pod listing fill
    function _fillListing(PodListing calldata l, uint256 topcornAmount) internal {
        bytes32 lHash = hashListing(l.start, l.amount, l.pricePerPod, l.maxHarvestableIndex, l.toWallet);
        require(s.podListings[l.index] == lHash, "Marketplace: Listing does not exist.");
        uint256 plotSize = s.a[l.account].field.plots[l.index];
        require(plotSize >= (l.start + l.amount) && l.amount > 0, "Marketplace: Invalid Plot/Amount.");
        require(s.f.harvestable <= l.maxHarvestableIndex, "Marketplace: Listing has expired.");

        uint256 amount = (topcornAmount * 1e6) / l.pricePerPod;
        amount = roundAmount(l, amount);

        __fillListing(msg.sender, l, amount);
        _transferPlot(l.account, msg.sender, l.index, l.start, amount);
    }

    /// @notice Private function that updates the storage of the pod listings to reflect this fill.
    /// @param to () 
    /// @param l listing object with the current parameters for this pod listing
    /// @param amount amount of topcorns for pod listing
    function __fillListing(
        address to,
        PodListing calldata l,
        uint256 amount
    ) private {
        require(l.amount >= amount, "Marketplace: Not enough pods in Listing.");

        if (l.amount > amount) s.podListings[l.index + amount + l.start] = hashListing(0, l.amount - amount, l.pricePerPod, l.maxHarvestableIndex, l.toWallet);
        emit PodListingFilled(l.account, to, l.index, l.start, amount);
        delete s.podListings[l.index];
    }

    /*
     * Cancel
     */

    /// @notice Internal function for removing and canceling a pod listing.
    /// @param index lplot id index for storage
    function _cancelPodListing(address account, uint256 index) internal {
        require(s.a[account].field.plots[index] > 0, "Marketplace: Listing not owned by sender.");
        delete s.podListings[index];
        emit PodListingCancelled(account, index);
    }

    /*
     * Helpers
     */

    // If remainder left (always <1 pod) that would otherwise be unpurchaseable
    // due to rounding from calculating amount, give it to last buyer
    /// @notice Private helper function to check if there is a listing remainder left (always <1 pod) that would otherwise be unpurchaseable. So due to rounding from calculating amount, we give it to last buyer. This returns that rounded amount.
    /// @param l listing object with the current parameters for this pod listing
    /// @param amount amount of topcorns for pod listing fill
    /// @return uint256 rounded amount of topcorns for pod listing fill
    function roundAmount(PodListing calldata l, uint256 amount) private pure returns (uint256) {
        require(l.amount >= amount, "Marketplace: Not enough pods in Listing.");
        uint256 remainingAmount = l.amount - amount;
        if (remainingAmount < (1e6 / l.pricePerPod)) amount = l.amount;
        return amount;
    }

    /// @notice Internal function that hashes this listing for security purposes and double spending prevention. This returns the resulting hash.
    /// @param start starting pod plot spot for this listing
    /// @param amount amount of pods to list
    /// @param pricePerPod price per pod
    /// @param maxHarvestableIndex index for maximum amount that is harvestable
    /// @param toWallet optional boolean to transfer pods to wallet or keep as wrapped
    /// @return lHash hash of the pod listing
    function hashListing(
        uint256 start,
        uint256 amount,
        uint24 pricePerPod,
        uint256 maxHarvestableIndex,
        bool toWallet
    ) internal pure returns (bytes32 lHash) {
        lHash = keccak256(abi.encodePacked(start, amount, pricePerPod, maxHarvestableIndex, toWallet));
    }
}
