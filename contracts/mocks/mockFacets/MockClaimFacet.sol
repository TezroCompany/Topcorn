/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/ClaimFacet.sol";
import "../../libraries/LibMarket.sol";
import "../../libraries/LibAppStorage.sol";
import "../MockToken.sol";

/**
 * @title Mock Claim Facet
 **/
contract MockClaimFacet is ClaimFacet {
    function claimWithAllocationE(LibClaim.Claim calldata c, uint256 topcornsAllocated) public payable {
        LibClaim.claim(c);
        LibMarket.allocateTopcorns(topcornsAllocated);
        LibMarket.claimRefund(c);
    }

    function incrementBalanceOfWrappedE(address account, uint256 amount) public payable {
        s.a[account].wrappedTopcorns += amount;
        MockToken(s.c.topcorn).mint(address(this), amount);
    }
}
