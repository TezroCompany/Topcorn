/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "./Order.sol";

/**
 * @title Pod Marketplace v1
 **/
contract MarketplaceFacet is Order {
    /*
     * Pod Listing
     */

    // Create
    // Note: pricePerPod is bounded by 16_777_215 Topcorns.
    function createPodListing(
        uint256 index,
        uint256 start,
        uint256 amount,
        uint24 pricePerPod,
        uint256 maxHarvestableIndex,
        bool toWallet
    ) external {
        _createPodListing(index, start, amount, pricePerPod, maxHarvestableIndex, toWallet);
    }

    // Fill
    function fillPodListing(PodListing calldata l, uint256 topcornAmount) external {
        LibMarket.transferTopcorns(l.account, topcornAmount, l.toWallet);
        _fillListing(l, topcornAmount);
    }

    function claimAndFillPodListing(
        PodListing calldata l,
        uint256 topcornAmount,
        LibClaim.Claim calldata claim
    ) external nonReentrant {
        allocateTopcornsToWallet(claim, topcornAmount, l.account, l.toWallet);
        _fillListing(l, topcornAmount);
        LibMarket.claimRefund(claim);
    }

    function buyTopcornsAndFillPodListing(
        PodListing calldata l,
        uint256 topcornAmount,
        uint256 buyTopcornAmount
    ) external payable nonReentrant {
        if (topcornAmount > 0) LibMarket.transferTopcorns(l.account, topcornAmount, l.toWallet);
        _buyTopcornsAndFillPodListing(l, topcornAmount, buyTopcornAmount);
    }

    function claimBuyTopcornsAndFillPodListing(
        PodListing calldata l,
        uint256 topcornAmount,
        uint256 buyTopcornAmount,
        LibClaim.Claim calldata claim
    ) external payable nonReentrant {
        allocateTopcornsToWallet(claim, topcornAmount, l.account, l.toWallet);
        _buyTopcornsAndFillPodListing(l, topcornAmount, buyTopcornAmount);
    }

    // Cancel
    function cancelPodListing(uint256 index) external {
        _cancelPodListing(msg.sender, index);
    }

    // Get
    function podListing(uint256 index) external view returns (bytes32) {
        return s.podListings[index];
    }

    /*
     * Pod Orders
     */

    // Create
    // Note: pricePerPod is bounded by 16_777_215 Topcorns.
    function createPodOrder(
        uint256 topcornAmount,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) external returns (bytes32 id) {
        topcorn().transferFrom(msg.sender, address(this), topcornAmount);
        return _createPodOrder(topcornAmount, pricePerPod, maxPlaceInLine);
    }

    function claimAndCreatePodOrder(
        uint256 topcornAmount,
        uint24 pricePerPod,
        uint232 maxPlaceInLine,
        LibClaim.Claim calldata claim
    ) external nonReentrant returns (bytes32 id) {
        allocateTopcorns(claim, topcornAmount, address(this));
        id = _createPodOrder(topcornAmount, pricePerPod, maxPlaceInLine);
        LibMarket.claimRefund(claim);
    }

    function buyTopcornsAndCreatePodOrder(
        uint256 topcornAmount,
        uint256 buyTopcornAmount,
        uint24 pricePerPod,
        uint232 maxPlaceInLine
    ) external payable nonReentrant returns (bytes32 id) {
        if (topcornAmount > 0) topcorn().transferFrom(msg.sender, address(this), topcornAmount);
        return _buyTopcornsAndCreatePodOrder(topcornAmount, buyTopcornAmount, pricePerPod, maxPlaceInLine);
    }

    function claimBuyTopcornsAndCreatePodOrder(
        uint256 topcornAmount,
        uint256 buyTopcornAmount,
        uint24 pricePerPod,
        uint232 maxPlaceInLine,
        LibClaim.Claim calldata claim
    ) external payable nonReentrant returns (bytes32 id) {
        allocateTopcorns(claim, topcornAmount, address(this));
        return _buyTopcornsAndCreatePodOrder(topcornAmount, buyTopcornAmount, pricePerPod, maxPlaceInLine);
    }

    // Fill
    function fillPodOrder(
        PodOrder calldata o,
        uint256 index,
        uint256 start,
        uint256 amount,
        bool toWallet
    ) external {
        _fillPodOrder(o, index, start, amount, toWallet);
    }

    // Cancel
    function cancelPodOrder(
        uint24 pricePerPod,
        uint256 maxPlaceInLine,
        bool toWallet
    ) external {
        _cancelPodOrder(pricePerPod, maxPlaceInLine, toWallet);
    }

    // Get

    function podOrder(
        address account,
        uint24 pricePerPod,
        uint256 maxPlaceInLine
    ) external view returns (uint256) {
        return s.podOrders[createOrderId(account, pricePerPod, maxPlaceInLine)];
    }

    function podOrderById(bytes32 id) external view returns (uint256) {
        return s.podOrders[id];
    }

    /*
     * Helpers
     */

    function allocateTopcorns(
        LibClaim.Claim calldata c,
        uint256 transferTopcorns,
        address to
    ) private {
        LibClaim.claim(c);
        LibMarket.allocateTopcornsTo(transferTopcorns, to);
    }

    function allocateTopcornsToWallet(
        LibClaim.Claim calldata c,
        uint256 transferTopcorns,
        address to,
        bool toWallet
    ) private {
        LibClaim.claim(c);
        LibMarket.allocateTopcornsToWallet(transferTopcorns, to, toWallet);
    }

    /*
     * Transfer Plot
     */

    function transferPlot(
        address sender,
        address recipient,
        uint256 id,
        uint256 start,
        uint256 end
    ) external nonReentrant {
        require(sender != address(0) && recipient != address(0), "Field: Transfer to/from 0 address.");
        uint256 amount = s.a[sender].field.plots[id];
        require(amount > 0, "Field: Plot not owned by user.");
        require(end > start && amount >= end, "Field: Pod range invalid.");
        amount = end - start;
        if (msg.sender != sender && allowancePods(sender, msg.sender) != type(uint256).max) {
            decrementAllowancePods(sender, msg.sender, amount);
        }

        if (s.podListings[id] != bytes32(0)) {
            _cancelPodListing(sender, id);
        }
        _transferPlot(sender, recipient, id, start, amount);
    }

    function approvePods(address spender, uint256 amount) external nonReentrant {
        require(spender != address(0), "Field: Pod Approve to 0 address.");
        setAllowancePods(msg.sender, spender, amount);
        emit PodApproval(msg.sender, spender, amount);
    }
}
