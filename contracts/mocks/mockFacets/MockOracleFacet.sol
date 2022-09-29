/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/OracleFacet.sol";

/**
 * @title Mock Oracle Facet
 **/
contract MockOracleFacet is OracleFacet {
    function captureE() public virtual returns (Decimal.D256 memory, Decimal.D256 memory) {
        if (s.o.initialized) {
            return updateOracle();
        } else {
            initializeOracle();
            return (Decimal.one(), Decimal.one());
        }
    }

    function timestamp() public view returns (uint32) {
        return s.o.timestamp;
    }
}
