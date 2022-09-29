/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../../farm/facets/FieldFacet/FieldFacet.sol";

/**
 * @title Mock Field Facet
 **/
contract MockFieldFacet is FieldFacet {
    // for Testing purposes only
    uint32 mapToPlotIndex;
    mapping(uint32 => uint256) mapToPlots;
    mapping(uint32 => address) mapToAddress;

    function sowTopcornsAndIndex(uint256 amount) external returns (uint256) {
        mapToPlots[mapToPlotIndex] = s.f.pods;
        topcorn().transferFrom(msg.sender, address(this), amount);
        uint256 amountPods = _sowTopcorns(amount, false);
        mapToAddress[mapToPlotIndex] = msg.sender;
        mapToPlotIndex = mapToPlotIndex + 1;
        return amountPods;
    }

    function deletePlot(address account, uint256 index) external {
        delete s.a[account].field.plots[index];
    }

    function resetField() public {
        for (uint32 i; i < mapToPlotIndex; i++) {
            delete s.a[mapToAddress[i]].field.plots[mapToPlots[i]];
            delete s.podListings[mapToPlots[i]];
        }
    }

    function incrementTotalSoilE(uint256 amount) public {
        incrementTotalSoil(amount);
    }

    function incrementTotalSoilEE(uint256 amount) public {
        incrementTotalSoil(amount);
    }

    function incrementTotalHarvestableE(uint256 amount) public {
        topcorn().mint(address(this), amount);
        s.f.harvestable = s.f.harvestable + amount;
    }

    function incrementTotalPodsE(uint256 amount) public {
        s.f.pods = s.f.pods + amount;
    }

    function setFieldAmountsE(
        uint256 soil,
        uint256 harvestable,
        uint256 pods
    ) public {
        incrementTotalSoil(soil);
        s.f.harvestable = s.f.harvestable + harvestable;
        s.f.pods = s.f.pods + pods;
    }

    function resetAllowances(address[] memory accounts) public {
        for (uint256 i; i < accounts.length; i++) {
            for (uint256 j; j < accounts.length; j++) {
                s.a[accounts[i]].field.podAllowances[accounts[j]] = 0;
            }
        }
    }

    function incrementTotalSoil(uint256 amount) internal {
        s.f.soil = s.f.soil + amount;
    }
}
