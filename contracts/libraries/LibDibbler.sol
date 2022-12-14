/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../C.sol";
import "../interfaces/ITopcorn.sol";
import "./Decimal.sol";
import "./LibCheck.sol";
import "./LibAppStorage.sol";

/**
 * @title Dibbler
 **/
library LibDibbler {
    using Decimal for Decimal.D256;

    event Sow(address indexed account, uint256 index, uint256 topcorns, uint256 pods);

    /**
     * Shed
     **/

    function sow(uint256 amount, address account) internal returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        // We can assume amount <= soil from getSowAmount
        s.f.soil = s.f.soil - amount;
        return sowNoSoil(amount, account);
    }

    function sowNoSoil(uint256 amount, address account) internal returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 pods = topcornsToPods(amount, s.w.yield);
        require(pods > 0, "Field: Must receive non-zero Pods.");
        sowPlot(account, amount, pods);
        s.f.pods = s.f.pods + pods;
        saveSowTime();
        return pods;
    }

    function sowPlot(
        address account,
        uint256 topcorns,
        uint256 pods
    ) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.a[account].field.plots[s.f.pods] = pods;
        emit Sow(account, s.f.pods, topcorns, pods);
    }

    function topcornsToPods(uint256 stalks, uint256 y) private pure returns (uint256) {
        Decimal.D256 memory rate = Decimal.ratio(y, 100).add(Decimal.one());
        return Decimal.from(stalks).mul(rate).asUint256();
    }

    function saveSowTime() private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.f.soil > 1e18 || s.w.nextSowTime < type(uint32).max) return;
        s.w.nextSowTime = uint32(block.timestamp - s.season.timestamp);
    }
}
