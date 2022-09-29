/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import {AppStorage} from "../AppStorage.sol";
import {ITopcorn} from "../../interfaces/ITopcorn.sol";


contract InitLiquidity {
    AppStorage internal s;
    
    address private constant ownerAddress = address(0x0000000000000000000000000000000000000000);

    function init() external {
        ITopcorn(s.c.topcorn).mint(ownerAddress, 10_000_000_000_000_000_000_000); // 10,000 TopCorns
    }
}