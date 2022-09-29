/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/MarketplaceFacet/MarketplaceFacet.sol";

/**
 * @title Mock Marketplace Facet
 **/
contract MockMarketplaceFacet is MarketplaceFacet {
    function deleteOrders(bytes32[] calldata ids) external {
        for (uint256 i; i < ids.length; i++) {
            delete s.podOrders[ids[i]];
        }
    }
}
