/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../../../interfaces/ITopcorn.sol";
import "../../../libraries/LibDibbler.sol";
import "../../ReentrancyGuard.sol";

/**
 * @title Dibbler
 **/
contract TopcornDibbler is ReentrancyGuard {
    using Decimal for Decimal.D256;

    event Sow(address indexed account, uint256 index, uint256 topcorns, uint256 pods);

    /**
     * Getters
     **/

    /// @notice Getter for the net total number of pods excluding the number of harvested pods
    /// @return uint256 net total number of pods excluding the number of harvested pods
    function totalPods() external view returns (uint256) {
        return s.f.pods - s.f.harvested;
    }

    /// @notice Getter for the current index of the pods
    /// @return uint256 the current index of the pods
    function podIndex() external view returns (uint256) {
        return s.f.pods;
    }

    /// @notice Getter for the current index of the harvestable pods
    /// @return uint256 the current index of the harvestable pods
    function harvestableIndex() external view returns (uint256) {
        return s.f.harvestable;
    }

    /// @notice Getter for the current index of the harvested pods
    /// @return uint256 the current index of the harvested pods
    function harvestedIndex() external view returns (uint256) {
        return s.f.harvested;
    }

    /// @notice Getter for the number of total harvestable pods
    /// @return uint256 he number of total harvestable pods
    function totalHarvestable() external view returns (uint256) {
        return s.f.harvestable - s.f.harvested;
    }

    /// @notice Getter for the number of total unripened pods
    /// @return uint256 the number of total unripened pods
    function totalUnripenedPods() external view returns (uint256) {
        return s.f.pods - s.f.harvestable;
    }

    /// @notice Getter for the current number of pods at a particular plot id for a particular account
    /// @param account address of the account to retrieve number of pods
    /// @param plotId plot id to retrieve number of pods from
    /// @return uint256 the current number of pods at a particular plot id for a particular account
    function plot(address account, uint256 plotId) external view returns (uint256) {
        return s.a[account].field.plots[plotId];
    }

    /// @notice Getter for the total amount of soil currently
    /// @return uint256 the total amount of soil currently
    function totalSoil() external view returns (uint256) {
        return s.f.soil;
    }

    /**
     * Internal
     **/

    /// @notice Internal Function for sowing a specified amount of topcorns and returns the amount of pods received
    /// @param amount amount of topcorns to sow
    /// @param fromWallet ()
    /// @return pods the amount of pods received
    function _sowTopcorns(uint256 amount, bool fromWallet) internal returns (uint256 pods) {
        pods = LibDibbler.sow(amount, msg.sender);
        if (fromWallet) topcorn().burnFrom(msg.sender, amount);
        else topcorn().burn(amount);
        LibCheck.topcornBalanceCheck();
    }

    /// @notice Internal Function for retrieving the ITopcorn object for the topcorn token ()
    /// @return ITopcorn the ITopcorn object for the topcorn token
    function topcorn() internal view returns (ITopcorn) {
        return ITopcorn(s.c.topcorn);
    }
}
