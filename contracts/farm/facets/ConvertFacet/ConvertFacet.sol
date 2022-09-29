/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "./ConvertSilo.sol";
import "../../../libraries/LibConvert.sol";
import "../../../libraries/LibInternal.sol";
import "../../../libraries/LibClaim.sol";

/**
 * @title Silo handles depositing and withdrawing Topcorns and LP, and updating the Silo.
 **/
contract ConvertFacet is ConvertSilo {
    function convertDepositedTopcorns(
        uint256 topcorns,
        uint256 minLP,
        uint32[] memory crates,
        uint256[] memory amounts
    ) external updateSiloNonReentrant {
        LibInternal.updateSilo(msg.sender);
        (uint256 lp, uint256 topcornsConverted) = LibConvert.sellToPegAndAddLiquidity(topcorns, minLP);
        (uint256 topcornsRemoved, uint256 stalkRemoved) = _withdrawTopcornsForConvert(crates, amounts, topcornsConverted);
        require(topcornsRemoved == topcornsConverted, "Silo: Wrong Topcorns removed.");
        uint32 _s = uint32(stalkRemoved / (topcornsConverted * C.getSeedsPerLP()));
        _s = getDepositSeason(_s);

        _depositLP(lp, topcornsConverted, _s);
        LibCheck.balanceCheck();
        LibSilo.updateBalanceOfRainStalk(msg.sender);
    }

    function convertDepositedLP(
        uint256 lp,
        uint256 minTopcorns,
        uint32[] memory crates,
        uint256[] memory amounts
    ) external updateSiloNonReentrant {
        LibInternal.updateSilo(msg.sender);
        (uint256 topcorns, uint256 lpConverted) = LibConvert.removeLPAndBuyToPeg(lp, minTopcorns);
        (uint256 lpRemoved, uint256 stalkRemoved) = _withdrawLPForConvert(crates, amounts, lpConverted);
        require(lpRemoved == lpConverted, "Silo: Wrong LP removed.");
        uint32 _s = uint32(stalkRemoved / (topcorns * C.getSeedsPerTopcorn()));
        _s = getDepositSeason(_s);
        _depositTopcorns(topcorns, _s);
        LibCheck.balanceCheck();
        LibSilo.updateBalanceOfRainStalk(msg.sender);
    }

    function claimConvertAddAndDepositLP(
        uint256 lp,
        LibMarket.AddLiquidity calldata al,
        uint32[] memory crates,
        uint256[] memory amounts,
        LibClaim.Claim calldata claim
    ) external payable updateSiloNonReentrant {
        LibClaim.claim(claim);
        _convertAddAndDepositLP(lp, al, crates, amounts);
    }

    function convertAddAndDepositLP(
        uint256 lp,
        LibMarket.AddLiquidity calldata al,
        uint32[] memory crates,
        uint256[] memory amounts
    ) external payable updateSiloNonReentrant {
        _convertAddAndDepositLP(lp, al, crates, amounts);
    }

    function lpToPeg() external view returns (uint256 lp) {
        return LibConvert.lpToPeg();
    }

    function topcornsToPeg() external view returns (uint256 topcorns) {
        (uint256 bnbReserve, uint256 topcornReserve) = reserves();
        return LibConvert.topcornsToPeg(bnbReserve, topcornReserve);
    }

    function getDepositSeason(uint32 _s) internal view returns (uint32) {
        uint32 __s = season();
        if (_s >= __s) _s = __s - 1;
        return uint32(__s - _s);
    }
}
