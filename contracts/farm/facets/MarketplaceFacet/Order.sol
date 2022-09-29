/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "./Listing.sol";

/**
 * @title Pod Marketplace v1
 **/
contract Order is Listing {
    struct PodOrder {
        address account;
        uint24 pricePerPod;
        uint256 maxPlaceInLine;
    }

    event PodOrderCreated(address indexed account, bytes32 orderId, uint256 amount, uint24 pricePerPod, uint256 maxPlaceInLine);
    event PodOrderFilled(address indexed from, address indexed to, bytes32 orderId, uint256 index, uint256 start, uint256 amount);
    event PodOrderCancelled(address indexed account, bytes32 orderId);

    /*
     * Create
     */
     
    /// @notice Internal function for buying topcorns on behalf of the pod orderer and then adding that topcorn amount to the created pod order.
    /// @param topcornAmount amount of pods in topcorns for pod order
    /// @param buyTopcornAmount amount of topcorns to buy and use for pod order
    /// @param pricePerPod price per pod
    /// @param maxPlaceInLine maximum place in pod line to place an order for
    /// @return id id of the newly created pod order
    function _buyTopcornsAndCreatePodOrder(
        uint256 topcornAmount,
        uint256 buyTopcornAmount,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) internal returns (bytes32 id) {
        uint256 boughtTopcornAmount = LibMarket.buyExactTokens(buyTopcornAmount, address(this));
        id = _createPodOrder(topcornAmount + boughtTopcornAmount, pricePerPod, maxPlaceInLine);
        LibMarket.refund();
    }

    /// @notice Internal function that handles the calculation of the pods to order amount and calls the internal function #__createPodOrder.
    /// @param topcornAmount amount of pods in topcorns for pod order
    /// @param pricePerPod price per pod
    /// @param maxPlaceInLine maximum place in pod line to place an order for
    /// @return id id of the newly created pod order
    function _createPodOrder(
        uint256 topcornAmount,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) internal returns (bytes32 id) {
        require(0 < pricePerPod, "Marketplace: Pod price must be greater than 0.");
        uint256 amount = (topcornAmount * 1e6) / pricePerPod;
        return __createPodOrder(amount, pricePerPod, maxPlaceInLine);
    }

    /// @notice Internal function that handles the business logic of the creation and storage of a pod order within the Farmer ecosystem.
    /// @param amount amount of pods for pod order
    /// @param pricePerPod price per pod
    /// @param maxPlaceInLine maximum place in pod line to place an order for
    /// @return id id of the newly created pod order
    function __createPodOrder(
        uint256 amount,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) internal returns (bytes32 id) {
        require(amount > 0, "Marketplace: Order amount must be > 0.");
        id = createOrderId(msg.sender, pricePerPod, maxPlaceInLine);
        if (s.podOrders[id] > 0) _cancelPodOrder(pricePerPod, maxPlaceInLine, false);
        s.podOrders[id] = amount;
        emit PodOrderCreated(msg.sender, id, amount, pricePerPod, maxPlaceInLine);
    }

    /*
     * Fill
     */

    /// @notice Internal function that handles the business logic of the fill/completion of a Pod Order through the transfer of the payment in topcorns to the Pod Lister and the transfer in pods to the Pod Orderer.
    /// @param o Order object with inputs for a pod order fill
    /// @param index plot id index for the pod order to be filled with
    /// @param start  	starting pod plot spot for this order fill
    /// @param amount amount of pods to fill with
    /// @param toWallet optional boolean to transfer pods to wallet or keep as wrapped
    function _fillPodOrder(
        PodOrder calldata o,
        uint256 index,
        uint256 start,
        uint256 amount,
        bool toWallet
    ) internal {
        bytes32 id = createOrderId(o.account, o.pricePerPod, o.maxPlaceInLine);
        s.podOrders[id] = s.podOrders[id] - amount;
        require(s.a[msg.sender].field.plots[index] >= (start + amount), "Marketplace: Invalid Plot.");
        uint256 placeInLineEndPlot = index + start + amount - s.f.harvestable;
        require(placeInLineEndPlot <= o.maxPlaceInLine, "Marketplace: Plot too far in line.");
        uint256 costInTopcorns = (o.pricePerPod * amount) / 1e6;
        if (toWallet) topcorn().transfer(msg.sender, costInTopcorns);
        else s.a[msg.sender].wrappedTopcorns = s.a[msg.sender].wrappedTopcorns + costInTopcorns;
        if (s.podListings[index] != bytes32(0)) {
            _cancelPodListing(msg.sender, index);
        }
        _transferPlot(msg.sender, o.account, index, start, amount);
        if (s.podOrders[id] == 0) {
            delete s.podOrders[id];
        }
        emit PodOrderFilled(msg.sender, o.account, id, index, start, amount);
    }

    /*
     * Cancel
     */

    /// @notice Internal function for canceling the pod order and removing it from storage.
    /// @param pricePerPod price per pod
    /// @param maxPlaceInLine maximum place in pod line to of the order to cancel
    /// @param toWallet optional boolean to transfer pods to wallet or keep as wrapped
    function _cancelPodOrder(
        uint24 pricePerPod,
        uint256 maxPlaceInLine,
        bool toWallet
    ) internal {
        bytes32 id = createOrderId(msg.sender, pricePerPod, maxPlaceInLine);
        uint256 amountTopcorns = (pricePerPod * s.podOrders[id]) / 1e6;
        if (toWallet) topcorn().transfer(msg.sender, amountTopcorns);
        else s.a[msg.sender].wrappedTopcorns = s.a[msg.sender].wrappedTopcorns + amountTopcorns;
        delete s.podOrders[id];
        emit PodOrderCancelled(msg.sender, id);
    }

    /*
     * Helpers
     */

    /// @notice Internal function that hashes a Pod Order and thus creates a order id for it. This returns that bytes32 hash as an id.
    /// @param account address of the pod orderer account
    /// @param pricePerPod price per pod
    /// @param maxPlaceInLine maximum place in pod line for the order
    /// @return id of the newly created pod order
    function createOrderId(
        address account,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) internal pure returns (bytes32 id) {
        id = keccak256(abi.encodePacked(account, pricePerPod, maxPlaceInLine));
    }
}
