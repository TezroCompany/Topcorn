/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../../AppStorage.sol";
import "../../../libraries/LibDiamond.sol";

/**
 * @title Pausing/unpausing.
 **/
contract SystemFacet {
    AppStorage internal s;

    event Pause(address account, uint256 timestamp);
    event Unpause(address account, uint256 timestamp, uint256 timePassed);

    /**
     * Pause / Unpause
     **/

    function ownerPause() external {
        LibDiamond.enforceIsContractOwner();
        pause();
    }

    function ownerUnpause() external {
        LibDiamond.enforceIsContractOwner();
        unpause();
    }

    function pause() private {
        if (s.paused) return;
        s.paused = true;
        s.o.initialized = false;
        s.pausedAt = uint128(block.timestamp);
        emit Pause(msg.sender, block.timestamp);
    }

    function unpause() private {
        if (!s.paused) return;
        s.paused = false;
        uint256 timePassed = block.timestamp - uint256(s.pausedAt);
        timePassed = (timePassed / 3600 + 1) * 3600;
        s.season.start = s.season.start + timePassed;
        emit Unpause(msg.sender, block.timestamp, timePassed);
    }
}
